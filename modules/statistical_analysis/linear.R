# 线性回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

# 线性回归参数UI
linear_params_ui <- function(ns, data) {
  numeric_vars <- names(data)[sapply(data, is.numeric)]
  factor_vars <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x))]
  
  tagList(
    fluidRow(
      column(6, 
             selectInput(ns("linear_response"), "响应变量 (Response)", choices = numeric_vars),
             bsTooltip(ns("linear_response"), "连续型因变量 (数值型)", placement = "top", trigger = "hover")
      )
    ),
    fluidRow(
      column(6,
             selectInput(ns("linear_strata"), "亚组变量 (Split, 行分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("linear_strata"), "按该变量分组后，分别拟合并以行分组方式展示结果（split）", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("linear_facet"), "分组变量 (Facet, 列分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("linear_facet"), "按该变量分组后，以列分组方式并排展示回归结果", placement = "top", trigger = "hover")
      )
    ),
    fluidRow(
      column(12,
             selectInput(ns("linear_model_strata"), "分层变量 (控制项) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("linear_model_strata"), "该变量作为模型控制项进入回归，用于分层变量控制", placement = "top", trigger = "hover")
      )
    ),
    
    selectizeInput(ns("linear_predictors"), "预测变量 (Predictors)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("linear_predictors"), "自变量 (可多选)", placement = "top", trigger = "hover")
  )
}

# 线性回归分析
perform_linear_analysis <- function(data, linear_response, linear_predictors, linear_strata = NULL, linear_facet = NULL, linear_model_strata = NULL) {
  req(linear_response, linear_predictors)
  
  # 验证变量
  if (!linear_response %in% names(data)) stop(paste("响应变量", linear_response, "不存在"))
  missing_preds <- linear_predictors[!linear_predictors %in% names(data)]
  if (length(missing_preds) > 0) stop(paste("预测变量不存在:", paste(missing_preds, collapse = ", ")))
  
  strata_var <- if (!is.null(linear_strata) && linear_strata != "None") linear_strata else NULL
  facet_var <- if (!is.null(linear_facet) && linear_facet != "None") linear_facet else NULL
  model_strata_var <- if (!is.null(linear_model_strata) && linear_model_strata != "None") linear_model_strata else NULL
  model_notes <- character(0)
  add_note <- function(msg) {
    txt <- trimws(as.character(msg))
    if (nzchar(txt) && !(txt %in% model_notes)) model_notes <<- c(model_notes, txt)
  }

  var_labels <- sapply(linear_predictors, function(v) {
    lv <- attr(data[[v]], "label", exact = TRUE)
    if (is.null(lv) || !nzchar(trimws(as.character(lv)[1]))) v else trimws(as.character(lv)[1])
  }, USE.NAMES = TRUE)
  for (v in names(var_labels)) {
    attr(data[[v]], "label") <- unname(var_labels[[v]])
  }

  term_to_display <- function(term) {
    t <- as.character(term)
    ordered <- linear_predictors[order(nchar(linear_predictors), decreasing = TRUE)]
    hit <- ordered[startsWith(t, ordered)]
    if (length(hit) == 0) return(t)
    v <- hit[1]
    suffix <- substring(t, nchar(v) + 1)
    paste0(unname(var_labels[[v]]), suffix)
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
    ordered <- linear_predictors[order(nchar(linear_predictors), decreasing = TRUE)]
    hit <- ordered[startsWith(as.character(term_raw), ordered)]
    if (length(hit) == 0) return(NA_character_)
    hit[1]
  }
  interaction_p_map <- function(df_in, strata_nm, strata_levels) {
    if (is.null(strata_nm) || length(strata_levels) <= 1) return(setNames(character(0), character(0)))
    out <- character(0)
    ref_level <- strata_levels[1]
    ctrl_terms <- if (!is.null(model_strata_var) && !identical(model_strata_var, strata_nm)) model_strata_var else NULL
    for (pred in linear_predictors) {
      base_terms <- setdiff(linear_predictors, pred)
      f1 <- stats::reformulate(c(base_terms, pred, strata_nm, ctrl_terms, paste0(pred, ":", strata_nm)), response = linear_response)
      tid <- tryCatch({
        m1 <- stats::lm(f1, data = df_in)
        broom::tidy(m1)
      }, warning = function(w) {
        add_note(paste0("亚组交互检验提示(", pred, "): ", conditionMessage(w))); NULL
      }, error = function(e) {
        add_note(paste0("亚组交互检验失败(", pred, "): ", conditionMessage(e))); NULL
      })
      for (lv in strata_levels[strata_levels != ref_level]) {
        p_fmt <- "NA"
        if (!is.null(tid) && nrow(tid) > 0 && "p.value" %in% names(tid)) {
          idx <- which(grepl(":", tid$term, fixed = TRUE) & grepl(pred, tid$term, fixed = TRUE) & grepl(strata_nm, tid$term, fixed = TRUE) & grepl(lv, tid$term, fixed = TRUE))
          if (length(idx) > 0) p_fmt <- format_p(tid$p.value[idx[1]])
        }
        out[[paste0(pred, "||", lv)]] <- p_fmt
      }
    }
    out
  }
  get_int_p <- function(int_map, pred_key, sval, facet_tag = "__ALL__") {
    key <- paste0(pred_key, "||", as.character(sval), "||", facet_tag)
    if (key %in% names(int_map)) unname(int_map[[key]]) else "NA"
  }
  if (!is.null(strata_var) && !strata_var %in% names(data)) stop(paste("亚组变量", strata_var, "不存在"))
  if (!is.null(facet_var) && !facet_var %in% names(data)) stop(paste("分组变量", facet_var, "不存在"))
  if (!is.null(model_strata_var) && !model_strata_var %in% names(data)) stop(paste("分层变量", model_strata_var, "不存在"))
  if (!is.null(strata_var) && !is.null(facet_var) && identical(strata_var, facet_var)) {
    stop("分层变量与分组变量不能相同")
  }

  model_terms <- unique(c(linear_predictors, model_strata_var))
  formula_str <- paste(linear_response, "~", paste(model_terms, collapse = "+"))
  formula <- as.formula(formula_str)

  build_tbl <- function(df_sub) {
    model <- lm(formula, data = df_sub)
    gtsummary::tbl_regression(model) %>%
      gtsummary::add_n() %>%
      gtsummary::add_global_p() %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "预测变量", p.value = "P值")
  }

  format_p <- function(p) {
    if (is.na(p)) return("NA")
    if (p < 0.0001) return("<0.0001")
    sub("\\.?0+$", "", sprintf("%.4f", p))
  }

  format_beta_ci <- function(est, low, high) {
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
    left_cols <- intersect(c("预测变量", "label", "分层"), col_names)
    if (length(left_cols) == 0) {
      left_cols <- 1
    }
    styled <- apply_sci_gt_style(
      gt_tbl,
      title = NULL,
      footnotes = NULL,
      left_columns = left_cols
    )
    if ("分层" %in% col_names) {
      styled <- styled %>%
        gt::cols_align(align = "left", columns = c("分层")) %>%
        gt::tab_style(
          style = gt::cell_text(indent = gt::px(4)),
          locations = gt::cells_body(columns = "分层")
        )
    }
    styled
  }

  build_strata_first_gt <- function(df_in, strata_var = NULL, facet_var = NULL) {
    if (is.null(strata_var)) {
      strata_vals <- "总体"
    } else {
      strata_vals <- normalize_subgroup_levels(get_levels_all(df_in[[strata_var]]))
    }
    out_list <- list()
    skipped_models <- 0
    int_p <- if (!is.null(strata_var)) {
      if (is.null(facet_var)) {
        m <- interaction_p_map(df_in, strata_var, strata_vals)
        if (length(m) > 0) names(m) <- vapply(names(m), function(nm) {
          parts <- strsplit(nm, "||", fixed = TRUE)[[1]]
          paste0(parts[1], "||", parts[2], "||__ALL__")
        }, character(1))
        m
      } else {
        facet_levels_for_p <- get_levels_all(df_in[[facet_var]])
        mm <- lapply(facet_levels_for_p, function(fv) {
          sub <- df_in[df_in[[facet_var]] == fv, , drop = FALSE]
          m <- interaction_p_map(sub, strata_var, strata_vals)
          if (length(m) == 0) return(character(0))
          names(m) <- vapply(names(m), function(nm) {
            parts <- strsplit(nm, "||", fixed = TRUE)[[1]]
            paste0(parts[1], "||", parts[2], "||", as.character(fv))
          }, character(1))
          m
        })
        unlist(mm, use.names = TRUE)
      }
    } else character(0)
    facet_levels_all <- if (!is.null(facet_var)) get_levels_all(df_in[[facet_var]]) else character(0)

    for (sval in strata_vals) {
      strata_data <- if (is.null(strata_var)) df_in else df_in[df_in[[strata_var]] == sval, , drop = FALSE]
      if (nrow(strata_data) == 0) {
        add_note(paste0("分层[", sval, "]无可用样本，已以占位形式展示。"))
        next
      }
      if (is.null(facet_var)) {
        fit <- tryCatch(lm(formula, data = strata_data), error = function(e) NULL)
        if (is.null(fit)) {
          skipped_models <- skipped_models + 1
          next
        }
        tid <- tryCatch(broom::tidy(fit, conf.int = TRUE), error = function(e) NULL)
        if (is.null(tid)) {
          skipped_models <- skipped_models + 1
          next
        }
        tid <- tid[tid$term != "(Intercept)", , drop = FALSE]
        if (nrow(tid) == 0) next
        est <- if ("estimate" %in% names(tid)) tid$estimate else rep(NA_real_, nrow(tid))
        low <- if ("conf.low" %in% names(tid)) tid$conf.low else rep(NA_real_, nrow(tid))
        high <- if ("conf.high" %in% names(tid)) tid$conf.high else rep(NA_real_, nrow(tid))
        pvals <- if ("p.value" %in% names(tid)) tid$p.value else rep(NA_real_, nrow(tid))
        tid$预测变量 <- vapply(tid$term, term_to_display, character(1))
        tid$预测变量原始 <- vapply(tid$term, predictor_key, character(1))
        tid$分层 <- if (is.null(strata_var)) "总体" else as.character(sval)
        tid$N <- as.character(count_effective_n(strata_data))
        tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_beta_ci(est[i], low[i], high[i]), character(1))
        tid$P值 <- vapply(pvals, format_p, character(1))
        tid$分层差异P值 <- if (!is.null(strata_var) && as.character(sval) != strata_vals[1]) vapply(tid$预测变量原始, function(pk) get_int_p(int_p, pk, as.character(sval), "__ALL__"), character(1)) else ""
        out_list[[length(out_list) + 1]] <- tid[, c("预测变量", "预测变量原始", "分层", "N", "统计值", "P值", "分层差异P值"), drop = FALSE]
      } else {
        facet_vals <- facet_levels_all
        for (fval in facet_vals) {
          sub_data <- strata_data[strata_data[[facet_var]] == fval, , drop = FALSE]
          if (nrow(sub_data) == 0) next
          fit <- tryCatch(lm(formula, data = sub_data), error = function(e) NULL)
          if (is.null(fit)) {
            skipped_models <- skipped_models + 1
            next
          }
          tid <- tryCatch(broom::tidy(fit, conf.int = TRUE), error = function(e) NULL)
          if (is.null(tid)) {
            skipped_models <- skipped_models + 1
            next
          }
          tid <- tid[tid$term != "(Intercept)", , drop = FALSE]
          if (nrow(tid) == 0) next
          est <- if ("estimate" %in% names(tid)) tid$estimate else rep(NA_real_, nrow(tid))
          low <- if ("conf.low" %in% names(tid)) tid$conf.low else rep(NA_real_, nrow(tid))
          high <- if ("conf.high" %in% names(tid)) tid$conf.high else rep(NA_real_, nrow(tid))
          pvals <- if ("p.value" %in% names(tid)) tid$p.value else rep(NA_real_, nrow(tid))
          tid$预测变量 <- vapply(tid$term, term_to_display, character(1))
          tid$预测变量原始 <- vapply(tid$term, predictor_key, character(1))
          tid$分层 <- if (is.null(strata_var)) "总体" else as.character(sval)
          tid$列分组 <- as.character(fval)
          tid$N <- as.character(count_effective_n(sub_data))
          tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_beta_ci(est[i], low[i], high[i]), character(1))
          tid$P值 <- vapply(pvals, format_p, character(1))
          tid$分层差异P值 <- if (!is.null(strata_var) && as.character(sval) != strata_vals[1]) vapply(tid$预测变量原始, function(pk) get_int_p(int_p, pk, as.character(sval), as.character(fval)), character(1)) else ""
          out_list[[length(out_list) + 1]] <- tid[, c("预测变量", "预测变量原始", "分层", "列分组", "N", "统计值", "P值", "分层差异P值"), drop = FALSE]
        }
      }
    }

    if (length(out_list) == 0) {
      stop("无法为任何分层生成模型结果，请检查各层样本量。")
    }

    final_df <- dplyr::bind_rows(out_list)
    if (nrow(final_df) == 0) {
      dummy_preds <- unname(var_labels)
      if (length(dummy_preds) == 0) dummy_preds <- linear_predictors
      final_df <- data.frame(
        预测变量 = dummy_preds,
        预测变量原始 = linear_predictors,
        分层 = if (is.null(strata_var)) "总体" else strata_vals[1],
        N = "0",
        统计值 = "NA",
        P值 = "NA",
        分层差异P值 = "",
        stringsAsFactors = FALSE
      )
    }
    if (!is.null(strata_var)) {
      all_preds <- unique(final_df$预测变量)
      complete_grid <- expand.grid(预测变量 = all_preds, 分层 = strata_vals, stringsAsFactors = FALSE)
      final_df <- dplyr::left_join(complete_grid, final_df, by = c("预测变量", "分层")) %>%
        dplyr::mutate(
          预测变量原始 = ifelse(is.na(预测变量原始), "", 预测变量原始),
          N = ifelse(is.na(N), "0", N),
          统计值 = ifelse(is.na(统计值), "NA", 统计值),
          P值 = ifelse(is.na(P值), "NA", P值),
          分层差异P值 = ifelse(
            as.character(分层) == strata_vals[1] | !nzchar(预测变量原始),
            "",
            vapply(seq_along(预测变量原始), function(i) get_int_p(int_p, 预测变量原始[i], as.character(分层[i]), "__ALL__"), character(1))
          )
        )
    }
    if ("列分组" %in% names(final_df)) {
      facet_n_map <- sapply(facet_levels_all, function(x) {
        sum(as.character(df_in[[facet_var]]) == x, na.rm = TRUE)
      }, USE.NAMES = TRUE)
      vals_from <- if (!is.null(strata_var)) c("N", "统计值", "P值", "分层差异P值") else c("N", "统计值", "P值")
      final_df <- final_df %>%
        tidyr::pivot_wider(names_from = 列分组, values_from = dplyr::all_of(vals_from), names_glue = "{列分组}__{.value}", values_fill = "NA")
      expected_cols <- if (!is.null(strata_var)) as.vector(rbind(paste0(facet_levels_all, "__N"), paste0(facet_levels_all, "__统计值"), paste0(facet_levels_all, "__P值"), paste0(facet_levels_all, "__分层差异P值"))) else as.vector(rbind(paste0(facet_levels_all, "__N"), paste0(facet_levels_all, "__统计值"), paste0(facet_levels_all, "__P值")))
      missing_cols <- setdiff(expected_cols, names(final_df))
      if (length(missing_cols) == length(expected_cols)) {
        stop("列分组结果展开失败：未生成任何预期列，请检查分组变量取值与模型输出。")
      }
      if (length(missing_cols) > 0) {
        for (mc in missing_cols) final_df[[mc]] <- if (grepl("__N$", mc)) "0" else "NA"
      }
      final_df <- final_df %>% dplyr::select(预测变量, 分层, dplyr::all_of(expected_cols))
      label_map <- list(分层 = "")
      spanner_map <- list()
      for (lv in facet_levels_all) {
        n_col <- paste0(lv, "__N")
        stat_col <- paste0(lv, "__统计值")
        p_col <- paste0(lv, "__P值")
        pd_col <- paste0(lv, "__分层差异P值")
        label_map[[n_col]] <- "N"
        label_map[[stat_col]] <- "Beta (95% CI)"
        label_map[[p_col]] <- "P值"
        if (!is.null(strata_var)) label_map[[pd_col]] <- "亚组差异P值"
        lv_text <- if (grepl("组$", lv)) lv else paste0(lv, "组")
        spanner_map[[lv]] <- list(
          label = gt::md(paste0(lv_text, "<br><span style='font-weight:normal'>(N = ", facet_n_map[[lv]], ")</span>")),
          columns = if (!is.null(strata_var)) c(n_col, stat_col, p_col, pd_col) else c(n_col, stat_col, p_col)
        )
      }
    } else {
      if (!is.null(strata_var)) {
        final_df <- final_df %>% dplyr::select(预测变量, 分层, N, 统计值, P值, 分层差异P值)
        label_map <- list(分层 = "", N = "N", 统计值 = "Beta (95% CI)", P值 = "P值", 分层差异P值 = "亚组差异P值")
      } else {
        final_df <- final_df %>% dplyr::select(预测变量, 分层, N, 统计值, P值)
        label_map <- list(分层 = "", N = "N", 统计值 = "Beta (95% CI)", P值 = "P值")
      }
      spanner_map <- list()
    }
    if (!is.null(strata_var)) final_df$分层 <- factor(as.character(final_df$分层), levels = strata_vals)
    final_df <- final_df %>%
      dplyr::arrange(预测变量, 分层) %>%
      dplyr::group_by(预测变量, 分层) %>%
      dplyr::mutate(分层 = ifelse(dplyr::row_number() == 1, paste0("\u00A0\u00A0\u00A0\u00A0", 分层), "")) %>%
      dplyr::ungroup()
    gt_tbl <- do.call(gt::cols_label, c(list(.data = gt::gt(final_df, groupname_col = "预测变量")), label_map))
    if (length(spanner_map) > 0) {
      for (sp in spanner_map) {
        gt_tbl <- gt_tbl %>% gt::tab_spanner(label = sp$label, columns = sp$columns)
      }
    }
    gt_tbl <- apply_clinical_style(gt_tbl)
    attr(gt_tbl, "skipped_models") <- skipped_models
    gt_tbl
  }

  if (is.null(strata_var) && is.null(facet_var)) {
    model <- lm(formula, data = data)
    tbl <- gtsummary::tbl_regression(model) %>%
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
  if (!is.null(model_strata_var)) interpretation <- paste0(interpretation, "<li><b>分层变量控制:</b> 模型中纳入", model_strata_var, "作为控制项。</li>")
  if (is.null(strata_var) && is.null(facet_var)) interpretation <- paste0(interpretation, "<li>未设置分层/分组，展示总体模型结果。</li>")
  skipped_n <- if (exists("gt_table")) attr(gt_table, "skipped_models", exact = TRUE) else NULL
  if (!is.null(skipped_n) && is.numeric(skipped_n) && skipped_n > 0) {
    interpretation <- paste0(interpretation, "<li><b>稳定性提示:</b> 有 ", skipped_n, " 个子模型因样本不足或无法估计被自动跳过，表格以可稳定估计结果展示。</li>")
    add_note(paste0("有", skipped_n, "个子模型因样本不足或无法估计被自动跳过。"))
  }
  interpretation <- paste0(interpretation, "</ul>")
  
  return(list(
    table = gt_table,
    interpretation = HTML(interpretation),
    model_notes = model_notes,
    code = generate_linear_code("data", linear_response, linear_predictors, strata_var, facet_var, model_strata_var)
  ))
}

generate_linear_code <- function(data_name = "data", linear_response, linear_predictors, linear_strata = NULL, linear_facet = NULL, linear_model_strata = NULL) {
  preds_txt <- if (length(linear_predictors) > 0) paste0("c(", paste(sprintf("\"%s\"", linear_predictors), collapse = ", "), ")") else "character(0)"
  strata_txt <- if (is.null(linear_strata)) "NULL" else paste0("\"", linear_strata, "\"")
  facet_txt <- if (is.null(linear_facet)) "NULL" else paste0("\"", linear_facet, "\"")
  model_strata_txt <- if (is.null(linear_model_strata)) "NULL" else paste0("\"", linear_model_strata, "\"")
  lines <- c(
    "# 1) Load packages",
    "library(stats)",
    "library(dplyr)",
    "library(broom)",
    "library(tidyr)",
    "library(gt)",
    "",
    "# 2) Set analysis parameters",
    paste0("data <- ", data_name),
    paste0("response <- \"", linear_response, "\""),
    paste0("predictors <- ", preds_txt),
    paste0("split_var <- ", strata_txt),
    paste0("facet_var <- ", facet_txt),
    paste0("model_strata_var <- ", model_strata_txt),
    "",
    "# 3) Build linear model formula with optional stratification-control covariate",
    "model_terms <- unique(c(predictors, model_strata_var))",
    "formula_obj <- as.formula(paste(response, \"~\", paste(model_terms, collapse = \"+\")))",
    "",
    "# 4) Fit overall linear regression",
    "fit <- lm(formula_obj, data = data)",
    "overall_tbl <- broom::tidy(fit, conf.int = TRUE)",
    "",
    "# 5) If split_var is provided, compute interaction-based subgroup-difference P-values",
    "if (!is.null(split_var) && split_var != \"None\") {",
    "  lv <- if (is.factor(data[[split_var]])) levels(data[[split_var]]) else unique(as.character(data[[split_var]]))",
    "  lv <- lv[!is.na(lv)]",
    "  ref <- lv[1]",
    "  int_map <- character(0)",
    "  if (is.null(facet_var) || facet_var == \"None\") {",
    "    src <- list(`__ALL__` = data)",
    "  } else {",
    "    fvals <- if (is.factor(data[[facet_var]])) levels(data[[facet_var]]) else unique(as.character(data[[facet_var]]))",
    "    fvals <- fvals[!is.na(fvals)]",
    "    src <- lapply(fvals, function(v) data[data[[facet_var]] == v, , drop = FALSE])",
    "    names(src) <- as.character(fvals)",
    "  }",
    "  for (tg in names(src)) {",
    "    dsub <- src[[tg]]",
    "    for (pred in predictors) {",
    "      f_int <- reformulate(c(setdiff(predictors, pred), pred, split_var, model_strata_var, paste0(pred, \":\", split_var)), response = response)",
    "      td <- tryCatch(broom::tidy(lm(f_int, data = dsub)), error = function(e) NULL)",
    "      for (g in lv[lv != ref]) {",
    "        p <- \"NA\"",
    "        if (!is.null(td) && \"p.value\" %in% names(td)) {",
    "          idx <- which(grepl(\":\", td$term, fixed = TRUE) & grepl(pred, td$term, fixed = TRUE) & grepl(split_var, td$term, fixed = TRUE) & grepl(g, td$term, fixed = TRUE))",
    "          if (length(idx) > 0) p <- format(td$p.value[idx[1]], scientific = FALSE, digits = 4)",
    "        }",
    "        int_map[[paste0(pred, \"||\", g, \"||\", tg)]] <- p",
    "      }",
    "    }",
    "  }",
    "}",
    "",
    "# 6) Print main model result",
    "print(overall_tbl)"
  )
  paste(lines, collapse = "\n")
}
