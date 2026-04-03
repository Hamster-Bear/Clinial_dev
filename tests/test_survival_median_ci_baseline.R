library(testthat)

source(file.path("..", "modules", "common", "analysis_format.R"))
source(file.path("..", "modules", "common", "graphics_repro.R"))

test_that("固定样例的 median/LCL/UCL 与基准一致", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survminer")
  library(survival)
  library(survminer)
  df <- data.frame(
    time = c(5, 8, 12, 20, 6, 9, 13, 21),
    status = c(1, 0, 1, 0, 1, 1, 0, 0)
  )
  time_var <- "time"
  status_var <- "status"
  km_censor_value <- "0"
  status_vec <- df[[status_var]]
  if (km_censor_value == "1") {
    status_vec <- ifelse(status_vec == 1, 0, ifelse(status_vec == 0, 1, status_vec))
  }
  valid_status <- unique(status_vec[!is.na(status_vec)])
  if (length(valid_status) > 0 && !all(valid_status %in% c(0, 1))) {
    min_status <- min(valid_status, na.rm = TRUE)
    status_vec <- ifelse(status_vec == min_status, 0, 1)
  }
  surv_obj <- Surv(df[[time_var]], status_vec)
  fit <- survminer::surv_fit(surv_obj ~ 1, data = df, conf.type = "log-log")
  tbl <- summary(fit)$table
  if (is.null(dim(tbl))) {
    tbl <- t(as.matrix(tbl))
    rownames(tbl) <- "all"
  } else {
    tbl <- as.matrix(tbl)
  }
  median_val <- as.numeric(tbl[, "median"])
  lcl_val <- as.numeric(tbl[, "0.95LCL"])
  ucl_val <- as.numeric(tbl[, "0.95UCL"])
  expect_equal(median_val, 12)
  expect_equal(lcl_val, 5)
  expect_true(is.na(ucl_val))
})

test_that("KM 可复现代码包含 UI 同源关键步骤", {
  code <- generate_graphics_repro_code(
    fig_type = "km",
    state = list(
      time_var = "time",
      status_var = "status",
      km_censor_value = "0",
      strata_var = "None",
      facet_var = "None",
      facet_value = NULL
    ),
    data_name = "data"
  )
  expect_match(code, "km_censor_value <-")
  expect_match(code, "status_vec <- ifelse\\(status_vec == 1, 0")
  expect_match(code, "conf.type = \"log-log\"")
  expect_match(code, "extract_median_ci <- function")
  expect_match(code, "median_df <- extract_median_ci\\(fit\\)")
})
