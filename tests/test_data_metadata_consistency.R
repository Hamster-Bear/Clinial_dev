library(testthat)

source(file.path("..", "modules", "common", "data_metadata.R"))

test_that("metadata_attach_to_data 同步有效标签与类型元数据", {
  df <- data.frame(
    age = c("10", "20", "30"),
    arm = c("A", "B", "A"),
    stringsAsFactors = FALSE
  )
  attr(df$age, "label") <- "原始年龄"
  out <- metadata_attach_to_data(
    df,
    type_overrides = c(age = "numeric"),
    label_overrides = c(age = "年龄", arm = "治疗组")
  )
  meta <- attr(out, "hamster_var_meta")
  expect_true(is.data.frame(meta))
  expect_equal(meta$type[meta$var_name == "age"], "numeric")
  expect_equal(meta$label[meta$var_name == "age"], "年龄")
  expect_equal(attr(out$arm, "label"), "治疗组")
})

test_that("metadata_build_column_choices 使用有效标签", {
  df <- data.frame(x = 1:2, y = c("A", "B"))
  out <- metadata_attach_to_data(df, label_overrides = c(y = "分组"))
  choices <- metadata_build_column_choices(out)
  expect_true(any(grepl("y \\| 分组", names(choices), fixed = FALSE)))
})

test_that("metadata_get_var_type 优先使用元数据中的有效类型", {
  df <- data.frame(dt = c("2024-01-01", "2024-01-02"), stringsAsFactors = FALSE)
  out <- metadata_attach_to_data(df, type_overrides = c(dt = "date"))
  expect_equal(metadata_get_var_type("dt", out$dt, data = out), "date")
  coerced <- metadata_coerce_var_data(out$dt, metadata_get_var_type("dt", out$dt, data = out))
  expect_s3_class(coerced, "Date")
})
