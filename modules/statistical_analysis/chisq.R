# 卡方检验模块

# 卡方检验参数UI
chisq_params_ui <- function(ns, data) {
  factor_vars <- names(data)[sapply(data, is.factor)]
  tagList(
    selectInput(ns("chisq_var1"), "变量1", choices = factor_vars),
    selectInput(ns("chisq_var2"), "变量2", choices = factor_vars)
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