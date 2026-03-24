# 逻辑回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

if (!exists("ensure_stat_analysis_dependencies", mode = "function") || !exists("build_regression_split_facet_gt", mode = "function")) {
  source("modules/common/analysis_shared.R")
}
ensure_stat_analysis_dependencies()

# 逻辑回归参数UI
logistic_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x))]
  
  tagList(
    fluidRow(
      column(6,
             selectInput(ns("logistic_response"), "响应变量 (Response)", choices = numeric_vars),
             bsTooltip(ns("logistic_response"), "二分类因变量 (0/1 或 No/Yes)", placement = "top", trigger = "hover")
      )
    ),
    fluidRow(
      column(6,
             selectInput(ns("logistic_strata"), "亚组变量 (Split, 行分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_strata"), "按该变量分组后，分别拟合并以行分组方式展示结果（split）", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("logistic_facet"), "分组变量 (Facet, 列分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_facet"), "按该变量分组后，以列分组方式并排展示回归结果", placement = "top", trigger = "hover")
      )
    ),
    fluidRow(
      column(12,
             selectInput(ns("logistic_model_strata"), "分层变量 (控制项) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_model_strata"), "该变量作为模型控制项进入回归，用于分层变量控制", placement = "top", trigger = "hover")
      )
    ),
    uiOutput(ns("logistic_event_mapping_ui")),
    
    selectizeInput(ns("logistic_predictors"), "预测变量 (Predictors)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("logistic_predictors"), "纳入模型的自变量 (解释变量)", placement = "top", trigger = "hover")
  )
}

# 逻辑回归分析
perform_logistic_analysis <- function(data, logistic_response, logistic_predictors, logistic_strata = NULL, logistic_facet = NULL, logistic_event_value = NULL, logistic_model_strata = NULL) {
  shiny::req(logistic_response)
  
  # 验证变量
  if (!logistic_response %in% names(data)) stop(paste("响应变量", logistic_response, "不存在"))
  missing_preds <- logistic_predictors[!logistic_predictors %in% names(data)]
  if (length(missing_preds) > 0) stop(paste("预测变量不存在:", paste(missing_preds, collapse = ", ")))

  strata_var <- normalize_optional_var(logistic_strata)
  facet_var <- normalize_optional_var(logistic_facet)
  model_strata_var <- normalize_optional_var(logistic_model_strata)
  validate_regression_inputs(
    data = data,
    response = logistic_response,
    predictors = logistic_predictors,
    split_var = strata_var,
    facet_var = facet_var,
    model_strata_var = model_strata_var,
    analysis_name = "逻辑回归"
  )
  model_notes <- character(0)
  add_note <- function(msg) {
    txt <- trimws(as.character(msg))
    if (nzchar(txt) && !(txt %in% model_notes)) {
      model_notes <<- c(model_notes, txt)
    }
  }

  var_labels <- sapply(logistic_predictors, function(v) {
    lv <- attr(data[[v]], "label", exact = TRUE)
    if (is.null(lv) || !nzchar(trimws(as.character(lv)[1]))) v else trimws(as.character(lv)[1])
  }, USE.NAMES = TRUE)

  response_vals <- unique(as.character(data[[logistic_response]][!is.na(data[[logistic_response]])]))
  if (length(response_vals) < 2) {
    stop("逻辑回归响应变量至少需要两个非缺失取值。")
  }
  event_val <- as.character(logistic_event_value)
  if (is.null(logistic_event_value) || !event_val %in% response_vals) {
    event_val <- if ("1" %in% response_vals) "1" else response_vals[1]
  }
  data[[logistic_response]] <- ifelse(
    as.character(data[[logistic_response]]) == event_val, 1,
    ifelse(!is.na(data[[logistic_response]]), 0, NA_real_)
  )
  add_note(paste0("响应变量映射：事件=", event_val, "，其余非缺失取值映射为非事件。"))
  for (v in names(var_labels)) {
    attr(data[[v]], "label") <- unname(var_labels[[v]])
  }

  term_to_display <- function(term) {
    t <- as.character(term)
    if (is.na(t) || !nzchar(t)) return(t)
    ordered <- logistic_predictors[order(nchar(logistic_predictors), decreasing = TRUE)]
    hit <- ordered[startsWith(t, ordered)]
    if (length(hit) == 0) return(t)
    v <- hit[1]
    suffix <- substring(t, nchar(v) + 1)
    paste0(unname(var_labels[[v]]), suffix)
  }

  get_levels_all <- function(x) {
    if (is.factor(x)) {
      levels(x)
    } else {
      ux <- unique(as.character(x))
      ux[!is.na(ux)]
    }
  }
  normalize_subgroup_levels <- function(v) {
    lv <- as.character(v)
    if (all(c("男", "女") %in% lv)) return(c("男", "女"))
    if (all(c("M", "F") %in% lv)) return(c("M", "F"))
    if (all(c("Male", "Female") %in% lv)) return(c("Male", "Female"))
    lv
  }
  split_levels <- if (!is.null(strata_var)) normalize_subgroup_levels(get_levels_all(data[[strata_var]])) else character(0)

  count_effective_n <- function(df_sub) {
    vars <- unique(c(logistic_response, logistic_predictors))
    vars <- vars[vars %in% names(df_sub)]
    if (length(vars) == 0) return(0L)
    sum(stats::complete.cases(df_sub[, vars, drop = FALSE]))
  }

  predictor_key <- function(term_raw) {
    ordered <- logistic_predictors[order(nchar(logistic_predictors), decreasing = TRUE)]
    hit <- ordered[startsWith(as.character(term_raw), ordered)]
    if (length(hit) == 0) return(NA_character_)
    hit[1]
  }

  fit_tidy_interaction <- function(df_in, pred, strata_nm) {
    ctrl_terms <- if (!is.null(model_strata_var) && !identical(model_strata_var, strata_nm)) model_strata_var else NULL
    base_terms <- setdiff(logistic_predictors, pred)
    f1 <- stats::reformulate(c(base_terms, pred, strata_nm, ctrl_terms, paste0(pred, ":", strata_nm)), response = logistic_response)
    tryCatch({
      m1 <- stats::glm(f1, data = df_in, family = binomial())
      broom::tidy(m1)
    }, warning = function(w) {
      add_note(paste0("亚组交互检验提示(", pred, "): ", conditionMessage(w)))
      NULL
    }, error = function(e) {
      add_note(paste0("亚组交互检验失败(", pred, "): ", conditionMessage(e)))
      NULL
    })
  }
  model_terms <- unique(c(logistic_predictors, model_strata_var))
  formula_str <- paste(logistic_response, "~", paste(model_terms, collapse = "+"))
  formula <- as.formula(formula_str)

  build_tbl <- function(df_sub) {
    model <- glm(formula, data = df_sub, family = binomial())
    gtsummary::tbl_regression(model, exponentiate = TRUE) %>%
      gtsummary::add_n() %>%
      gtsummary::add_global_p() %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "预测变量", p.value = "P值")
  }

  format_p <- function(p) {
    format_p_value_regression(p)
  }

  format_or_ci <- function(est, low, high) {
    est <- suppressWarnings(as.numeric(est))
    low <- suppressWarnings(as.numeric(low))
    high <- suppressWarnings(as.numeric(high))
    if (is.na(est)) return("NA")
    if (any(is.na(c(low, high)))) return(sub("\\.?0+$", "", sprintf("%.4f", est)))
    paste0(
      sub("\\.?0+$", "", sprintf("%.4f", est)),
      " (", sub("\\.?0+$", "", sprintf("%.4f", low)), ", ",
      sub("\\.?0+$", "", sprintf("%.4f", high)), ")"
    )
  }

  apply_clinical_style <- function(gt_tbl) {
    col_names <- tryCatch(names(gt_tbl[["_data"]]), error = function(e) character(0))
    left_cols <- intersect(c("预测变量", "label", "亚组"), col_names)
    if (length(left_cols) == 0) {
      left_cols <- 1
    }
    styled <- apply_sci_gt_style(
      gt_tbl,
      title = NULL,
      footnotes = NULL,
      left_columns = left_cols
    )
    if ("亚组" %in% col_names) {
      styled <- styled %>%
        gt::cols_align(align = "left", columns = c("亚组")) %>%
        gt::tab_style(
          style = gt::cell_text(indent = gt::px(4)),
          locations = gt::cells_body(columns = "亚组")
        )
    }
    styled
  }

  build_strata_first_gt <- function(df_in, strata_var = NULL, facet_var = NULL) {
    strata_vals <- if (is.null(strata_var)) "总体" else normalize_subgroup_levels(get_levels_all(df_in[[strata_var]]))
    int_p <- if (!is.null(strata_var)) {
      compute_interaction_p_map(
        df_in = df_in,
        predictors = logistic_predictors,
        strata_nm = strata_var,
        strata_levels = strata_vals,
        fit_tidy_fn = fit_tidy_interaction,
        facet_var = facet_var
      )
    } else character(0)

    fit_tidy_fn <- function(sub_data, sval, fval) {
      fit <- tryCatch(glm(formula, data = sub_data, family = binomial()), error = function(e) {
        if (is.null(facet_var)) {
          add_note(paste0("亚组[", sval, "]建模失败: ", conditionMessage(e)))
        } else {
          add_note(paste0("亚组[", sval, "]分组[", fval, "]建模失败: ", conditionMessage(e)))
        }
        NULL
      })
      if (is.null(fit)) return(NULL)
      tid <- tryCatch(broom::tidy(fit), error = function(e) {
        if (is.null(facet_var)) {
          add_note(paste0("亚组[", sval, "]结果整理失败: ", conditionMessage(e)))
        } else {
          add_note(paste0("亚组[", sval, "]分组[", fval, "]结果整理失败: ", conditionMessage(e)))
        }
        NULL
      })
      if (is.null(tid) || nrow(tid) == 0) return(NULL)
      beta <- if ("estimate" %in% names(tid)) tid$estimate else rep(NA_real_, nrow(tid))
      se <- if ("std.error" %in% names(tid)) tid$std.error else rep(NA_real_, nrow(tid))
      beta <- suppressWarnings(as.numeric(beta))
      se <- suppressWarnings(as.numeric(se))
      tid$estimate <- exp(beta)
      tid$conf.low <- exp(beta - 1.96 * se)
      tid$conf.high <- exp(beta + 1.96 * se)
      tid
    }

    build_regression_split_facet_gt(
      df_in = df_in,
      predictors = logistic_predictors,
      strata_var = strata_var,
      facet_var = facet_var,
      strata_vals = strata_vals,
      metric_label = "OR (95% CI)",
      fit_tidy_fn = fit_tidy_fn,
      term_to_display_fn = term_to_display,
      predictor_key_fn = predictor_key,
      count_effective_n_fn = count_effective_n,
      format_estimate_fn = format_or_ci,
      format_p_fn = format_p,
      apply_style_fn = apply_clinical_style,
      add_note_fn = add_note,
      int_p_map = int_p,
      get_int_p_fn = get_interaction_p_value
    )
  }

  if (is.null(strata_var) && is.null(facet_var)) {
    model <- glm(formula, data = data, family = binomial())
    tbl <- gtsummary::tbl_regression(model, exponentiate = TRUE) %>%
      gtsummary::add_global_p() %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "预测变量", p.value = "P值")
    gt_table <- gtsummary::as_gt(tbl) %>% apply_clinical_style()
  } else if (is.null(strata_var) && !is.null(facet_var)) {
    facet_vals <- unique(data[[facet_var]])
    facet_vals <- facet_vals[!is.na(facet_vals)]
    facet_tbls <- list()
    facet_headers <- character(0)
    for (val in facet_vals) {
      sub_data <- data[data[[facet_var]] == val, , drop = FALSE]
      if (nrow(sub_data) > 0) {
        tryCatch({
          facet_tbls[[length(facet_tbls) + 1]] <- build_tbl(sub_data)
          n_val <- nrow(sub_data)
          val_text <- as.character(val)
          if (!grepl("组$", val_text)) val_text <- paste0(val_text, "组")
          facet_headers <- c(facet_headers, paste0(val_text, " (N=", n_val, ")"))
        }, error = function(e) warning(paste("分组", val, "建模失败:", e$message)))
      }
    }
    if (length(facet_tbls) == 0) stop("无法为任何分组生成模型结果，请检查数据样本量或变量选择。")
    tbl <- if (length(facet_tbls) == 1) facet_tbls[[1]] else gtsummary::tbl_merge(tbls = facet_tbls, tab_spanner = facet_headers)
    gt_table <- gtsummary::as_gt(tbl) %>% apply_clinical_style()
  } else {
    gt_table <- build_strata_first_gt(data, strata_var, facet_var)
  }

  interpretation <- "<h4><b>结果解读 (Result Interpretation):</b></h4><ul>"
  if (!is.null(strata_var)) interpretation <- paste0(interpretation, "<li><b>亚组(split):</b> ", strata_var, "（按变量分组独立拟合）</li>")
  if (!is.null(strata_var) && length(split_levels) > 0) interpretation <- paste0(interpretation, "<li><b>亚组差异P值定义:</b> 以", split_levels[1], "为参考，基于“预测变量×亚组”交互项检验得到；值显示在对应比较亚组行。</li>")
  if (!is.null(strata_var) && !is.null(facet_var)) interpretation <- paste0(interpretation, "<li><b>列分组下亚组差异P值:</b> 每个列分组在其子数据内独立计算并展示。</li>")
  if (!is.null(facet_var)) interpretation <- paste0(interpretation, "<li><b>列分组(分组):</b> ", facet_var, "</li>")
  if (!is.null(model_strata_var)) interpretation <- paste0(interpretation, "<li><b>模型strata控制变量:</b> 模型中纳入", model_strata_var, "作为控制项。</li>")
  if (is.null(strata_var) && is.null(facet_var)) interpretation <- paste0(interpretation, "<li>未设置亚组/分组，展示总体模型结果。</li>")
  skipped_n <- if (exists("gt_table")) attr(gt_table, "skipped_models", exact = TRUE) else NULL
  if (!is.null(skipped_n) && is.numeric(skipped_n) && skipped_n > 0) {
    interpretation <- paste0(interpretation, "<li><b>稳定性提示:</b> 有 ", skipped_n, " 个子模型因样本不足或无法估计被自动跳过，表格以可稳定估计结果展示。</li>")
    add_note(paste0("有", skipped_n, "个子模型因样本不足或无法估计被自动跳过。"))
  }
  interpretation <- paste0(interpretation, "</ul>")
  
  return(list(
    table = gt_table,
    interpretation = shiny::HTML(interpretation),
    model_notes = model_notes,
    code = generate_logistic_code("data", logistic_response, logistic_predictors, strata_var, facet_var, event_val, model_strata_var)
  ))
}

generate_logistic_code <- function(data_name = "data", logistic_response, logistic_predictors, logistic_strata = NULL, logistic_facet = NULL, logistic_event_value = "1", logistic_model_strata = NULL) {
  preds_txt <- if (length(logistic_predictors) > 0) paste0("c(", paste(sprintf("\"%s\"", logistic_predictors), collapse = ", "), ")") else "character(0)"
  strata_txt <- if (is.null(logistic_strata)) "NULL" else paste0("\"", logistic_strata, "\"")
  facet_txt <- if (is.null(logistic_facet)) "NULL" else paste0("\"", logistic_facet, "\"")
  model_strata_txt <- if (is.null(logistic_model_strata)) "NULL" else paste0("\"", logistic_model_strata, "\"")
  build_repro_code_template(list(
    list(
      title = "Load packages",
      lines = c("library(stats)", "library(broom)", "library(gtsummary)", "library(gt)")
    ),
    list(
      title = "Set analysis parameters",
      lines = c(
        paste0("data <- ", data_name),
        paste0("response <- \"", logistic_response, "\""),
        paste0("predictors <- ", preds_txt),
        paste0("split_var <- ", strata_txt),
        paste0("facet_var <- ", facet_txt),
        paste0("model_strata_var <- ", model_strata_txt),
        paste0("event_value <- \"", logistic_event_value, "\"")
      )
    ),
    list(
      title = "Run analysis in RStudio",
      lines = c(
        "resp_vals <- unique(as.character(data[[response]][!is.na(data[[response]])]))",
        "ev <- as.character(event_value)",
        "if (is.null(event_value) || !ev %in% resp_vals) ev <- if (\"1\" %in% resp_vals) \"1\" else resp_vals[1]",
        "data[[response]] <- ifelse(as.character(data[[response]]) == ev, 1, ifelse(!is.na(data[[response]]), 0, NA_real_))",
        "split_levels <- if (!is.null(split_var)) unique(as.character(stats::na.omit(data[[split_var]]))) else \"总体\"",
        "facet_levels <- if (!is.null(facet_var)) unique(as.character(stats::na.omit(data[[facet_var]]))) else \"__ALL__\"",
        "res_list <- list()",
        "for (s in split_levels) {",
        "  ds <- if (is.null(split_var)) data else data[as.character(data[[split_var]]) == as.character(s), , drop = FALSE]",
        "  for (f in facet_levels) {",
        "    df_sub <- if (is.null(facet_var)) ds else ds[as.character(ds[[facet_var]]) == as.character(f), , drop = FALSE]",
        "    if (nrow(df_sub) == 0) next",
        "    model_terms <- unique(c(predictors, model_strata_var))",
        "    fml <- as.formula(paste(response, \"~\", paste(model_terms, collapse = \"+\")))",
        "    fit <- stats::glm(fml, data = df_sub, family = stats::binomial())",
        "    td <- broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE)",
        "    td$亚组 <- if (is.null(split_var)) \"总体\" else as.character(s)",
        "    td$列分组 <- if (is.null(facet_var)) \"总体\" else as.character(f)",
        "    res_list[[length(res_list) + 1L]] <- td",
        "  }",
        "}",
        "overall_tbl <- dplyr::bind_rows(res_list)"
      )
    ),
    list(
      title = "Inspect outputs",
      lines = c(
        "print(overall_tbl)"
      )
    )
  ))
}
