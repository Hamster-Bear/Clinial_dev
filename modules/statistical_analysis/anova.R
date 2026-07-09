# 方差分析模块

if (file.exists("modules/common/analysis/stat_analysis_submodule_copy.R")) {
  source("modules/common/analysis/stat_analysis_submodule_copy.R")
} else {
  source(file.path("..", "modules", "common", "analysis", "stat_analysis_submodule_copy.R"))
}
if (!exists("analysis_build_formula", mode = "function")) {
  if (file.exists("modules/common/analysis/analysis_shared.R")) {
    source("modules/common/analysis/analysis_shared.R")
  } else {
    source(file.path("..", "modules", "common", "analysis", "analysis_shared.R"))
  }
}
if (exists("ensure_stat_analysis_dependencies", mode = "function")) {
  ensure_stat_analysis_dependencies()
}
if (!exists("format_p_value_regression", mode = "function")) {
  if (!exists("format_p_value_ama", mode = "function")) {
    if (file.exists("modules/common/export/table_export.R")) {
      source("modules/common/export/table_export.R")
    } else {
      source(file.path("..", "modules", "common", "export", "table_export.R"))
    }
  }
  if (file.exists("modules/common/analysis/analysis_format.R")) {
    source("modules/common/analysis/analysis_format.R")
  } else {
    source(file.path("..", "modules", "common", "analysis", "analysis_format.R"))
  }
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
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x) || is.logical(x))]
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
  shiny::req(anova_response, anova_factors)
  if (!is.data.frame(data)) stop("方差分析输入数据必须是 data.frame。")
  if (!anova_response %in% names(data)) stop(paste0("响应变量 ", anova_response, " 不存在。"))
  if (length(anova_factors) == 0) stop("方差分析至少需要一个分组变量。")
  missing_factors <- anova_factors[!anova_factors %in% names(data)]
  if (length(missing_factors) > 0) stop(paste0("分组变量不存在: ", paste(missing_factors, collapse = ", ")))
  if (anova_response %in% anova_factors) stop("响应变量不能同时作为分组变量。")

  model_vars <- unique(c(anova_response, anova_factors))
  analysis_data <- data[stats::complete.cases(data[, model_vars, drop = FALSE]), model_vars, drop = FALSE]
  if (nrow(analysis_data) == 0) stop("方差分析没有可用的完整观测。")
  for (v in anova_factors) {
    analysis_data[[v]] <- factor(analysis_data[[v]])
    if (nlevels(analysis_data[[v]]) < 2) {
      stop(paste0("分组变量 ", v, " 至少需要两个非缺失水平。"))
    }
  }

  interaction_pairs <- NULL
  if (length(anova_factors) > 1) {
    interaction_pairs <- utils::combn(anova_factors, 2, simplify = FALSE)
  }
  formula <- analysis_build_formula(anova_response, anova_factors, interaction_pairs = interaction_pairs)
  
  model <- aov(formula, data = analysis_data)
  result <- broom::tidy(model)
  result <- result[, intersect(c("term", "df", "sumsq", "meansq", "statistic", "p.value"), names(result)), drop = FALSE]
  if ("p.value" %in% names(result)) {
    result$P值 <- vapply(result$p.value, format_p_value_regression, character(1))
    result$p.value <- NULL
  }
  names(result)[names(result) == "term"] <- "项目"
  names(result)[names(result) == "df"] <- "自由度"
  names(result)[names(result) == "sumsq"] <- "平方和"
  names(result)[names(result) == "meansq"] <- "均方"
  names(result)[names(result) == "statistic"] <- "F值"
  result
}

# 任务历史回填
apply_anova_state <- function(session, extra) {
  if (!is.list(extra)) return(invisible(FALSE))
  if (!is.null(extra$anova_response) && nzchar(extra$anova_response))
    updateSelectInput(session, "anova_response", selected = extra$anova_response)
  if (!is.null(extra$anova_factors) && length(extra$anova_factors) > 0)
    updateSelectizeInput(session, "anova_factors", selected = extra$anova_factors)
  invisible(TRUE)
}
