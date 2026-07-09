# 卡方检验模块

if (file.exists("modules/common/analysis/stat_analysis_submodule_copy.R")) {
  source("modules/common/analysis/stat_analysis_submodule_copy.R")
} else {
  source(file.path("..", "modules", "common", "analysis", "stat_analysis_submodule_copy.R"))
}
if (file.exists("modules/common/analysis/analysis_shared.R")) {
  source("modules/common/analysis/analysis_shared.R")
} else {
  source(file.path("..", "modules", "common", "analysis", "analysis_shared.R"))
}
ensure_stat_analysis_dependencies()
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
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x) || is.logical(x))]
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

cmh_params_ui <- function(ns, data) {
  copy <- STAT_ANALYSIS_SUBMODULE_COPY$cmh
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x) || is.logical(x))]
  tagList(
    app_card_note(copy$intro),
    app_card_panel(
      tags$strong("变量选择"),
      app_card_note(copy$variables),
      selectInput(ns("cmh_var1"), "行变量", choices = factor_vars),
      selectInput(ns("cmh_var2"), "列变量", choices = factor_vars),
      selectInput(ns("cmh_strata"), "分层变量", choices = factor_vars)
    )
  )
}

prepare_categorical_test_data <- function(data, vars, analysis_name) {
  if (!is.data.frame(data)) stop(paste0(analysis_name, "输入数据必须是 data.frame。"))
  if (any(is.na(vars)) || any(!nzchar(as.character(vars)))) stop(paste0(analysis_name, "变量不能为空。"))
  missing_vars <- vars[!vars %in% names(data)]
  if (length(missing_vars) > 0) stop(paste0("变量不存在: ", paste(missing_vars, collapse = ", ")))
  if (length(unique(vars)) != length(vars)) stop("分类检验变量不能重复。")
  df <- data[stats::complete.cases(data[, vars, drop = FALSE]), vars, drop = FALSE]
  if (nrow(df) == 0) stop(paste0(analysis_name, "没有可用的完整观测。"))
  for (v in vars) {
    df[[v]] <- factor(df[[v]])
    if (nlevels(df[[v]]) < 2) {
      stop(paste0("变量 ", v, " 至少需要两个非缺失水平。"))
    }
  }
  df
}

# 卡方检验
perform_chisq_analysis <- function(data, chisq_var1, chisq_var2) {
  shiny::req(chisq_var1, chisq_var2)

  analysis_data <- prepare_categorical_test_data(data, c(chisq_var1, chisq_var2), "卡方检验")
  table <- table(analysis_data[[chisq_var1]], analysis_data[[chisq_var2]])
  test <- suppressWarnings(chisq.test(table))

  result <- data.frame(
    检验 = "Pearson 卡方检验",
    统计量 = unname(test$statistic),
    自由度 = unname(test$parameter),
    P值 = format_p_value_regression(test$p.value),
    check.names = FALSE
  )

  result
}

perform_cmh_analysis <- function(data, cmh_var1, cmh_var2, cmh_strata) {
  shiny::req(cmh_var1, cmh_var2, cmh_strata)

  analysis_data <- prepare_categorical_test_data(data, c(cmh_var1, cmh_var2, cmh_strata), "CMH检验")
  table <- xtabs(stats::as.formula(paste(
    "~",
    paste(
      vapply(c(cmh_var1, cmh_var2, cmh_strata), analysis_quote_formula_name, character(1)),
      collapse = " + "
    )
  )), data = analysis_data)
  test <- mantelhaen.test(table)

  result <- data.frame(
    检验 = "Cochran-Mantel-Haenszel 检验",
    统计量 = unname(test$statistic),
    自由度 = if (!is.null(test$parameter)) unname(test$parameter) else NA_real_,
    P值 = format_p_value_regression(test$p.value),
    check.names = FALSE
  )
  if (!is.null(test$estimate)) {
    result$共同OR <- unname(test$estimate)
  }
  if (!is.null(test$conf.int) && length(test$conf.int) == 2) {
    result$`95%CI` <- sprintf("%.2f (%.2f, %.2f)", unname(test$estimate), test$conf.int[[1]], test$conf.int[[2]])
  }

  result
}

# 任务历史回填
apply_chisq_state <- function(session, extra) {
  if (!is.list(extra)) return(invisible(FALSE))
  if (!is.null(extra$chisq_var1) && nzchar(extra$chisq_var1))
    updateSelectInput(session, "chisq_var1", selected = extra$chisq_var1)
  if (!is.null(extra$chisq_var2) && nzchar(extra$chisq_var2))
    updateSelectInput(session, "chisq_var2", selected = extra$chisq_var2)
  invisible(TRUE)
}

apply_cmh_state <- function(session, extra) {
  if (!is.list(extra)) return(invisible(FALSE))
  if (!is.null(extra$cmh_var1) && nzchar(extra$cmh_var1))
    updateSelectInput(session, "cmh_var1", selected = extra$cmh_var1)
  if (!is.null(extra$cmh_var2) && nzchar(extra$cmh_var2))
    updateSelectInput(session, "cmh_var2", selected = extra$cmh_var2)
  if (!is.null(extra$cmh_strata) && nzchar(extra$cmh_strata))
    updateSelectInput(session, "cmh_strata", selected = extra$cmh_strata)
  invisible(TRUE)
}
