# 方差分析模块

if (file.exists("modules/common/stat_analysis_submodule_copy.R")) {
  source("modules/common/stat_analysis_submodule_copy.R")
} else {
  source(file.path("..", "modules", "common", "stat_analysis_submodule_copy.R"))
}
if (!exists("app_card_note", mode = "function") || !exists("app_card_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}

# 方差分析参数UI
anova_params_ui <- function(ns, data) {
  copy <- STAT_ANALYSIS_SUBMODULE_COPY$anova
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, is.factor)]
  tagList(
    app_card_note(copy$intro),
    app_card_panel(
      tags$strong("响应变量"),
      app_card_note(copy$response),
      selectInput(ns("anova_response"), "响应变量", choices = numeric_vars)
    ),
    app_card_panel(
      tags$strong("分组因素"),
      app_card_note(copy$factors),
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
