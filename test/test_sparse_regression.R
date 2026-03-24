library(shiny)
library(dplyr)
library(survival)

source("modules/common/table_export.R")
source("modules/common/analysis_format.R")
source("modules/common/analysis_shared.R")
source("modules/statistical_analysis/linear.R")
source("modules/statistical_analysis/logistic.R")
source("modules/statistical_analysis/cox.R")

# 1. 构造极端稀疏数据集
build_sparse_data <- function() {
  data.frame(
    # 响应变量
    Y_cont = c(1.2, NA, 3.4, 4.5, NA, 6.7, 7.8, 8.9, 9.0, 10.1),
    Y_bin = factor(c("Yes", "No", NA, "Yes", "No", "Yes", NA, "No", "No", "Yes")),
    TIME = c(10, 20, 30, NA, 50, 60, 70, 80, NA, 100),
    STATUS = c(1, 0, 1, 1, 0, NA, 1, 0, 1, 0),
    
    # 分组变量 (极端稀疏，某些组只有一个样本或全是 NA)
    TRT = factor(c("A", "A", "A", "A", "A", "B", "B", "C", "C", NA)),
    SITE = factor(c("S1", "S1", "S2", "S2", "S2", "S1", "S1", NA, "S2", "S2")),
    
    # 预测变量 (连续变量包含大量 NA)
    AGE = c(50, NA, 60, 70, NA, NA, 80, 90, 55, NA),
    
    # 预测变量 (分类变量，某个水平在某个亚组中可能完全没有)
    SEX = factor(c("M", "M", "F", "M", "F", "M", "F", "F", NA, "M")),
    
    stringsAsFactors = FALSE
  )
}

df_sparse <- build_sparse_data()

# 辅助测试函数
run_sparse_test <- function(scenario_name, test_expr) {
  cat(sprintf("\n=== Testing Scenario: %s ===\n", scenario_name))
  tryCatch({
    res <- test_expr
    cat("[PASS] Successfully generated table.\n")
    # 检查返回对象
    if (is.list(res) && !is.null(res$table)) {
      data_tbl <- res$table[["_data"]]
      cat(sprintf("Table dimensions: %d rows, %d cols\n", nrow(data_tbl), ncol(data_tbl)))
      # 打印前几行看看结构
      print(head(data_tbl, 3))
    }
  }, error = function(e) {
    cat(sprintf("[FAIL] Error: %s\n", e$message))
  })
}

# 场景 1: 线性回归，带极端稀疏的分类和连续预测变量
run_sparse_test("Linear Regression - Sparse Predictors", {
  perform_linear_analysis(
    data = df_sparse,
    linear_response = "Y_cont",
    linear_predictors = c("AGE", "SEX"),
    linear_strata = NULL,
    linear_facet = NULL,
    linear_reference_map = list(SEX = "F")
  )
})

# 场景 2: 逻辑回归，带亚组和列分组 (高度交叉，必然产生无法拟合的子模型)
run_sparse_test("Logistic Regression - Highly Crossed (Strata + Facet)", {
  perform_logistic_analysis(
    data = df_sparse,
    logistic_response = "Y_bin",
    logistic_predictors = c("AGE", "SEX"),
    logistic_strata = "SITE",
    logistic_facet = "TRT",
    logistic_event_value = "Yes",
    logistic_reference_map = list(SEX = "F"),
    total_cols_settings = list(list(name = "Total A+B", groups = c("A", "B")))
  )
})

# 场景 3: Cox回归，极端稀疏状态变量和时间变量
run_sparse_test("Cox Regression - Sparse Survival Data", {
  perform_cox_analysis(
    data = df_sparse,
    cox_time = "TIME",
    cox_status = "STATUS",
    cox_covariates = c("AGE", "SEX"),
    cox_strata = NULL,
    cox_facet = "TRT",
    cox_event_value = "1",
    cox_reference_map = list(SEX = "M")
  )
})

cat("\nSparse dataset testing complete.\n")