# Cox回归分析模块

# Cox回归参数UI
cox_params_ui <- function(ns) {
  tagList(
    selectInput(ns("cox_time"), "时间变量 (Time)", choices = NULL),
    selectInput(ns("cox_status"), "删失变量 (Status)", choices = NULL),
    selectizeInput(ns("cox_covariates"), "协变量 (Covariates)", choices = NULL, multiple = TRUE),
    selectInput(ns("cox_strata"), "分层变量 (Strata) - 可选", choices = c("None", NULL))
  )
}

# Cox回归分析
perform_cox_analysis <- function(data, cox_time, cox_status, cox_covariates, cox_strata) {
  req(cox_time, cox_status)
  
  # 验证变量是否存在
  if (!cox_time %in% names(data)) {
    stop(paste("时间变量", cox_time, "不存在于数据中"))
  }
  if (!cox_status %in% names(data)) {
    stop(paste("状态变量", cox_status, "不存在于数据中"))
  }
  
  # 验证协变量是否存在
  if (!is.null(cox_covariates) && length(cox_covariates) > 0) {
    missing_covariates <- cox_covariates[!cox_covariates %in% names(data)]
    if (length(missing_covariates) > 0) {
      stop(paste("协变量不存在:", paste(missing_covariates, collapse = ", ")))
    }
  }
  
  # 直接构建公式，避免中间变量
  if (length(cox_covariates) > 0) {
    formula <- as.formula(paste("Surv(", cox_time, ",", cox_status, ") ~",
                                paste(cox_covariates, collapse = "+")))
  } else {
    formula <- as.formula(paste("Surv(", cox_time, ",", cox_status, ") ~ 1"))
  }
  
  # 添加分层变量
  if (!is.null(cox_strata) && cox_strata != "None") {
    if (!cox_strata %in% names(data)) {
      stop(paste("分层变量", cox_strata, "不存在于数据中"))
    }
    formula <- as.formula(paste0(deparse(formula), " + strata(", cox_strata, ")"))
  }
  
  # 执行Cox回归
  model <- survival::coxph(formula, data = data)
  
  # 提取结果
  result <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  
  return(result)
}