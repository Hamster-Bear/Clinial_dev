# 方差分析模块

if (!exists("app_card_note", mode = "function") || !exists("app_card_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}

# 方差分析参数UI
anova_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, is.factor)]
  tagList(
    app_card_note("ANOVA 参数区已接入公共壳分组样式；本轮只统一说明块与参数分区，不调整方差分析公式与结果输出逻辑。"),
    app_card_panel(
      tags$strong("响应变量"),
      app_card_note("选择连续型响应变量，作为方差分析的因变量。"),
      selectInput(ns("anova_response"), "响应变量", choices = numeric_vars)
    ),
    app_card_panel(
      tags$strong("分组因素"),
      app_card_note("可同时选择一个或多个因子变量，后续仍按原有交互项公式拼接方式进行方差分析。"),
      selectizeInput(ns("anova_factors"), "分组变量", choices = factor_vars, multiple = TRUE)
    )
  )
}

# 方差分析
perform_anova_analysis <- function(data, anova_response, anova_factors) {
  req(anova_response, anova_factors)
  
  formula <- as.formula(
    paste(anova_response, "~", paste(anova_factors, collapse = "*"))
  )
  
  model <- aov(formula, data = data)
  result <- broom::tidy(model)
  
  return(result)
}
