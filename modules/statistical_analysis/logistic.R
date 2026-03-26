# 逻辑回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

if (file.exists("modules/common/analysis_shared.R")) {
  source("modules/common/analysis_shared.R")
} else {
  source(file.path("..", "modules", "common", "analysis_shared.R"))
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
             selectInput(ns("logistic_strata"), "亚组变量 (Subgroup) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_strata"), "按该变量分组后，分别拟合并以堆叠方式展示结果", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("logistic_facet"), "队列/分组变量 (Cohort/Arm) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_facet"), "按该变量分组后，以列分组方式并排展示回归结果", placement = "top", trigger = "hover")
      )
    ),
    fluidRow(
      column(12,
             selectInput(ns("logistic_model_strata"), "模型分层因素 (Stratification Factor) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_model_strata"), "该变量作为模型控制项进入回归，用于控制基线混杂", placement = "top", trigger = "hover")
      )
    ),
    
    uiOutput(ns("logistic_total_cols_ui")),
    uiOutput(ns("logistic_event_mapping_ui")),
    
    selectizeInput(ns("logistic_predictors"), "预测变量 (Predictors)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("logistic_predictors"), "纳入模型的自变量 (解释变量)", placement = "top", trigger = "hover"),
    uiOutput(ns("logistic_reference_ui"))
  )
}

# 逻辑回归分析
perform_logistic_analysis <- function(data, logistic_response, logistic_predictors, logistic_strata = NULL, logistic_facet = NULL, logistic_event_value = NULL, logistic_model_strata = NULL, logistic_reference_map = NULL, total_cols_settings = list()) {
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

  ref_pack <- prepare_predictor_reference_levels(data, logistic_predictors, logistic_reference_map)
  data <- ref_pack$data

  var_labels <- sapply(logistic_predictors, function(v) {
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
    t_clean <- gsub("`", "", t)
    ordered <- logistic_predictors[order(nchar(logistic_predictors), decreasing = TRUE)]
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
    t_clean <- gsub("`", "", as.character(term_raw))
    ordered <- logistic_predictors[order(nchar(logistic_predictors), decreasing = TRUE)]
    for (v in ordered) {
      aliases <- unique(c(v, make.names(v)))
      if (any(startsWith(t_clean, aliases))) return(v)
    }
    level_hits <- character(0)
    for (v in ordered) {
      if (!v %in% names(data)) next
      is_cat <- is.factor(data[[v]]) || is.character(data[[v]]) || is.logical(data[[v]])
      if (!is_cat) next
      lv <- get_levels_all(data[[v]])
      lv <- lv[nzchar(as.character(lv))]
      if (length(lv) == 0) next
      if (t_clean %in% as.character(lv)) level_hits <- c(level_hits, v)
    }
    level_hits <- unique(level_hits)
    if (length(level_hits) == 1) return(level_hits[1])
    NA_character_
  }

  quote_formula_name <- function(x) {
    paste0("`", gsub("`", "\\\\`", as.character(x), fixed = TRUE), "`")
  }

  build_formula_safe <- function(response, terms, interaction_pairs = NULL) {
    main_terms <- as.character(terms)
    main_terms <- main_terms[!is.na(main_terms) & nzchar(main_terms)]
    quoted_terms <- if (length(main_terms) > 0) vapply(main_terms, quote_formula_name, character(1)) else character(0)
    interaction_terms <- character(0)
    if (!is.null(interaction_pairs) && length(interaction_pairs) > 0) {
      interaction_terms <- vapply(interaction_pairs, function(pair) {
        paste0(quote_formula_name(pair[1]), ":", quote_formula_name(pair[2]))
      }, character(1))
    }
    rhs_terms <- unique(c(quoted_terms, interaction_terms))
    if (length(rhs_terms) == 0) rhs_terms <- "1"
    stats::as.formula(paste0(quote_formula_name(response), " ~ ", paste(rhs_terms, collapse = " + ")))
  }

  fit_tidy_interaction <- function(df_in, pred, strata_nm) {
    ctrl_terms <- if (!is.null(model_strata_var) && !identical(model_strata_var, strata_nm)) model_strata_var else NULL
    base_terms <- setdiff(logistic_predictors, pred)
    f1 <- build_formula_safe(
      response = logistic_response,
      terms = c(base_terms, pred, strata_nm, ctrl_terms),
      interaction_pairs = list(c(pred, strata_nm))
    )
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
  analysis_formula <- build_formula_safe(logistic_response, model_terms)

  # format_p <- function(p) {
  #   format_p_value_regression(p)
  # }
  #
  # format_or_ci <- function(est, low, high) {
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

    fit_tidy_fn <- function(sub_data, sval, fval) {
      pick_tid_col <- function(df, candidates) {
        nm_vec <- names(df)
        norm_name <- function(x) tolower(gsub("[^a-z0-9]", "", as.character(x)))
        nm_norm <- norm_name(nm_vec)
        cand_norm <- norm_name(candidates)
        for (nm in candidates) {
          if (nm %in% nm_vec) return(df[[nm]])
        }
        idx <- which(nm_norm %in% cand_norm)
        if (length(idx) > 0) return(df[[nm_vec[idx[1]]]])
        NULL
      }
      fit <- tryCatch(glm(analysis_formula, data = sub_data, family = binomial()), error = function(e) {
        if (is.null(facet_var)) {
          add_note(paste0("亚组[", sval, "]建模失败: ", conditionMessage(e)))
        } else {
          add_note(paste0("亚组[", sval, "]分组[", fval, "]建模失败: ", conditionMessage(e)))
        }
        NULL
      })
      if (is.null(fit)) return(NULL)
      tid <- tryCatch(
        broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE),
        error = function(e) NULL
      )
      if (is.null(tid) || !is.data.frame(tid) || nrow(tid) == 0) {
        tid <- extract_broom_tidy_with_fallback(
          fit = fit,
          conf.int = TRUE,
          exponentiate = TRUE,
          facet_var = facet_var,
          sval = sval,
          fval = fval,
          add_note_fn = add_note
        )
      }
      if (is.null(tid) || !is.data.frame(tid) || nrow(tid) == 0) return(NULL)
      if (!"term" %in% names(tid)) return(NULL)
      est_col <- pick_tid_col(tid, c("odds_ratio", "oddsratio", "or", "hr", "beta"))
      if (!is.null(est_col)) {
        tid$estimate <- suppressWarnings(as.numeric(est_col))
      } else if (!"estimate" %in% names(tid)) {
        tid$estimate <- NA_real_
      }
      low_col <- pick_tid_col(tid, c("lcl", "lower", "ci_low", "lower_ci"))
      if (!is.null(low_col)) {
        tid$conf.low <- suppressWarnings(as.numeric(low_col))
      } else if (!"conf.low" %in% names(tid)) {
        tid$conf.low <- NA_real_
      }
      high_col <- pick_tid_col(tid, c("ucl", "upper", "ci_high", "upper_ci"))
      if (!is.null(high_col)) {
        tid$conf.high <- suppressWarnings(as.numeric(high_col))
      } else if (!"conf.high" %in% names(tid)) {
        tid$conf.high <- NA_real_
      }
      if (!"p.value" %in% names(tid)) {
        p_col <- pick_tid_col(tid, c("p", "p_value", "pvalue", "Pr(>|z|)", "Pr(>|t|)"))
        if (!is.null(p_col)) tid$p.value <- suppressWarnings(as.numeric(p_col))
      }
      if (!"p.value" %in% names(tid)) tid$p.value <- NA_real_
      tid <- tid[, c("term", "estimate", "conf.low", "conf.high", "p.value"), drop = FALSE]
      tid
    }

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
    cat_refs <- character(0)
    for (v in logistic_predictors) {
      if (!v %in% names(df_in)) next
      is_cat <- is.factor(df_in[[v]]) || is.character(df_in[[v]]) || is.logical(df_in[[v]])
      if (!is_cat) next
      lv <- get_levels_all(df_in[[v]])
      lv <- lv[nzchar(as.character(lv))]
      if (length(lv) == 0) next
      ref_v <- pred_ref_level[[v]]
      if (is.null(ref_v) || is.na(ref_v) || !as.character(ref_v) %in% as.character(lv)) {
        ref_v <- as.character(lv[1])
      }
      cat_refs[[v]] <- as.character(ref_v)
    }

    build_unified_regression_table(
      df_in = df_in,
      predictors = logistic_predictors,
      response_var_name = logistic_response,
      strata_var = strata_var,
      facet_var = facet_var,
      strata_vals = strata_vals,
      metric_label = "OR (95% CI)",
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

  sanitize_logistic_gt <- function(gt_tbl, df_in) {
    if (!inherits(gt_tbl, "gt_tbl")) return(gt_tbl)
    raw <- tryCatch(as.data.frame(gt_tbl[["_data"]], stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(raw) || !is.data.frame(raw) || nrow(raw) == 0) return(gt_tbl)
    if (!all(c("预测变量", "统计值", "P值") %in% names(raw))) return(gt_tbl)
    norm_text <- function(x) {
      z <- gsub("\u00A0", " ", as.character(x), fixed = TRUE)
      z <- trimws(z)
      tolower(z)
    }
    is_header_row <- function(x) {
      txt <- gsub("\u00A0", " ", as.character(x), fixed = TRUE)
      !grepl("^\\s", txt)
    }
    model_vars <- unique(c(logistic_predictors, model_strata_var, logistic_response))
    model_vars <- model_vars[model_vars %in% names(df_in)]
    cc_data <- if (length(model_vars) > 0) {
      df_in[stats::complete.cases(df_in[, model_vars, drop = FALSE]), , drop = FALSE]
    } else {
      df_in
    }
    header_map <- character(0)
    for (v in logistic_predictors) {
      if (!v %in% names(df_in)) next
      header_map[[norm_text(v)]] <- v
      v_label <- attr(df_in[[v]], "label", exact = TRUE)
      if (!is.null(v_label) && nzchar(trimws(as.character(v_label)[1]))) {
        header_map[[norm_text(v_label)]] <- v
      }
    }
    keep <- rep(TRUE, nrow(raw))
    n_out <- if ("N" %in% names(raw)) as.character(raw$N) else rep("", nrow(raw))
    current_var <- NA_character_
    current_ref <- NA_character_
    seen_levels <- character(0)
    for (i in seq_len(nrow(raw))) {
      lbl <- as.character(raw$预测变量[i])
      lbl_norm <- norm_text(lbl)
      stat_norm <- norm_text(raw$统计值[i])
      if (is_header_row(lbl) && lbl_norm %in% names(header_map)) {
        current_var <- unname(header_map[[lbl_norm]])
        current_ref <- NA_character_
        seen_levels <- character(0)
        if ("N" %in% names(raw) && current_var %in% names(cc_data)) {
          denom <- suppressWarnings(as.numeric(raw$N[i]))
          if (is.na(denom)) denom <- sum(!is.na(cc_data[[current_var]]))
          events <- sum(cc_data[[logistic_response]] == 1 & !is.na(cc_data[[current_var]]), na.rm = TRUE)
          n_out[i] <- paste0(events, "/", as.integer(denom))
        }
        next
      }
      if (is.na(current_var) || !nzchar(current_var)) next
      level_clean <- gsub("\\s*\\(Reference\\)$", "", lbl, perl = TRUE)
      level_clean <- norm_text(level_clean)
      if (!nzchar(level_clean)) next
      is_ref <- grepl("\\(reference\\)", lbl_norm, perl = TRUE) || identical(stat_norm, "reference")
      if (is_ref) {
        current_ref <- level_clean
      } else if (!is.na(current_ref) && nzchar(current_ref) && identical(level_clean, current_ref)) {
        keep[i] <- FALSE
      } else if (level_clean %in% seen_levels) {
        keep[i] <- FALSE
      }
      seen_levels <- c(seen_levels, level_clean)
      if ("N" %in% names(raw) && current_var %in% names(cc_data)) {
        denom <- suppressWarnings(as.numeric(raw$N[i]))
        level_vec <- norm_text(cc_data[[current_var]])
        if (is.na(denom)) denom <- sum(level_vec == level_clean, na.rm = TRUE)
        events <- sum(cc_data[[logistic_response]] == 1 & level_vec == level_clean, na.rm = TRUE)
        n_out[i] <- paste0(events, "/", as.integer(denom))
      }
    }
    if ("N" %in% names(raw)) {
      raw$N <- n_out
      names(raw)[names(raw) == "N"] <- "event/N"
    }
    sanitized <- raw[keep, , drop = FALSE]
    new_tbl <- gt::gt(sanitized)
    attr(new_tbl, "skipped_models") <- attr(gt_tbl, "skipped_models", exact = TRUE)
    new_tbl
  }

  gt_table <- sanitize_logistic_gt(build_strata_first_gt(data, strata_var, facet_var), data)

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
        "qname <- function(x) paste0(\"`\", gsub(\"`\", \"\\\\\\\\`\", as.character(x), fixed = TRUE), \"`\")",
        "build_formula_safe <- function(response, terms) {",
        "  terms <- as.character(terms)",
        "  terms <- terms[!is.na(terms) & nzchar(terms)]",
        "  rhs <- if (length(terms) > 0) paste(vapply(terms, qname, character(1)), collapse = \" + \") else \"1\"",
        "  stats::as.formula(paste0(qname(response), \" ~ \", rhs))",
        "}",
        "res_list <- list()",
        "for (s in split_levels) {",
        "  ds <- if (is.null(split_var)) data else data[as.character(data[[split_var]]) == as.character(s), , drop = FALSE]",
        "  for (f in facet_levels) {",
        "    df_sub <- if (is.null(facet_var)) ds else ds[as.character(ds[[facet_var]]) == as.character(f), , drop = FALSE]",
        "    if (nrow(df_sub) == 0) next",
        "    model_terms <- unique(c(predictors, model_strata_var))",
        "    fml <- build_formula_safe(response, model_terms)",
        "    fit <- stats::glm(fml, data = df_sub, family = stats::binomial())",
        "    td <- broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE)",
        "    if (!\"estimate\" %in% names(td) && \"odds_ratio\" %in% names(td)) td$estimate <- as.numeric(td$odds_ratio)",
        "    if (!\"conf.low\" %in% names(td) && \"lcl\" %in% names(td)) td$conf.low <- as.numeric(td$lcl)",
        "    if (!\"conf.high\" %in% names(td) && \"ucl\" %in% names(td)) td$conf.high <- as.numeric(td$ucl)",
        "    if (!\"p.value\" %in% names(td) && \"p\" %in% names(td)) td$p.value <- as.numeric(td$p)",
        "    td <- td[, intersect(c(\"term\", \"estimate\", \"conf.low\", \"conf.high\", \"p.value\"), names(td)), drop = FALSE]",
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
