# 逻辑回归分析模块

# 逻辑回归参数UI
logistic_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  tagList(
    selectInput(ns("logistic_response"), "响应变量", choices = numeric_vars),
    selectizeInput(ns("logistic_predictors"), "预测变量", choices = names(data), multiple = TRUE)
  )
}

# 逻辑回归分析
perform_logistic_analysis <- function(data, logistic_response, logistic_predictors) {
  req(logistic_response, logistic_predictors)
  
  formula <- as.formula(
    paste(logistic_response, "~", paste(logistic_predictors, collapse = "+"))
  )
  
  model <- glm(formula, data = data, family = binomial())
  result <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  
  return(result)
}