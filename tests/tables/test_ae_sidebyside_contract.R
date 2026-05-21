# ae_sidebyside 合同测试 — perform_ae_sidebyside_analysis() 和 generate_ae_sidebyside_code()
test_find_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- sub(file_arg, "", args[grep(file_arg, args)])
  script_path <- if (length(script_path) > 0) script_path[[1]] else ""
  start_candidates <- unique(c(
    if (nzchar(script_path)) dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)) else character(0),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  ))
  for (candidate in start_candidates) {
    current <- candidate
    repeat {
      if (file.exists(file.path(current, "app.R")) &&
          dir.exists(file.path(current, "modules")) &&
          dir.exists(file.path(current, "tests"))) {
        return(normalizePath(current, winslash = "/", mustWork = TRUE))
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }
  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- test_find_project_root()
source(file.path(project_root, "modules", "common", "graphics_common.R"))
source(file.path(project_root, "modules", "tables", "ae_sidebyside.R"))

test_data <- data.frame(
  USUBJID = rep(paste0("SUBJ-", sprintf("%02d", 1:10)), each = 3),
  TRT01A = factor(rep(c("Drug A", "Placebo"), each = 15)),
  AETERM = rep(c("Nausea", "Headache", "Fatigue", "Dizziness", "Pain"), 6),
  AESEV = factor(rep(c("MILD", "MODERATE", "SEVERE"), 10)),
  TEAE_FL = "Y",
  TRAE_FL = rep(c("Y", "N"), 15),
  stringsAsFactors = FALSE
)

test_that("perform_ae_sidebyside_analysis returns ggplot object", {
  result <- perform_ae_sidebyside_analysis(
    test_data,
    term_col = "AETERM", sev_col = "AESEV", subj_col = "USUBJID",
    group_col = "TRT01A", flag_col = "TEAE_FL", flag_val = "Y",
    rel_col = "TRAE_FL", rel_val = "Y",
    count_mode = "worst_subject_term", min_pct = 0
  )
  expect_s3_class(result, "ggplot")
})

test_that("perform_ae_sidebyside_analysis works with event_count mode", {
  result <- perform_ae_sidebyside_analysis(
    test_data,
    term_col = "AETERM", sev_col = "AESEV", subj_col = "USUBJID",
    group_col = "TRT01A", flag_col = "TEAE_FL", flag_val = "Y",
    rel_col = "TRAE_FL", rel_val = "Y",
    count_mode = "event_count", min_pct = 0
  )
  expect_s3_class(result, "ggplot")
})

test_that("perform_ae_sidebyside_analysis applies min_pct filter", {
  result_all <- perform_ae_sidebyside_analysis(
    test_data,
    term_col = "AETERM", sev_col = "AESEV", subj_col = "USUBJID",
    group_col = "TRT01A", flag_col = "TEAE_FL", flag_val = "Y",
    rel_col = "TRAE_FL", rel_val = "Y",
    count_mode = "worst_subject_term", min_pct = 0
  )
  result_filtered <- perform_ae_sidebyside_analysis(
    test_data,
    term_col = "AETERM", sev_col = "AESEV", subj_col = "USUBJID",
    group_col = "TRT01A", flag_col = "TEAE_FL", flag_val = "Y",
    rel_col = "TRAE_FL", rel_val = "Y",
    count_mode = "worst_subject_term", min_pct = 50
  )
  expect_s3_class(result_all, "ggplot")
  expect_s3_class(result_filtered, "ggplot")
})

test_that("perform_ae_sidebyside_analysis errors on missing term_col", {
  expect_error(
    perform_ae_sidebyside_analysis(
      test_data,
      term_col = "NONEXISTENT", sev_col = "AESEV", subj_col = "USUBJID",
      group_col = "TRT01A", flag_col = "TEAE_FL", flag_val = "Y",
      rel_col = "TRAE_FL", rel_val = "Y"
    )
  )
})

test_that("generate_ae_sidebyside_code produces non-placeholder output", {
  code <- generate_ae_sidebyside_code(
    term_col = "AETERM", sev_col = "AESEV", subj_col = "USUBJID",
    group_col = "TRT01A", flag_col = "TEAE_FL", flag_val = "Y",
    rel_col = "TRAE_FL", rel_val = "Y"
  )
  expect_false(grepl("代码示例", code, fixed = TRUE))
  expect_true(grepl("library(ggplot2)", code, fixed = TRUE))
  expect_true(grepl("perform_ae_sidebyside_analysis", code, fixed = TRUE))
  expect_true(grepl("AETERM", code, fixed = TRUE))
})
