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

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

copy_text <- read_utf8("modules", "common", "analysis", "stat_analysis_submodule_copy.R")
desc_text <- read_utf8("modules", "statistical_analysis", "desc.R")
cox_text <- read_utf8("modules", "statistical_analysis", "cox.R")
logistic_text <- read_utf8("modules", "statistical_analysis", "logistic.R")
linear_text <- read_utf8("modules", "statistical_analysis", "linear.R")
anova_text <- read_utf8("modules", "statistical_analysis", "anova.R")
chisq_text <- read_utf8("modules", "statistical_analysis", "chisq.R")

expect_contains(copy_text, "STAT_ANALYSIS_SUBMODULE_COPY <- list", "统计分析子模块共享文案对象")
expect_contains(copy_text, "desc = list", "描述性统计共享文案")
expect_contains(copy_text, "cox = list", "Cox 回归共享文案")
expect_contains(copy_text, "logistic = list", "Logistic 回归共享文案")
expect_contains(copy_text, "linear = list", "线性回归共享文案")
expect_contains(copy_text, "anova = list", "方差分析共享文案")
expect_contains(copy_text, "chisq = list", "卡方检验共享文案")

expect_contains(desc_text, "source\\(\"modules/common/analysis/stat_analysis_submodule_copy.R\"\\)", "desc 加载统计分析共享文案")
expect_contains(desc_text, "copy <- STAT_ANALYSIS_SUBMODULE_COPY\\$desc", "desc 读取共享文案")
expect_contains(desc_text, "app_card_note\\(copy\\$intro\\)", "desc 顶部说明改为共享文案")
expect_contains(desc_text, "app_card_note\\(copy\\$variables\\)", "desc 变量说明改为共享文案")
expect_contains(desc_text, "app_card_note\\(copy\\$options\\)", "desc 展示说明改为共享文案")

expect_contains(cox_text, "source\\(\"modules/common/analysis/stat_analysis_submodule_copy.R\"\\)", "cox 加载统计分析共享文案")
expect_contains(cox_text, "copy <- STAT_ANALYSIS_SUBMODULE_COPY\\$cox", "cox 读取共享文案")
expect_contains(cox_text, "app_card_note\\(copy\\$intro\\)", "cox 顶部说明改为共享文案")
expect_contains(cox_text, "app_card_note\\(copy\\$outcome\\)", "cox 结局说明改为共享文案")
expect_contains(cox_text, "app_card_note\\(copy\\$total_cols\\)", "cox 总计列说明改为共享文案")
expect_contains(cox_text, "app_card_note\\(copy\\$covariates\\)", "cox 协变量说明改为共享文案")

expect_contains(logistic_text, "source\\(\"modules/common/analysis/stat_analysis_submodule_copy.R\"\\)", "logistic 加载统计分析共享文案")
expect_contains(logistic_text, "copy <- STAT_ANALYSIS_SUBMODULE_COPY\\$logistic", "logistic 读取共享文案")
expect_contains(logistic_text, "app_card_note\\(copy\\$intro\\)", "logistic 顶部说明改为共享文案")
expect_contains(logistic_text, "app_card_note\\(copy\\$outcome\\)", "logistic 响应说明改为共享文案")
expect_contains(logistic_text, "app_card_note\\(copy\\$total_cols\\)", "logistic 总计列说明改为共享文案")
expect_contains(logistic_text, "app_card_note\\(copy\\$covariates\\)", "logistic 预测变量说明改为共享文案")

expect_contains(linear_text, "source\\(\"modules/common/analysis/stat_analysis_submodule_copy.R\"\\)", "linear 加载统计分析共享文案")
expect_contains(linear_text, "copy <- STAT_ANALYSIS_SUBMODULE_COPY\\$linear", "linear 读取共享文案")
expect_contains(linear_text, "app_card_note\\(copy\\$intro\\)", "linear 顶部说明改为共享文案")
expect_contains(linear_text, "app_card_note\\(copy\\$outcome\\)", "linear 响应说明改为共享文案")
expect_contains(linear_text, "app_card_note\\(copy\\$total_cols\\)", "linear 总计列说明改为共享文案")
expect_contains(linear_text, "app_card_note\\(copy\\$covariates\\)", "linear 预测变量说明改为共享文案")

expect_contains(anova_text, "source\\(\"modules/common/analysis/stat_analysis_submodule_copy.R\"\\)", "anova 加载统计分析共享文案")
expect_contains(anova_text, "copy <- STAT_ANALYSIS_SUBMODULE_COPY\\$anova", "anova 读取共享文案")
expect_contains(anova_text, "app_card_note\\(copy\\$intro\\)", "anova 顶部说明改为共享文案")
expect_contains(anova_text, "app_card_note\\(copy\\$response\\)", "anova 响应说明改为共享文案")
expect_contains(anova_text, "app_card_note\\(copy\\$factors\\)", "anova 分组说明改为共享文案")

expect_contains(chisq_text, "source\\(\"modules/common/analysis/stat_analysis_submodule_copy.R\"\\)", "chisq 加载统计分析共享文案")
expect_contains(chisq_text, "copy <- STAT_ANALYSIS_SUBMODULE_COPY\\$chisq", "chisq 读取共享文案")
expect_contains(chisq_text, "app_card_note\\(copy\\$intro\\)", "chisq 顶部说明改为共享文案")
expect_contains(chisq_text, "app_card_note\\(copy\\$variables\\)", "chisq 变量说明改为共享文案")

cat("Statistical analysis copy guard passed.\n")
