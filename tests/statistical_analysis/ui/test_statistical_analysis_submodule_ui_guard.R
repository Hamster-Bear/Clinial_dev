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
setwd(file.path(project_root, "tests"))
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

library(shiny)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

desc_text <- read_utf8("modules", "statistical_analysis", "desc.R")
cox_text <- read_utf8("modules", "statistical_analysis", "cox.R")
if (!nzchar(desc_text) || !nzchar(cox_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(desc_text, "source\\(\"modules/common/ui_shell.R\"\\)", "desc 模块可独立加载公共 UI 壳")
expect_contains(desc_text, "app_card_note\\(", "desc 模块使用公共说明块")
expect_contains(desc_text, "app_card_panel\\(", "desc 模块使用公共信息面板")
expect_contains(desc_text, "变量与分组", "desc 模块保留变量与分组区")
expect_contains(desc_text, "展示与汇总", "desc 模块保留展示与汇总区")
expect_contains(desc_text, "uiOutput\\(ns\\(\"desc_total_cols_ui\"\\)\\)", "desc 模块保留总计列配置输出")
expect_contains(desc_text, "numericInput\\(ns\\(\"desc_decimals\"\\)", "desc 模块保留小数位数配置")
expect_contains(desc_text, "checkboxInput\\(ns\\(\"desc_auto_decimals\"\\)", "desc 模块保留自动小数位数配置")

expect_contains(cox_text, "source\\(\"modules/common/ui_shell.R\"\\)", "cox 模块可独立加载公共 UI 壳")
expect_contains(cox_text, "app_card_note\\(", "cox 模块使用公共说明块")
expect_contains(cox_text, "app_card_panel\\(", "cox 模块使用公共信息面板")
expect_contains(cox_text, "结局与分层", "cox 模块保留结局与分层区")
expect_contains(cox_text, "总计列与状态映射", "cox 模块保留总计列与状态映射区")
expect_contains(cox_text, "协变量与参考组", "cox 模块保留协变量与参考组区")
expect_contains(cox_text, "uiOutput\\(ns\\(\"cox_total_cols_ui\"\\)\\)", "cox 模块保留总计列配置输出")
expect_contains(cox_text, "uiOutput\\(ns\\(\"cox_status_mapping_ui\"\\)\\)", "cox 模块保留状态映射输出")
expect_contains(cox_text, "uiOutput\\(ns\\(\"cox_reference_ui\"\\)\\)", "cox 模块保留参考组输出")
expect_contains(cox_text, "selectizeInput\\(ns\\(\"cox_covariates\"\\)", "cox 模块保留协变量输入")

module_path <- function(p) file.path(project_root, p)
source(module_path(file.path("modules", "statistical_analysis", "desc.R")))
source(module_path(file.path("modules", "statistical_analysis", "cox.R")))
if (!exists("bsTooltip", mode = "function")) {
  bsTooltip <- function(...) NULL
}

demo_df <- data.frame(
  subject = 1:6,
  arm = factor(c("A", "A", "B", "B", "A", "B")),
  sex = factor(c("M", "F", "F", "M", "F", "M")),
  time = c(5, 8, 10, 6, 9, 12),
  status = c(1, 0, 1, 1, 0, 1),
  age = c(61, 55, 49, 67, 58, 63),
  bmi = c(23.4, 25.1, 21.8, 27.2, 22.6, 24.5),
  stringsAsFactors = TRUE
)

desc_ui <- desc_params_ui(NS("desc"), demo_df)
cox_ui <- cox_params_ui(NS("cox"), demo_df)
if (!inherits(desc_ui, "shiny.tag.list")) stop("desc_params_ui 未返回 shiny.tag.list", call. = FALSE)
if (!inherits(cox_ui, "shiny.tag.list")) stop("cox_params_ui 未返回 shiny.tag.list", call. = FALSE)

cat("Statistical analysis submodule UI guard passed.\n")

