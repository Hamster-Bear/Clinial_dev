# Cox回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

if (!exists("ensure_stat_analysis_dependencies", mode = "function") || !exists("build_regression_split_facet_gt", mode = "function")) {
  source("modules/common/analysis_shared.R")
}
ensure_stat_analysis_dependencies()

# Cox回归参数UI
cox_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x))]
  
  tagList(
    fluidRow(
      column(6,
             selectInput(ns("cox_time"), "时间变量 (Time)", choices = numeric_vars),
             bsTooltip(ns("cox_time"), "生存时间变量，通常为数值型 (如随访月数)", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("cox_status"), "删失变量 (Status)", choices = numeric_vars),
             bsTooltip(ns("cox_status"), "事件状态变量 (0=删失, 1=发生事件)", placement = "top", trigger = "hover")
      )
    ),
    
    fluidRow(
      column(6,
    selectInput(ns("cox_strata"), "亚组变量 (Subgroup) - 可选", choices = c("None", factor_vars)),
            bsTooltip(ns("cox_strata"), "按该变量分组后，分别拟合并以堆叠方式展示结果", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("cox_facet"), "队列/分组变量 (Cohort/Arm) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("cox_facet"), "按该变量分组后，以列分组方式并排展示Cox回归结果", placement = "top", trigger = "hover")
      )
    ),
    fluidRow(
      column(12,
             selectInput(ns("cox_model_strata"), "模型分层因素 (Stratification Factor) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("cox_model_strata"), "该变量将以strata()形式进入Cox模型进行基线风险分层控制", placement = "top", trigger = "hover")
      )
    ),
    
    uiOutput(ns("cox_total_cols_ui")),
    uiOutput(ns("cox_status_mapping_ui")),
    
    selectizeInput(ns("cox_covariates"), "协变量 (Covariates)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("cox_covariates"), "纳入 Cox 模型的协变量", placement = "top", trigger = "hover"),
    uiOutput(ns("cox_reference_ui"))
  )
}

# Cox回归分析
perform_cox_analysis <- function(data, cox_time, cox_status, cox_covariates, cox_strata, cox_facet = NULL, cox_event_value = NULL, cox_model_strata = NULL, cox_reference_map = NULL, total_cols_settings = list()) {
  shiny::req(cox_time, cox_status)
  
  # 验证变量是否存在
  if (!cox_time %in% names(data)) stop(paste("时间变量", cox_time, "不存在于数据中"))
  if (!cox_status %in% names(data)) stop(paste("状态变量", cox_status, "不存在于数据中"))
  
  # 验证协变量
  if (!is.null(cox_covariates) && length(cox_covariates) > 0) {
    missing_covariates <- cox_covariates[!cox_covariates %in% names(data)]
    if (length(missing_covariates) > 0) stop(paste("协变量不存在:", paste(missing_covariates, collapse = ", ")))
  }
  
  strata_var <- if (!is.null(cox_strata) && cox_strata != "None") cox_strata else NULL
  facet_var <- if (!is.null(cox_facet) && cox_facet != "None") cox_facet else NULL
  model_strata_var <- if (!is.null(cox_model_strata) && cox_model_strata != "None") cox_model_strata else NULL
  if (is.null(cox_covariates) || length(cox_covariates) == 0) stop("Cox回归至少需要一个协变量。")
  overlap_cov <- intersect(cox_covariates, unique(na.omit(c(cox_time, cox_status, strata_var, facet_var, model_strata_var))))
  if (length(overlap_cov) > 0) stop(paste0("协变量不能与时间/状态/亚组/分组/分层变量重复: ", paste(overlap_cov, collapse = ", ")))
  model_notes <- character(0)
  add_note <- function(msg) {
    txt <- trimws(as.character(msg))
    if (nzchar(txt) && !(txt %in% model_notes)) model_notes <<- c(model_notes, txt)
  }

  ref_pack <- prepare_predictor_reference_levels(data, cox_covariates, cox_reference_map)
  data <- ref_pack$data

  var_labels <- sapply(cox_covariates, function(v) {
    lv <- attr(data[[v]], "label", exact = TRUE)
    if (is.null(lv) || !nzchar(trimws(as.character(lv)[1]))) v else trimws(as.character(lv)[1])
  }, USE.NAMES = TRUE)
  pred_is_cat <- ref_pack$pred_is_cat
  pred_ref_level <- ref_pack$pred_ref_level
  cat_preds <- names(pred_ref_level)[!is.na(pred_ref_level)]
  if (length(cat_preds) > 0) {
    add_note(paste0(
      "分类变量参考组：",
      paste(
        sprintf("%s=%s", unname(var_labels[cat_preds]), unname(pred_ref_level[cat_preds])),
        collapse = "；"
      ),
      "。"
    ))
  }
  for (v in names(var_labels)) {
    attr(data[[v]], "label") <- unname(var_labels[[v]])
  }
  status_vals <- unique(as.character(data[[cox_status]][!is.na(data[[cox_status]])]))
  if (length(status_vals) < 2) {
    stop("Cox状态变量至少需要两个非缺失取值。")
  }
  event_val <- as.character(cox_event_value)
  if (is.null(cox_event_value) || !event_val %in% status_vals) {
    event_val <- if ("1" %in% status_vals) "1" else status_vals[1]
  }
  data[[cox_status]] <- ifelse(
    as.character(data[[cox_status]]) == event_val, 1,
    ifelse(!is.na(data[[cox_status]]), 0, NA_real_)
  )
  add_note(paste0("状态变量映射：事件=", event_val, "，其余非缺失取值映射为删失。"))

  term_to_display <- function(term) {
    t <- as.character(term)
    ordered <- cox_covariates[order(nchar(cox_covariates), decreasing = TRUE)]
    hit <- ordered[startsWith(t, ordered)]
    if (length(hit) == 0) return(t)
    v <- hit[1]
    suffix <- substring(t, nchar(v) + 1)
    if (isTRUE(pred_is_cat[[v]]) && nzchar(suffix)) {
      return(suffix)
    }
    unname(var_labels[[v]])
  }
  get_levels_all <- function(x) {
    if (is.factor(x)) levels(x) else {u <- unique(as.character(x)); u[!is.na(u)]}
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
    vars <- unique(c(cox_time, cox_status, cox_covariates))
    vars <- vars[vars %in% names(df_sub)]
    if (length(vars) == 0) return(0L)
    sum(stats::complete.cases(df_sub[, vars, drop = FALSE]))
  }
  predictor_key <- function(term_raw) {
    ordered <- cox_covariates[order(nchar(cox_covariates), decreasing = TRUE)]
    hit <- ordered[startsWith(as.character(term_raw), ordered)]
    if (length(hit) == 0) return(NA_character_)
    hit[1]
  }
  fit_tidy_interaction <- function(df_in, pred, strata_nm) {
    ctrl_term <- if (!is.null(model_strata_var) && !identical(model_strata_var, strata_nm)) paste0("strata(", model_strata_var, ")") else NULL
    base_terms <- setdiff(cox_covariates, pred)
    f_int <- stats::reformulate(c(base_terms, pred, strata_nm, ctrl_term, paste0(pred, ":", strata_nm)), response = paste0("survival::Surv(", cox_time, ",", cox_status, ")"))
    tryCatch({
      fit <- survival::coxph(f_int, data = df_in)
      broom::tidy(fit)
    }, warning = function(w) {
      add_note(paste0("亚组交互检验提示(", pred, "): ", conditionMessage(w)))
      NULL
    }, error = function(e) {
      add_note(paste0("亚组交互检验失败(", pred, "): ", conditionMessage(e)))
      NULL
    })
  }
  if (!is.null(strata_var) && !strata_var %in% names(data)) stop(paste("亚组变量", strata_var, "不存在于数据中"))
  if (!is.null(facet_var) && !facet_var %in% names(data)) stop(paste("分组变量", facet_var, "不存在于数据中"))
  if (!is.null(model_strata_var) && !model_strata_var %in% names(data)) stop(paste("分层变量", model_strata_var, "不存在于数据中"))
  if (!is.null(strata_var) && !is.null(facet_var) && identical(strata_var, facet_var)) {
    stop("亚组变量与分组变量不能相同")
  }

  # 构建公式字符串
  if (length(cox_covariates) > 0) {
    formula_str <- paste("survival::Surv(", cox_time, ",", cox_status, ") ~", paste(cox_covariates, collapse = "+"))
  } else {
    formula_str <- paste("survival::Surv(", cox_time, ",", cox_status, ") ~ 1")
  }
  
  formula <- as.formula(formula_str)
  strata_ctrl_formula <- if (!is.null(model_strata_var)) {
    as.formula(paste0(formula_str, " + strata(", model_strata_var, ")"))
  } else NULL
  analysis_formula <- if (!is.null(strata_ctrl_formula)) strata_ctrl_formula else formula

  build_tbl <- function(df_sub) {
    sub_model <- survival::coxph(analysis_formula, data = df_sub)
    tbl_tmp <- gtsummary::tbl_regression(sub_model, exponentiate = TRUE)
    tbl_tmp <- tryCatch(gtsummary::add_n(tbl_tmp), error = function(e) {
      add_note(paste0("Cox分组表N列提示: ", conditionMessage(e)))
      tbl_tmp
    })
    tbl_tmp <- tryCatch(gtsummary::add_global_p(tbl_tmp), error = function(e) tbl_tmp)
    tbl_tmp %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "预测变量", p.value = "P值")
  }

  # format_p <- function(p) {
  #   format_p_value_regression(p)
  # }
  if (!is.null(strata_ctrl_formula)) {
    strata_ctrl_ok <- tryCatch({
      suppressWarnings(survival::coxph(strata_ctrl_formula, data = data))
      TRUE
    }, error = function(e) {
      add_note(paste0("模型strata控制变量拟合失败: ", conditionMessage(e)))
      FALSE
    })
    if (isTRUE(strata_ctrl_ok)) {
      add_note(paste0("已并行执行模型strata控制变量模型：Surv(", cox_time, ", ", cox_status, ") ~ 协变量 + strata(", model_strata_var, ")。"))
    }
  }
  ph_global_p <- tryCatch({
    ph_model <- survival::coxph(analysis_formula, data = data)
    ph_obj <- survival::cox.zph(ph_model)
    ph_tbl <- as.data.frame(ph_obj$table)
    if ("GLOBAL" %in% rownames(ph_tbl)) as.numeric(ph_tbl["GLOBAL", ncol(ph_tbl)]) else as.numeric(ph_tbl[nrow(ph_tbl), ncol(ph_tbl)])
  }, error = function(e) NA_real_)
  if (!is.na(ph_global_p)) {
    add_note(paste0("比例风险假设检验（Schoenfeld，全局）P=", format_p_value_regression(ph_global_p), "。"))
    if (is.finite(ph_global_p) && ph_global_p < 0.05) {
      add_note("比例风险假设可能不满足（全局P<0.05），建议结合临床背景与诊断图进一步评估。")
    }
  }

  # format_hr_ci <- function(est, low, high) {
  #   est <- suppressWarnings(as.numeric(est))
  #   low <- suppressWarnings(as.numeric(low))
  #   high <- suppressWarnings(as.numeric(high))
  #   if (is.na(est)) return("NA")
  #   if (any(is.na(c(low, high)))) return(sub("\\.?0+$", "", sprintf("%.4f", est)))
  #   paste0(
  #     sub("\\.?0+$", "", sprintf("%.4f", est)),
  #     " (", sub("\\.?0+$", "", sprintf("%.4f", low)), ", ",
  #     sub("\\.?0+$", "", sprintf("%.4f", high)), ")"
  #   )
  # }

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
        predictors = cox_covariates,
        strata_nm = strata_var,
        strata_levels = strata_vals,
        fit_tidy_fn = fit_tidy_interaction,
        facet_var = facet_var
      )
    } else character(0)

    fit_tidy_fn <- function(sub_data, sval, fval) {
      fit <- tryCatch(survival::coxph(analysis_formula, data = sub_data), error = function(e) {
        if (is.null(facet_var)) {
          add_note(paste0("亚组[", sval, "]建模失败: ", conditionMessage(e)))
        } else {
          add_note(paste0("亚组[", sval, "]分组[", fval, "]建模失败: ", conditionMessage(e)))
        }
        NULL
      })
      if (is.null(fit)) return(NULL)
      tid <- tryCatch(broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE), error = function(e) {
        if (is.null(facet_var)) {
          add_note(paste0("亚组[", sval, "]结果整理失败: ", conditionMessage(e)))
        } else {
          add_note(paste0("亚组[", sval, "]分组[", fval, "]结果整理失败: ", conditionMessage(e)))
        }
        NULL
      })
      if (is.null(tid) || nrow(tid) == 0) return(NULL)
      tid
    }

    build_unified_regression_table(
      df_in = df_in,
      predictors = cox_covariates,
      strata_var = strata_var,
      facet_var = facet_var,
      strata_vals = strata_vals,
      metric_label = "HR (95% CI)",
      fit_tidy_fn = fit_tidy_fn,
      term_to_display_fn = term_to_display,
      predictor_key_fn = predictor_key,
      count_effective_n_fn = count_effective_n,
      format_estimate_fn = format_regression_stat,
      format_p_fn = format_p_value_regression,
      apply_style_fn = apply_clinical_style,
      add_note_fn = add_note,
      int_p_map = int_p,
      get_int_p_fn = get_interaction_p_value,
      categorical_ref_map = pred_ref_level[!is.na(pred_ref_level)],
      total_cols_settings = total_cols_settings
    )
  }

  # 统一使用 build_strata_first_gt (底层已替换为 build_unified_regression_table)
  gt_table <- build_strata_first_gt(data, strata_var, facet_var)

  interpretation <- "<h4><b>结果解读 (Result Interpretation):</b></h4><ul>"
  if (!is.null(strata_var)) interpretation <- paste0(interpretation, "<li><b>亚组(Subgroup):</b> ", strata_var, "（按变量分组独立拟合）</li>")
  if (!is.null(strata_var) && length(split_levels) > 0) interpretation <- paste0(interpretation, "<li><b>交互作用 P 值 (P for interaction):</b> 基于“协变量×亚组”交互项检验得到。</li>")
  if (!is.null(model_strata_var)) interpretation <- paste0(interpretation, "<li><b>模型分层因素 (Stratification Factor):</b> 模型中加入 strata(", model_strata_var, ") 进行基线风险控制。</li>")
  if (!is.null(facet_var)) interpretation <- paste0(interpretation, "<li><b>队列分组(Cohort/Arm):</b> ", facet_var, "</li>")
  if (is.null(strata_var) && is.null(facet_var)) interpretation <- paste0(interpretation, "<li>展示总体模型结果。</li>")
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
    code = generate_cox_code("data", cox_time, cox_status, cox_covariates, strata_var, facet_var, event_val, model_strata_var)
  ))
}

# 生成可复现R代码
generate_cox_code <- function(data_name = "data", cox_time, cox_status, cox_covariates, cox_strata, cox_facet = NULL, cox_event_value = "1", cox_model_strata = NULL) {
  covariates_txt <- if (length(cox_covariates) > 0) paste0("c(", paste(sprintf("\"%s\"", cox_covariates), collapse = ", "), ")") else "character(0)"
  strata_txt <- if (is.null(cox_strata)) "NULL" else paste0("\"", cox_strata, "\"")
  facet_txt <- if (is.null(cox_facet)) "NULL" else paste0("\"", cox_facet, "\"")
  model_strata_txt <- if (is.null(cox_model_strata)) "NULL" else paste0("\"", cox_model_strata, "\"")
  build_repro_code_template(list(
    list(
      title = "Load packages",
      lines = c("library(survival)", "library(broom)", "library(gtsummary)", "library(gt)")
    ),
    list(
      title = "Set analysis parameters",
      lines = c(
        paste0("data <- ", data_name),
        paste0("cox_time <- \"", cox_time, "\""),
        paste0("cox_status <- \"", cox_status, "\""),
        paste0("cox_covariates <- ", covariates_txt),
        paste0("cox_strata <- ", strata_txt),
        paste0("cox_facet <- ", facet_txt),
        paste0("cox_model_strata <- ", model_strata_txt),
        paste0("cox_event_value <- \"", cox_event_value, "\"")
      )
    ),
    list(
      title = "Run analysis in RStudio",
      lines = c(
        "status_vals <- unique(as.character(data[[cox_status]][!is.na(data[[cox_status]])]))",
        "event_val <- as.character(cox_event_value)",
        "if (is.null(cox_event_value) || !event_val %in% status_vals) event_val <- if (\"1\" %in% status_vals) \"1\" else status_vals[1]",
        "data[[cox_status]] <- ifelse(as.character(data[[cox_status]]) == event_val, 1, ifelse(!is.na(data[[cox_status]]), 0, NA_real_))",
        "split_levels <- if (!is.null(cox_strata)) unique(as.character(stats::na.omit(data[[cox_strata]]))) else \"总体\"",
        "facet_levels <- if (!is.null(cox_facet)) unique(as.character(stats::na.omit(data[[cox_facet]]))) else \"__ALL__\"",
        "res_list <- list()",
        "for (s in split_levels) {",
        "  ds <- if (is.null(cox_strata)) data else data[as.character(data[[cox_strata]]) == as.character(s), , drop = FALSE]",
        "  for (f in facet_levels) {",
        "    df_sub <- if (is.null(cox_facet)) ds else ds[as.character(ds[[cox_facet]]) == as.character(f), , drop = FALSE]",
        "    if (nrow(df_sub) == 0) next",
        "    rhs <- cox_covariates",
        "    if (!is.null(cox_model_strata) && nzchar(cox_model_strata)) rhs <- c(rhs, paste0(\"strata(\", cox_model_strata, \")\"))",
        "    fml <- as.formula(paste0(\"survival::Surv(\", cox_time, \",\", cox_status, \") ~ \", paste(rhs, collapse = \" + \")))",
        "    fit <- survival::coxph(fml, data = df_sub)",
        "    td <- broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE)",
        "    td$亚组 <- if (is.null(cox_strata)) \"总体\" else as.character(s)",
        "    td$列分组 <- if (is.null(cox_facet)) \"总体\" else as.character(f)",
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
