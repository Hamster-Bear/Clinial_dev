# 简单测试 t_dm 模块重构
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
  WEIGHT = round(rnorm(100, mean = 70, sd = 15), 1)
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
  # 不打印整个表格
  cat("  表格对象类型:", class(tbl1), "\n")
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
  cat("  表格对象类型:", class(tbl2), "\n")
} else {
  cat("  失败。\n")
}

cat("\n测试完成。\n")