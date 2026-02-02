# 测试 AE SOC/PT 汇总表格模块
library(dplyr)
library(rtables)
library(tern)

# 加载子模块函数
source("modules/tables/t_ae_soc_pt.R")

# 使用示例数据（模拟）
set.seed(123)
n <- 100
sample_data <- data.frame(
  USUBJID = paste0("SUBJ-", 1:n),
  TRT = sample(c("Placebo", "Drug A", "Drug B"), n, replace = TRUE),
  SOC = sample(c("Cardiac", "Nervous", "Gastrointestinal"), n, replace = TRUE),
  PT = sample(c("Headache", "Nausea", "Dizziness", "Fatigue"), n, replace = TRUE),
  SAFFL = sample(c("Y", "N"), n, replace = TRUE, prob = c(0.8, 0.2)),
  stringsAsFactors = TRUE
)

cat("测试数据维度:", dim(sample_data), "\n")
cat("变量名:", names(sample_data), "\n")

# 测试分析函数
cat("\n=== 测试 perform_t_ae_soc_pt_analysis ===\n")
result <- perform_t_ae_soc_pt_analysis(
  data = sample_data,
  trt_var = "TRT",
  soc_var = "SOC",
  pt_var = "PT",
  saffl_var = "SAFFL",
  saffl_val = "Y"
)

if (!is.null(result)) {
  cat("表格生成成功！\n")
  cat("表格类别:", class(result), "\n")
  # 打印前几行
  print(result)
} else {
  cat("表格生成失败。\n")
}

# 测试参数 UI 函数（不运行 Shiny）
cat("\n=== 测试 t_ae_soc_pt_params_ui ===\n")
ui <- t_ae_soc_pt_params_ui(function(id) paste0("test-", id), sample_data)
cat("UI 对象类型:", class(ui), "\n")

cat("\n测试完成。\n")