library(testthat)

module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}

source(module_path("modules/statistical_analysis/logistic.R"))
source(module_path("modules/common/table_export.R"))

test_that("medical_test_data.csv: event=1, predictor=gender 前端与表格规范完全一致", {
  csv_path <- module_path("test/medical_test_data.csv")
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

  names(front_df)[names(front_df) == "N"] <- "n"
  names(front_df)[names(front_df) == "统计值"] <- "OR (95% CI)"

  front_df <- front_df[, c("预测变量", "n", "OR (95% CI)", "P值"), drop = FALSE]
  spec_df <- spec_df[, c("预测变量", "n", "OR (95% CI)", "P值"), drop = FALSE]

  expected <- data.frame(
    预测变量 = c(
      "gender",
      "\u00A0\u00A0\u00A0\u00A0Female (Reference)",
      "\u00A0\u00A0\u00A0\u00A0Male"
    ),
    n = c("30", "15", "15"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expected[["OR (95% CI)"]] <- c("", "Reference", "1.00 (0.22, 4.56)")
  expected[["P值"]] <- c("", "", ">0.99")

  expect_identical(front_df, spec_df)
  expect_identical(front_df, expected)
  expect_true(startsWith(front_df$预测变量[2], "\u00A0\u00A0\u00A0\u00A0"))
  expect_true(startsWith(front_df$预测变量[3], "\u00A0\u00A0\u00A0\u00A0"))
})
