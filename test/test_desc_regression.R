library(shiny)

module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}

source(module_path("modules/common/table_export.R"))
source(module_path("modules/statistical_analysis/desc.R"))

set.seed(20260305)

build_demo_data <- function() {
  data.frame(
    TRT = factor(sample(c("A", "B", "C"), 120, replace = TRUE)),
    SITE = factor(sample(c("中心1", "中心2", "中心3"), 120, replace = TRUE)),
    SEX = factor(sample(c("男", "女"), 120, replace = TRUE)),
    RACE = factor(sample(c("汉族", "回族", "满族"), 120, replace = TRUE)),
    AGE = rnorm(120, 54, 12),
    BMI = rnorm(120, 24.3, 3.9),
    stringsAsFactors = TRUE
  )
}

assert_gt_tbl <- function(x, scenario) {
  if (is.list(x) && "table" %in% names(x)) {
    x <- x$table
  }
  if (!inherits(x, "gt_tbl")) {
    stop(paste0("[", scenario, "] 输出不是 gt_tbl"))
  }
}

run_scenario <- function(df, scenario, variables, col_group_var, row_group_var, total_cols_settings = list()) {
  out <- perform_desc_analysis(
    data = df,
    variables = variables,
    col_group_var = col_group_var,
    row_group_var = row_group_var,
    total_cols_count = length(total_cols_settings),
    total_cols_settings = total_cols_settings,
    decimals = 2,
    auto_decimals = TRUE
  )
  
  if (is.list(out) && "table" %in% names(out)) {
    gt_obj <- out$table
  } else {
    gt_obj <- out
  }
  
  assert_gt_tbl(gt_obj, scenario)
  data_tbl <- gt_obj[["_data"]]
  if (is.null(data_tbl) || nrow(data_tbl) == 0) {
    stop(paste0("[", scenario, "] 输出数据为空"))
  }
  message("[PASS] ", scenario, " rows=", nrow(data_tbl), " cols=", ncol(data_tbl))
}

df <- build_demo_data()
df$AGE[sample(seq_len(nrow(df)), 8)] <- NA
df$BMI[sample(seq_len(nrow(df)), 10)] <- NA

run_scenario(
  df = df,
  scenario = "无分组",
  variables = c("SEX", "RACE", "AGE", "BMI"),
  col_group_var = "无",
  row_group_var = "无"
)

run_scenario(
  df = df,
  scenario = "仅列分组",
  variables = c("SEX", "AGE", "BMI"),
  col_group_var = "TRT",
  row_group_var = "无",
  total_cols_settings = list(list(name = "总计AB", groups = c("A", "B")))
)

run_scenario(
  df = df,
  scenario = "仅行分组",
  variables = c("SEX", "AGE"),
  col_group_var = "无",
  row_group_var = "SITE"
)

run_scenario(
  df = df,
  scenario = "行列分组加总计",
  variables = c("SEX", "AGE", "BMI"),
  col_group_var = "TRT",
  row_group_var = "SITE",
  total_cols_settings = list(
    list(name = "低剂量", groups = c("A")),
    list(name = "高剂量", groups = c("B", "C"))
  )
)

df_extreme <- data.frame(
  TRT = factor(c("A", "A", "B")),
  SITE = factor(c("中心1", "中心1", "中心2")),
  SEX = factor(c("男", "女", "男")),
  AGE = c(NA, NA, NA),
  BMI = c(22.5, NA, NA),
  stringsAsFactors = TRUE
)

run_scenario(
  df = df_extreme,
  scenario = "极端场景",
  variables = c("SEX", "AGE", "BMI"),
  col_group_var = "TRT",
  row_group_var = "SITE",
  total_cols_settings = list(list(name = "总计", groups = c("A", "B")))
)

message("描述性统计回归脚本执行完成")
