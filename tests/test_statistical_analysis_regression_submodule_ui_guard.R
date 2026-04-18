args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

library(shiny)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

logistic_text <- read_utf8("modules", "statistical_analysis", "logistic.R")
linear_text <- read_utf8("modules", "statistical_analysis", "linear.R")
if (!nzchar(logistic_text) || !nzchar(linear_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(logistic_text, "source\\(\"modules/common/ui_shell.R\"\\)", "logistic 模块可独立加载公共 UI 壳")
expect_contains(logistic_text, "app_card_note\\(", "logistic 模块使用公共说明块")
expect_contains(logistic_text, "app_card_panel\\(", "logistic 模块使用公共信息面板")
expect_contains(logistic_text, "响应与分层", "logistic 模块保留响应与分层区")
expect_contains(logistic_text, "总计列与事件映射", "logistic 模块保留总计列与事件映射区")
expect_contains(logistic_text, "预测变量与参考组", "logistic 模块保留预测变量与参考组区")
expect_contains(logistic_text, "uiOutput\\(ns\\(\"logistic_total_cols_ui\"\\)\\)", "logistic 模块保留总计列配置输出")
expect_contains(logistic_text, "uiOutput\\(ns\\(\"logistic_event_mapping_ui\"\\)\\)", "logistic 模块保留事件映射输出")
expect_contains(logistic_text, "uiOutput\\(ns\\(\"logistic_reference_ui\"\\)\\)", "logistic 模块保留参考组输出")
expect_contains(logistic_text, "selectizeInput\\(ns\\(\"logistic_predictors\"\\)", "logistic 模块保留预测变量输入")

expect_contains(linear_text, "source\\(\"modules/common/ui_shell.R\"\\)", "linear 模块可独立加载公共 UI 壳")
expect_contains(linear_text, "app_card_note\\(", "linear 模块使用公共说明块")
expect_contains(linear_text, "app_card_panel\\(", "linear 模块使用公共信息面板")
expect_contains(linear_text, "响应与分层", "linear 模块保留响应与分层区")
expect_contains(linear_text, "总计列配置", "linear 模块保留总计列配置区")
expect_contains(linear_text, "预测变量与参考组", "linear 模块保留预测变量与参考组区")
expect_contains(linear_text, "uiOutput\\(ns\\(\"linear_total_cols_ui\"\\)\\)", "linear 模块保留总计列配置输出")
expect_contains(linear_text, "uiOutput\\(ns\\(\"linear_reference_ui\"\\)\\)", "linear 模块保留参考组输出")
expect_contains(linear_text, "selectizeInput\\(ns\\(\"linear_predictors\"\\)", "linear 模块保留预测变量输入")

module_path <- function(p) file.path(project_root, p)
source(module_path(file.path("modules", "statistical_analysis", "logistic.R")))
source(module_path(file.path("modules", "statistical_analysis", "linear.R")))
if (!exists("bsTooltip", mode = "function")) {
  bsTooltip <- function(...) NULL
}

demo_df <- data.frame(
  arm = factor(c("A", "A", "B", "B", "A", "B")),
  sex = factor(c("M", "F", "F", "M", "F", "M")),
  y = c(1, 0, 1, 0, 1, 1),
  z = c(2.1, 1.8, 3.0, 2.6, 2.9, 3.2),
  x = c(0.3, 1.1, -0.4, 0.8, 1.4, -0.2),
  stringsAsFactors = TRUE
)

logistic_ui <- logistic_params_ui(NS("logistic"), demo_df)
linear_ui <- linear_params_ui(NS("linear"), demo_df)
if (!inherits(logistic_ui, "shiny.tag.list")) stop("logistic_params_ui 未返回 shiny.tag.list", call. = FALSE)
if (!inherits(linear_ui, "shiny.tag.list")) stop("linear_params_ui 未返回 shiny.tag.list", call. = FALSE)

cat("Statistical analysis regression submodule UI guard passed.\n")
