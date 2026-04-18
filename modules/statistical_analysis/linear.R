# 线性回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

if (file.exists("modules/common/analysis_shared.R")) {
  source("modules/common/analysis_shared.R")
} else {
  source(file.path("..", "modules", "common", "analysis_shared.R"))
}
if (!exists("app_card_note", mode = "function") || !exists("app_card_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}
ensure_stat_analysis_dependencies()

# 线性回归参数UI
linear_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x))]
  
  tagList(
    app_card_note("Linear 回归参数区已接入公共壳分组样式；本轮只统一参数分区与说明块，不改变建模、总计列或结果展示逻辑。"),
    app_card_panel(
      tags$strong("响应与分层"),
      app_card_note("先定义连续型响应变量，再按需设置亚组、分面与模型内分层因素。"),
      fluidRow(
        column(6,
               selectInput(ns("linear_response"), "响应变量 (Response)", choices = numeric_vars),
               bsTooltip(ns("linear_response"), "连续型因变量 (数值型)", placement = "top", trigger = "hover")
        )
      ),
      fluidRow(
        column(6,
               selectInput(ns("linear_strata"), "亚组变量 (Subgroup) - 可选", choices = c("None", factor_vars)),
               bsTooltip(ns("linear_strata"), "按该变量分组后，分别拟合并以堆叠方式展示结果", placement = "top", trigger = "hover")
        ),
        column(6,
               selectInput(ns("linear_facet"), "队列/分组变量 (Cohort/Arm) - 可选", choices = c("None", factor_vars)),
               bsTooltip(ns("linear_facet"), "按该变量分组后，以列分组方式并排展示回归结果", placement = "top", trigger = "hover")
        )
      ),
      fluidRow(
        column(12,
               selectInput(ns("linear_model_strata"), "模型分层因素 (Stratification Factor) - 可选", choices = c("None", factor_vars)),
               bsTooltip(ns("linear_model_strata"), "该变量作为模型控制项进入回归，用于控制基线混杂", placement = "top", trigger = "hover")
        )
      )
    ),
    app_card_panel(
      tags$strong("总计列配置"),
      app_card_note("继续保留自定义总计列配置，用于控制线性回归结果中的列展示。"),
      uiOutput(ns("linear_total_cols_ui"))
    ),
    app_card_panel(
      tags$strong("预测变量与参考组"),
      app_card_note("预测变量选择、分类变量参考组与后续模型公式保持原有处理方式。"),
      selectizeInput(ns("linear_predictors"), "预测变量 (Predictors)", choices = names(data), multiple = TRUE),
      bsTooltip(ns("linear_predictors"), "纳入模型的自变量 (解释变量)", placement = "top", trigger = "hover"),
      uiOutput(ns("linear_reference_ui"))
    )
  )
}

# 线性回归分析
perform_linear_analysis <- function(data, linear_response, linear_predictors, linear_strata = NULL, linear_facet = NULL, linear_model_strata = NULL, linear_reference_map = NULL, total_cols_settings = list()) {
  shiny::req(linear_response)
  
  # 验证变量
  if (!linear_response %in% names(data)) stop(paste("响应变量", linear_response, "不存在"))
  missing_preds <- linear_predictors[!linear_predictors %in% names(data)]
  if (length(missing_preds) > 0) stop(paste("预测变量不存在:", paste(missing_preds, collapse = ", ")))
  
  strata_var <- normalize_optional_var(linear_strata)
  facet_var <- normalize_optional_var(linear_facet)
  model_strata_var <- normalize_optional_var(linear_model_strata)
  validate_regression_inputs(
    data = data,
    response = linear_response,
    predictors = linear_predictors,
    split_var = strata_var,
    facet_var = facet_var,
    model_strata_var = model_strata_var,
    analysis_name = "线性回归"
  )
  model_notes <- character(0)
  add_note <- function(msg) {
    txt <- trimws(as.character(msg))
    if (nzchar(txt) && !(txt %in% model_notes)) model_notes <<- c(model_notes, txt)
  }

  ref_pack <- prepare_predictor_reference_levels(data, linear_predictors, linear_reference_map)
  data <- ref_pack$data

  var_labels <- sapply(linear_predictors, function(v) {
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

  term_to_display <- function(term) {
    t <- as.character(term)
    if (is.na(t) || !nzchar(t)) return(t)
    t_clean <- gsub("`", "", t)
    ordered <- linear_predictors[order(nchar(linear_predictors), decreasing = TRUE)]
    for (v in ordered) {
      aliases <- unique(c(v, make.names(v)))
      for (al in aliases) {
        if (startsWith(t_clean, al)) {
          suffix <- substring(t_clean, nchar(al) + 1)
          if (isTRUE(pred_is_cat[[v]]) && nzchar(suffix)) {
            return(suffix)
          }
          return(unname(var_labels[[v]]))
        }
      }
    }
    t
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
    vars <- unique(c(linear_response, linear_predictors))
    vars <- vars[vars %in% names(df_sub)]
    if (length(vars) == 0) return(0L)
    sum(stats::complete.cases(df_sub[, vars, drop = FALSE]))
  }
  predictor_key <- function(term_raw) {
    t_clean <- gsub("`", "", as.character(term_raw))
    ordered <- linear_predictors[order(nchar(linear_predictors), decreasing = TRUE)]
    for (v in ordered) {
      aliases <- unique(c(v, make.names(v)))
      if (any(startsWith(t_clean, aliases))) return(v)
    }
    NA_character_
  }
  fit_tidy_interaction <- function(df_in, pred, strata_nm) {
    ctrl_terms <- if (!is.null(model_strata_var) && !identical(model_strata_var, strata_nm)) model_strata_var else NULL
    base_terms <- setdiff(linear_predictors, pred)
    f1 <- stats::reformulate(c(base_terms, pred, strata_nm, ctrl_terms, paste0(pred, ":", strata_nm)), response = linear_response)
    tryCatch({
      m1 <- stats::lm(f1, data = df_in)
      broom::tidy(m1)
    }, warning = function(w) {
      add_note(paste0("亚组交互检验提示(", pred, "): ", conditionMessage(w)))
      NULL
    }, error = function(e) {
      add_note(paste0("亚组交互检验失败(", pred, "): ", conditionMessage(e)))
      NULL
    })
  }
  model_terms <- unique(c(linear_predictors, model_strata_var))
  formula_str <- paste(linear_response, "~", paste(model_terms, collapse = "+"))
  formula <- as.formula(formula_str)

  # format_p <- function(p) {
  #   format_p_value_regression(p)
  # }
  #
  # format_beta_ci <- function(est, low, high) {
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
        predictors = linear_predictors,
        strata_nm = strata_var,
        strata_levels = strata_vals,
        fit_tidy_fn = fit_tidy_interaction,
        facet_var = facet_var
      )
    } else character(0)

    fit_tidy_fn <- function(sub_data, sval, fval) {
      fit <- tryCatch(lm(formula, data = sub_data), error = function(e) {
        if (is.null(facet_var)) {
          add_note(paste0("亚组[", sval, "]建模失败: ", conditionMessage(e)))
        } else {
          add_note(paste0("亚组[", sval, "]分组[", fval, "]建模失败: ", conditionMessage(e)))
        }
        NULL
      })
      if (is.null(fit)) return(NULL)
      
      extract_broom_tidy_with_fallback(
        fit = fit, 
        conf.int = TRUE, 
        exponentiate = FALSE,
        facet_var = facet_var, 
        sval = sval, 
        fval = fval, 
        add_note_fn = add_note
      )
    }

    cat_refs <- pred_ref_level[!is.na(pred_ref_level)]
    if (length(cat_refs) > 0 && is.null(names(cat_refs))) {
      names(cat_refs) <- names(pred_ref_level)[!is.na(pred_ref_level)]
    }

    build_unified_regression_table(
      df_in = df_in,
      predictors = linear_predictors,
      response_var_name = linear_response,
      strata_var = strata_var,
      facet_var = facet_var,
      strata_vals = strata_vals,
      metric_label = "Beta (95% CI)",
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
      categorical_ref_map = cat_refs,
      total_cols_settings = total_cols_settings
    )
  }

  sanitize_linear_gt <- function(gt_tbl, df_in) {
    if (!inherits(gt_tbl, "gt_tbl")) return(gt_tbl)
    raw <- tryCatch(as.data.frame(gt_tbl[["_data"]], stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(raw) || !is.data.frame(raw) || nrow(raw) == 0) return(gt_tbl)
    n_cols <- regression_extract_n_cols(raw)
    if (length(n_cols) == 0) return(gt_tbl)
    model_vars <- unique(c(linear_response, linear_predictors, model_strata_var, strata_var, facet_var))
    model_vars <- model_vars[!is.na(model_vars) & nzchar(model_vars) & model_vars %in% names(df_in)]
    cc_data <- if (length(model_vars) > 0) {
      df_in[stats::complete.cases(df_in[, model_vars, drop = FALSE]), , drop = FALSE]
    } else {
      df_in
    }
    total_map <- regression_build_total_map(df_in = df_in, facet_var = facet_var, total_cols_settings = total_cols_settings)
    strata_levels <- if (!is.null(strata_var) && strata_var %in% names(df_in)) unique(as.character(stats::na.omit(df_in[[strata_var]]))) else character(0)
    is_header_row <- function(x) {
      txt <- gsub("\u00A0", " ", as.character(x), fixed = TRUE)
      !grepl("^\\s", txt)
    }
    header_map <- character(0)
    for (v in linear_predictors) {
      if (!v %in% names(df_in)) next
      header_map[[regression_norm_text(v)]] <- v
      v_label <- attr(df_in[[v]], "label", exact = TRUE)
      if (!is.null(v_label) && nzchar(trimws(as.character(v_label)[1]))) {
        header_map[[regression_norm_text(v_label)]] <- v
      }
    }
    current_strata <- NA_character_
    current_var <- NA_character_
    for (i in seq_len(nrow(raw))) {
      current_strata <- regression_update_current_strata(raw_df = raw, row_index = i, current_strata = current_strata, strata_levels = strata_levels)
      lbl <- as.character(raw$预测变量[i])
      lbl_norm <- regression_norm_text(lbl)
      if (is_header_row(lbl) && lbl_norm %in% names(header_map)) {
        current_var <- unname(header_map[[lbl_norm]])
      }
      for (cn in n_cols) {
        d <- suppressWarnings(as.numeric(as.character(raw[[cn]][i])))
        if (is.na(d)) next
        slice <- regression_slice_for_n_context(
          cc_data = cc_data,
          raw_df = raw,
          row_index = i,
          n_col = cn,
          strata_var = strata_var,
          current_strata = current_strata,
          facet_var = facet_var,
          total_map = total_map
        )
        events <- as.integer(d)
        if (linear_response %in% names(slice)) {
          if (!is.na(current_var) && nzchar(current_var) && current_var %in% names(slice)) {
            if (is_header_row(lbl)) {
              events <- sum(!is.na(slice[[linear_response]]) & !is.na(slice[[current_var]]), na.rm = TRUE)
            } else {
              level_clean <- regression_norm_text(gsub("\\s*\\(Reference\\)$", "", lbl, perl = TRUE))
              level_vec <- regression_norm_text(slice[[current_var]])
              events <- sum(!is.na(slice[[linear_response]]) & level_vec == level_clean, na.rm = TRUE)
            }
          } else {
            events <- sum(!is.na(slice[[linear_response]]), na.rm = TRUE)
          }
        }
        raw[[cn]][i] <- paste0(as.integer(events), "/", as.integer(d))
      }
    }
    gt_tbl[["_data"]] <- raw
    lbls <- stats::setNames(as.list(rep("event/N", length(n_cols))), n_cols)
    do.call(gt::cols_label, c(list(.data = gt_tbl), lbls))
  }

  gt_table <- sanitize_linear_gt(build_strata_first_gt(data, strata_var, facet_var), data)

  interpretation <- "<h4><b>结果解读 (Result Interpretation):</b></h4><ul>"
  if (!is.null(strata_var)) interpretation <- paste0(interpretation, "<li><b>亚组(Subgroup):</b> ", strata_var, "（按变量分组独立拟合）</li>")
  if (!is.null(strata_var) && length(split_levels) > 0) interpretation <- paste0(interpretation, "<li><b>交互作用 P 值 (P for interaction):</b> 基于“预测变量×亚组”交互项检验得到。</li>")
  if (!is.null(facet_var)) interpretation <- paste0(interpretation, "<li><b>队列分组(Cohort/Arm):</b> ", facet_var, "</li>")
  if (!is.null(model_strata_var)) interpretation <- paste0(interpretation, "<li><b>模型分层因素 (Stratification Factor):</b> 模型中纳入", model_strata_var, "作为控制项。</li>")
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
    code = generate_linear_code("data", linear_response, linear_predictors, strata_var, facet_var, model_strata_var)
  ))
}

generate_linear_code <- function(data_name = "data", linear_response, linear_predictors, linear_strata = NULL, linear_facet = NULL, linear_model_strata = NULL) {
  preds_txt <- if (length(linear_predictors) > 0) paste0("c(", paste(sprintf("\"%s\"", linear_predictors), collapse = ", "), ")") else "character(0)"
  strata_txt <- if (is.null(linear_strata)) "NULL" else paste0("\"", linear_strata, "\"")
  facet_txt <- if (is.null(linear_facet)) "NULL" else paste0("\"", linear_facet, "\"")
  model_strata_txt <- if (is.null(linear_model_strata)) "NULL" else paste0("\"", linear_model_strata, "\"")
  build_repro_code_template(list(
    list(
      title = "Load packages",
      lines = c("library(stats)", "library(broom)", "library(gtsummary)", "library(gt)")
    ),
    list(
      title = "Set analysis parameters",
      lines = c(
        paste0("data <- ", data_name),
        paste0("response <- \"", linear_response, "\""),
        paste0("predictors <- ", preds_txt),
        paste0("split_var <- ", strata_txt),
        paste0("facet_var <- ", facet_txt),
        paste0("model_strata_var <- ", model_strata_txt)
      )
    ),
    list(
      title = "Run analysis in RStudio",
      lines = c(
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
        "    fit <- stats::lm(fml, data = df_sub)",
        "    td <- broom::tidy(fit, conf.int = TRUE)",
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
