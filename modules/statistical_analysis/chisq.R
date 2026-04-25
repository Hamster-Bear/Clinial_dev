# 卡方检验模块

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

# 卡方检验参数UI
chisq_params_ui <- function(ns, data) {
  copy <- STAT_ANALYSIS_SUBMODULE_COPY$chisq
  factor_vars <- names(data)[sapply(data, is.factor)]
  tagList(
    app_card_note(copy$intro),
    app_card_panel(
      tags$strong("变量选择"),
      app_card_note(copy$variables),
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
