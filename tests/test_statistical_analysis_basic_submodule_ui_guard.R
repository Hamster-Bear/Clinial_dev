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

anova_text <- read_utf8("modules", "statistical_analysis", "anova.R")
chisq_text <- read_utf8("modules", "statistical_analysis", "chisq.R")
if (!nzchar(anova_text) || !nzchar(chisq_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(anova_text, "source\\(\"modules/common/ui_shell.R\"\\)", "anova 模块可独立加载公共 UI 壳")
expect_contains(anova_text, "app_card_note\\(", "anova 模块使用公共说明块")
expect_contains(anova_text, "app_card_panel\\(", "anova 模块使用公共信息面板")
expect_contains(anova_text, "响应变量", "anova 模块保留响应变量区")
expect_contains(anova_text, "分组因素", "anova 模块保留分组因素区")
expect_contains(anova_text, "selectInput\\(ns\\(\"anova_response\"\\)", "anova 模块保留响应变量输入")
expect_contains(anova_text, "selectizeInput\\(ns\\(\"anova_factors\"\\)", "anova 模块保留分组因素输入")

expect_contains(chisq_text, "source\\(\"modules/common/ui_shell.R\"\\)", "chisq 模块可独立加载公共 UI 壳")
expect_contains(chisq_text, "app_card_note\\(", "chisq 模块使用公共说明块")
expect_contains(chisq_text, "app_card_panel\\(", "chisq 模块使用公共信息面板")
expect_contains(chisq_text, "变量选择", "chisq 模块保留变量选择区")
expect_contains(chisq_text, "selectInput\\(ns\\(\"chisq_var1\"\\)", "chisq 模块保留变量1输入")
expect_contains(chisq_text, "selectInput\\(ns\\(\"chisq_var2\"\\)", "chisq 模块保留变量2输入")

module_path <- function(p) file.path(project_root, p)
source(module_path(file.path("modules", "statistical_analysis", "anova.R")))
source(module_path(file.path("modules", "statistical_analysis", "chisq.R")))

demo_df <- data.frame(
  arm = factor(c("A", "A", "B", "B", "A", "B")),
  sex = factor(c("M", "F", "F", "M", "F", "M")),
  site = factor(c("中心1", "中心1", "中心2", "中心2", "中心3", "中心3")),
  score = c(3.2, 2.8, 4.1, 3.9, 3.5, 4.0),
  stringsAsFactors = TRUE
)

anova_ui <- anova_params_ui(NS("anova"), demo_df)
chisq_ui <- chisq_params_ui(NS("chisq"), demo_df)
if (!inherits(anova_ui, "shiny.tag.list")) stop("anova_params_ui 未返回 shiny.tag.list", call. = FALSE)
if (!inherits(chisq_ui, "shiny.tag.list")) stop("chisq_params_ui 未返回 shiny.tag.list", call. = FALSE)

cat("Statistical analysis basic submodule UI guard passed.\n")
