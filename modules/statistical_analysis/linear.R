# 线性回归分析模块

# 线性回归参数UI
linear_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  tagList(
    selectInput(ns("linear_response"), "响应变量", choices = numeric_vars),
    selectizeInput(ns("linear_predictors"), "预测变量", choices = names(data), multiple = TRUE)
  )
}

# 线性回归分析
perform_linear_analysis <- function(data, linear_response, linear_predictors) {
  req(linear_response, linear_predictors)
  
  formula <- as.formula(
    paste(linear_response, "~", paste(linear_predictors, collapse = "+"))
  )
  
  model <- lm(formula, data = data)
  result <- broom::tidy(model, conf.int = TRUE)
  
  return(result)
}