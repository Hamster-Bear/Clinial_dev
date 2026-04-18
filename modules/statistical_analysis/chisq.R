# 卡方检验模块

if (!exists("app_card_note", mode = "function") || !exists("app_card_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}

# 卡方检验参数UI
chisq_params_ui <- function(ns, data) {
  factor_vars <- names(data)[sapply(data, is.factor)]
  tagList(
    app_card_note("卡方检验参数区已接入公共壳分组样式；本轮只统一说明块与参数分区，不调整列联表构造与检验逻辑。"),
    app_card_panel(
      tags$strong("变量选择"),
      app_card_note("选择两列分类型变量，继续按原有列联表与卡方检验路径计算统计量、自由度和 P 值。"),
      selectInput(ns("chisq_var1"), "变量1", choices = factor_vars),
      selectInput(ns("chisq_var2"), "变量2", choices = factor_vars)
    )
  )
}

# 卡方检验
perform_chisq_analysis <- function(data, chisq_var1, chisq_var2) {
  req(chisq_var1, chisq_var2)
  
  table <- table(data[[chisq_var1]], data[[chisq_var2]])
  test <- chisq.test(table)
  
  result <- data.frame(
    Statistic = test$statistic,
    p.value = test$p.value,
    df = test$parameter
  )
  
  return(result)
}
