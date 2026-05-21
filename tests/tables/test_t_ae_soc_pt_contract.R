# t_ae_soc_pt 合同测试 — perform_t_ae_soc_pt_analysis() 和 generate_t_ae_soc_pt_code()
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
source(file.path(project_root, "modules", "tables", "t_ae_soc_pt.R"))

test_data <- data.frame(
  USUBJID = rep(paste0("SUBJ-", sprintf("%02d", 1:10)), each = 3),
  ARM = factor(rep(c("Drug A", "Placebo"), each = 15)),
  AEBODSYS = rep(c("Cardiac", "Respiratory", "Gastrointestinal"), 10),
  AEDECOD = paste0("AE-", sample(1:50, 30, replace = TRUE)),
  SAFFL = "Y",
  stringsAsFactors = FALSE
)

test_that("perform_t_ae_soc_pt_analysis returns rtables object", {
  result <- perform_t_ae_soc_pt_analysis(
    test_data, trt_var = "ARM", soc_var = "AEBODSYS",
    pt_var = "AEDECOD", id_var = "USUBJID"
  )
  expect_s4_class(result, "VTableTree")
})

test_that("perform_t_ae_soc_pt_analysis errors on missing trt_var", {
  expect_error(
    perform_t_ae_soc_pt_analysis(test_data, trt_var = "",
                                 soc_var = "AEBODSYS", pt_var = "AEDECOD"),
    "不能缺失"
  )
})

test_that("perform_t_ae_soc_pt_analysis applies population filter", {
  test_data2 <- test_data
  test_data2$SAFFL[1:5] <- "N"
  result <- perform_t_ae_soc_pt_analysis(
    test_data2, trt_var = "ARM", soc_var = "AEBODSYS",
    pt_var = "AEDECOD", id_var = "USUBJID",
    pop_var = "SAFFL", pop_val = "Y"
  )
  expect_s4_class(result, "VTableTree")
})

test_that("generate_t_ae_soc_pt_code produces non-placeholder output", {
  code <- generate_t_ae_soc_pt_code("ARM", "AEBODSYS", "AEDECOD",
                                     id_var = "USUBJID", pop_var = "SAFFL", pop_val = "Y")
  expect_false(grepl("代码生成功能待完善", code, fixed = TRUE))
  expect_true(grepl("library(rtables)", code, fixed = TRUE))
  expect_true(grepl("perform_t_ae_soc_pt_analysis", code, fixed = TRUE))
  expect_true(grepl("AEBODSYS", code, fixed = TRUE))
})
