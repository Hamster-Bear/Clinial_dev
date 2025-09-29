# 方差分析模块

# 方差分析参数UI
anova_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, is.factor)]
  tagList(
    selectInput(ns("anova_response"), "响应变量", choices = numeric_vars),
    selectizeInput(ns("anova_factors"), "分组变量", choices = factor_vars, multiple = TRUE)
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