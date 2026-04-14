library(testthat)

module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}

source(module_path("modules/statistical_analysis/logistic.R"))
source(module_path("modules/common/table_export.R"))

test_that("medical_test_data.csv: event=1, predictor=gender 前端与表格规范完全一致", {
  csv_path <- module_path("test/medical_test_data.csv")
  skip_if_not(file.exists(csv_path), "Medical test data CSV missing")
  dat <- read.csv(csv_path, stringsAsFactors = FALSE)
  dat$gender <- factor(dat$gender)

  res <- perform_logistic_analysis(
    data = dat,
    logistic_response = "event",
    logistic_predictors = c("gender"),
    logistic_event_value = "1"
  )

  front_df <- as.data.frame(res$table[["_data"]], stringsAsFactors = FALSE)
  spec_df <- as.data.frame(extract_table_dataframe(res$table), stringsAsFactors = FALSE)

  names(front_df)[names(front_df) == "N"] <- "Event/N"
  names(front_df)[names(front_df) == "统计值"] <- "OR (95% CI)"
  names(spec_df)[names(spec_df) == "n"] <- "Event/N"
  names(spec_df)[names(spec_df) == "统计值"] <- "OR (95% CI)"

  front_df <- front_df[, c("预测变量", "Event/N", "OR (95% CI)", "P值"), drop = FALSE]
  spec_df <- spec_df[, c("预测变量", "Event/N", "OR (95% CI)", "P值"), drop = FALSE]

  expect_identical(front_df, spec_df)
  expect_identical(front_df$预测变量, c("gender", "\u00A0\u00A0\u00A0\u00A0Female (Reference)", "\u00A0\u00A0\u00A0\u00A0Male"))
  expect_identical(front_df[["Event/N"]], c("20/30", "10/15", "10/15"))
  expect_identical(front_df[["OR (95% CI)"]][2], "Reference")
  expect_match(front_df[["OR (95% CI)"]][3], "^1\\.00 \\(")
  expect_identical(front_df$P值[3], ">0.99")
  expect_true(startsWith(front_df$预测变量[2], "\u00A0\u00A0\u00A0\u00A0"))
  expect_true(startsWith(front_df$预测变量[3], "\u00A0\u00A0\u00A0\u00A0"))
})

test_that("非标准分类变量名在前端与表格抽取结果保持一致", {
  dat <- data.frame(
    event = c(0, 1, 0, 1, 0, 1, 0, 1),
    check.names = FALSE
  )
  dat[["治疗 组"]] <- factor(c("对照/标准", "对照/标准", "对照/标准", "对照/标准", "试验-增强", "试验-增强", "试验-增强", "试验-增强"))

  res <- perform_logistic_analysis(
    data = dat,
    logistic_response = "event",
    logistic_predictors = c("治疗 组"),
    logistic_event_value = "1"
  )

  front_df <- as.data.frame(res$table[["_data"]], stringsAsFactors = FALSE)
  spec_df <- as.data.frame(extract_table_dataframe(res$table), stringsAsFactors = FALSE)

  names(front_df)[names(front_df) == "N"] <- "Event/N"
  names(front_df)[names(front_df) == "统计值"] <- "OR (95% CI)"
  names(spec_df)[names(spec_df) == "n"] <- "Event/N"
  names(spec_df)[names(spec_df) == "统计值"] <- "OR (95% CI)"
  front_df <- front_df[, c("预测变量", "Event/N", "OR (95% CI)", "P值"), drop = FALSE]
  spec_df <- spec_df[, c("预测变量", "Event/N", "OR (95% CI)", "P值"), drop = FALSE]

  expect_identical(front_df, spec_df)
  expect_identical(front_df$预测变量[1], "治疗 组")
  expect_identical(front_df[["Event/N"]][1], "4/8")
  expect_true(any(grepl("\\(Reference\\)$", front_df$预测变量)))
  ref_idx <- which(grepl("\\(Reference\\)$", front_df$预测变量))[1]
  non_ref_idx <- setdiff(seq_len(nrow(front_df)), c(1, ref_idx))[1]
  expect_identical(front_df[["Event/N"]][ref_idx], "2/4")
  expect_identical(front_df[["Event/N"]][non_ref_idx], "2/4")
  expect_identical(front_df[["OR (95% CI)"]][ref_idx], "Reference")
  expect_true(startsWith(front_df$预测变量[ref_idx], "\u00A0\u00A0\u00A0\u00A0"))
  expect_true(startsWith(front_df$预测变量[non_ref_idx], "\u00A0\u00A0\u00A0\u00A0"))
  expect_match(front_df[["OR (95% CI)"]][non_ref_idx], "^1\\.00 \\(")
  expect_identical(front_df$P值[ref_idx], "")
})
