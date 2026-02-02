# 测试带有总计列的 t_dm 模块
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
  SEX = factor(sample(c("Male", "Female"), 100, replace = TRUE))
)

# 总计列设置
total_settings <- list(
  list(name = "总计 Placebo", groups = c("Placebo")),
  list(name = "总计 Drug", groups = c("Drug"))
)

cat("测试带有总计列...\n")
tbl <- perform_t_dm_analysis(
  data = adsl,
  variables = c("AGE", "SEX"),
  by_var = "TRT",
  total_cols_settings = total_settings,
  table_title = "测试表格"
)
if (!is.null(tbl)) {
  cat("  成功！表格生成。\n")
  cat("  表格对象类型:", class(tbl), "\n")
} else {
  cat("  失败。\n")
}

cat("\n测试完成。\n")