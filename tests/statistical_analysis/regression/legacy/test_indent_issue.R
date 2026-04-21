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
library(dplyr)
module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}
source(module_path("modules/common/table_export.R"))
source(module_path("modules/common/analysis_format.R"))
source(module_path("modules/common/analysis_shared.R"))
source(module_path("modules/statistical_analysis/linear.R"))

# 创建模拟数据
set.seed(123)
n <- 50
mock_data <- data.frame(
  response = rnorm(n, 100, 15),
  age = rnorm(n, 60, 10),
  sex = factor(sample(c("Male", "Female"), n, replace = TRUE)),
  stratum = factor(sample(c("A", "B", "C"), n, replace = TRUE)),
  facet = factor(sample(c("Group1", "Group2"), n, replace = TRUE))
)

cat("=== 测试1: 无亚组无列分组 ===\n")
res1 <- perform_linear_analysis(
  data = mock_data,
  linear_response = "response",
  linear_predictors = c("age", "sex"),
  linear_strata = NULL,
  linear_facet = NULL,
  linear_reference_map = c(sex = "Female")
)
raw1 <- res1$table[["_data"]]
front1 <- extract_table_dataframe(res1$table)
cat("原始数据行数:", nrow(raw1), "\n")
cat("前端数据行数:", nrow(front1), "\n")
print(raw1[, c("预测变量", "N", "统计值", "P值")])
cat("预测变量列前10个字符:", substr(raw1$预测变量[3], 1, 10), "\n")
cat("是否以缩进开头:", startsWith(raw1$预测变量[3], "\u00A0\u00A0\u00A0\u00A0"), "\n")

cat("\n=== 测试2: 有亚组无列分组 ===\n")
res2 <- perform_linear_analysis(
  data = mock_data,
  linear_response = "response",
  linear_predictors = c("age", "sex"),
  linear_strata = "stratum",
  linear_facet = NULL,
  linear_reference_map = c(sex = "Female")
)
raw2 <- res2$table[["_data"]]
front2 <- extract_table_dataframe(res2$table)
cat("原始数据行数:", nrow(raw2), "\n")
cat("前端数据行数:", nrow(front2), "\n")
print(raw2[, c("亚组", "预测变量", "N", "统计值", "P值")])
cat("亚组列前10个字符:", substr(raw2$亚组[1], 1, 10), "\n")
cat("预测变量列前10个字符:", substr(raw2$预测变量[5], 1, 10), "\n")

cat("\n=== 测试3: 有亚组有列分组 ===\n")
res3 <- perform_linear_analysis(
  data = mock_data,
  linear_response = "response",
  linear_predictors = c("age", "sex"),
  linear_strata = "stratum",
  linear_facet = "facet",
  linear_reference_map = c(sex = "Female")
)
raw3 <- res3$table[["_data"]]
front3 <- extract_table_dataframe(res3$table)
cat("原始数据行数:", nrow(raw3), "\n")
cat("前端数据行数:", nrow(front3), "\n")
print(raw3[, grep("预测变量|亚组|Group1__N|Group1__统计值", names(raw3), value = TRUE)])

cat("\n=== 检查前后端一致性 ===\n")
# 比较原始数据和前端数据的预测变量列
for (i in 1:3) {
  res <- get(paste0("res", i))
  raw <- res$table[["_data"]]
  front <- extract_table_dataframe(res$table)
  # 预测变量列名可能不同，找到对应的列
  pred_col_raw <- grep("预测变量", names(raw), value = TRUE)[1]
  pred_col_front <- grep("预测变量|label|Variable", names(front), value = TRUE)[1]
  if (!is.na(pred_col_raw) && !is.na(pred_col_front)) {
    cat("测试", i, "预测变量列名: 原始=", pred_col_raw, " 前端=", pred_col_front, "\n")
    # 比较前几行
    for (j in 1:min(5, nrow(raw))) {
      raw_val <- raw[[pred_col_raw]][j]
      front_val <- front[[pred_col_front]][j]
      if (!identical(raw_val, front_val)) {
        cat("  行", j, "差异: 原始='", raw_val, "' 前端='", front_val, "'\n")
      }
    }
  }
}

cat("\n=== 检查导出表格 ===\n")
# 使用 build_sci_flextable 提取数据框
ft_df <- extract_table_dataframe(res1$table)
cat("导出数据框列名:", names(ft_df), "\n")
cat("预测变量值:", ft_df[[grep("预测变量|label|Variable", names(ft_df), value = TRUE)[1]]], "\n")

cat("\n测试完成。\n")

