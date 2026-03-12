# 测试 t_dm 模块重构
library(dplyr)
library(gtsummary)
library(gt)

# 加载模块函数
source("modules/tables/t_dm.R")

# 创建样本数据
set.seed(123)
adsl <- data.frame(
  SUBJID = 1:100,
  TRT = factor(rep(c("Placebo", "Drug"), each = 50)),
  AGE = round(rnorm(100, mean = 50, sd = 10), 1),
  SEX = factor(sample(c("Male", "Female"), 100, replace = TRUE)),
  WEIGHT = round(rnorm(100, mean = 70, sd = 15), 1),
  BMI = round(rnorm(100, mean = 25, sd = 5), 2),
  COUNTRY = factor(sample(c("US", "China", "EU"), 100, replace = TRUE))
)

# 测试1：无分组变量
cat("测试1：无分组变量...\n")
tbl1 <- perform_t_dm_analysis(
  data = adsl,
  variables = c("AGE", "SEX", "WEIGHT"),
  by_var = NULL,
  table_title = "测试表格1"
)
if (!is.null(tbl1)) {
  cat("  成功！表格生成。\n")
  print(tbl1)
} else {
  cat("  失败。\n")
}

# 测试2：有分组变量
cat("\n测试2：有分组变量...\n")
tbl2 <- perform_t_dm_analysis(
  data = adsl,
  variables = c("AGE", "SEX", "WEIGHT"),
  by_var = "TRT",
  table_title = "测试表格2"
)
if (!is.null(tbl2)) {
  cat("  成功！表格生成。\n")
  print(tbl2)
} else {
  cat("  失败。\n")
}

# 测试3：自定义总计列
cat("\n测试3：自定义总计列...\n")
total_settings <- list(
  list(name = "总计 Placebo", groups = c("Placebo")),
  list(name = "总计 Drug", groups = c("Drug"))
)
tbl3 <- perform_t_dm_analysis(
  data = adsl,
  variables = c("AGE", "SEX"),
  by_var = "TRT",
  total_cols_settings = total_settings,
  table_title = "测试表格3"
)
if (!is.null(tbl3)) {
  cat("  成功！表格生成。\n")
  print(tbl3)
} else {
  cat("  失败。\n")
}

# 测试4：代码生成
cat("\n测试4：代码生成...\n")
code <- generate_t_dm_code(
  variables = c("AGE", "SEX"),
  by_var = "TRT",
  total_cols_settings = total_settings,
  table_title = "测试表格"
)
cat(code, "\n")

cat("\n所有测试完成。\n")