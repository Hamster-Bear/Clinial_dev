# 逻辑回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

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
             selectInput(ns("logistic_strata"), "分层变量 (Strata, 行分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_strata"), "按该变量分层后，以行分组方式展示各层回归结果", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("logistic_facet"), "分组变量 (Facet, 列分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("logistic_facet"), "按该变量分组后，以列分组方式并排展示回归结果", placement = "top", trigger = "hover")
      )
    ),
    uiOutput(ns("logistic_event_mapping_ui")),
    
    selectizeInput(ns("logistic_predictors"), "预测变量 (Predictors)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("logistic_predictors"), "纳入模型的自变量 (解释变量)", placement = "top", trigger = "hover")
  )
}

# 逻辑回归分析
perform_logistic_analysis <- function(data, logistic_response, logistic_predictors, logistic_strata = NULL, logistic_facet = NULL, logistic_event_value = NULL) {
  req(logistic_response, logistic_predictors)
  
  # 验证变量
  if (!logistic_response %in% names(data)) stop(paste("响应变量", logistic_response, "不存在"))
  missing_preds <- logistic_predictors[!logistic_predictors %in% names(data)]
  if (length(missing_preds) > 0) stop(paste("预测变量不存在:", paste(missing_preds, collapse = ", ")))

  strata_var <- if (!is.null(logistic_strata) && logistic_strata != "None") logistic_strata else NULL
  facet_var <- if (!is.null(logistic_facet) && logistic_facet != "None") logistic_facet else NULL
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

  interaction_p_map <- function(df_in, strata_nm) {
    if (is.null(strata_nm)) return(setNames(character(0), character(0)))
    out <- setNames(rep("NA", length(logistic_predictors)), logistic_predictors)
    for (pred in logistic_predictors) {
      base_terms <- setdiff(logistic_predictors, pred)
      f0 <- stats::reformulate(c(base_terms, pred, strata_nm), response = logistic_response)
      f1 <- stats::reformulate(c(base_terms, pred, strata_nm, paste0(pred, ":", strata_nm)), response = logistic_response)
      pval <- tryCatch({
        m0 <- stats::glm(f0, data = df_in, family = binomial())
        m1 <- stats::glm(f1, data = df_in, family = binomial())
        a <- stats::anova(m0, m1, test = "LRT")
        as.numeric(a[2, ncol(a)])
      }, warning = function(w) {
        add_note(paste0("分层交互检验提示(", pred, "): ", conditionMessage(w)))
        NA_real_
      }, error = function(e) {
        add_note(paste0("分层交互检验失败(", pred, "): ", conditionMessage(e)))
        NA_real_
      })
      out[[pred]] <- format_p(pval)
    }
    out
  }
  if (!is.null(strata_var) && !strata_var %in% names(data)) stop(paste("分层变量", strata_var, "不存在"))
  if (!is.null(facet_var) && !facet_var %in% names(data)) stop(paste("分组变量", facet_var, "不存在"))
  if (!is.null(strata_var) && !is.null(facet_var) && identical(strata_var, facet_var)) {
    stop("分层变量与分组变量不能相同")
  }

  formula_str <- paste(logistic_response, "~", paste(logistic_predictors, collapse = "+"))
  formula <- as.formula(formula_str)

  build_tbl <- function(df_sub) {
    model <- glm(formula, data = df_sub, family = binomial())
    gtsummary::tbl_regression(model, exponentiate = TRUE) %>%
      gtsummary::add_n() %>%
      gtsummary::add_global_p() %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "**预测变量**", p.value = "**P值**")
  }

  format_p <- function(p) {
    if (is.na(p)) return("NA")
    if (p < 0.0001) return("<0.0001")
    sub("\\.?0+$", "", sprintf("%.4f", p))
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
    styled <- gt_tbl %>%
      gt::tab_options(
        table.width = gt::pct(100),
        table.font.size = "small",
        row_group.font.weight = "bold",
        column_labels.font.weight = "bold",
        table_body.hlines.color = "#D9D9D9",
        table_body.border.top.color = "#333333",
        table_body.border.bottom.color = "#333333",
        heading.border.bottom.color = "#333333"
      )
    if ("分层" %in% col_names) {
      styled <- styled %>%
        gt::cols_align(align = "left", columns = c("分层")) %>%
        gt::tab_style(
          style = gt::cell_text(indent = gt::px(4)),
          locations = gt::cells_body(columns = "分层")
        )
    }
    styled %>% gt::tab_source_note(gt::md("注：OR(95%CI)为效应量及区间估计，P值用于显著性判断。"))
  }

  build_strata_first_gt <- function(df_in, strata_var = NULL, facet_var = NULL) {
    if (is.null(strata_var)) {
      strata_vals <- "总体"
    } else {
      strata_vals <- get_levels_all(df_in[[strata_var]])
    }
    out_list <- list()
    skipped_models <- 0
    int_p <- interaction_p_map(df_in, strata_var)
    facet_levels_all <- if (!is.null(facet_var)) get_levels_all(df_in[[facet_var]]) else character(0)

    for (sval in strata_vals) {
      strata_data <- if (is.null(strata_var)) df_in else df_in[df_in[[strata_var]] == sval, , drop = FALSE]
      if (nrow(strata_data) == 0) {
        add_note(paste0("分层[", sval, "]无可用样本，已以占位形式展示。"))
        next
      }
      if (is.null(facet_var)) {
        fit <- tryCatch(glm(formula, data = strata_data, family = binomial()), error = function(e) {
          add_note(paste0("分层[", sval, "]建模失败: ", conditionMessage(e)))
          NULL
        })
        if (is.null(fit)) {
          skipped_models <- skipped_models + 1
          next
        }
        tid <- tryCatch(broom::tidy(fit), error = function(e) {
          add_note(paste0("分层[", sval, "]结果整理失败: ", conditionMessage(e)))
          NULL
        })
        if (is.null(tid)) {
          skipped_models <- skipped_models + 1
          next
        }
        tid <- tid[tid$term != "(Intercept)", , drop = FALSE]
        if (nrow(tid) == 0) next
        beta <- if ("estimate" %in% names(tid)) tid$estimate else rep(NA_real_, nrow(tid))
        se <- if ("std.error" %in% names(tid)) tid$std.error else rep(NA_real_, nrow(tid))
        beta <- suppressWarnings(as.numeric(beta))
        se <- suppressWarnings(as.numeric(se))
        est <- exp(beta)
        low <- exp(beta - 1.96 * se)
        high <- exp(beta + 1.96 * se)
        pvals <- if ("p.value" %in% names(tid)) tid$p.value else rep(NA_real_, nrow(tid))
        tid$预测变量 <- vapply(tid$term, term_to_display, character(1))
        tid$预测变量原始 <- vapply(tid$term, predictor_key, character(1))
        tid$分层 <- if (is.null(strata_var)) "总体" else as.character(sval)
        tid$N <- as.character(count_effective_n(strata_data))
        tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_or_ci(est[i], low[i], high[i]), character(1))
        tid$P值 <- vapply(pvals, format_p, character(1))
        tid$分层差异P值 <- if (!is.null(strata_var)) int_p[tid$预测变量原始] else ""
        out_list[[length(out_list) + 1]] <- tid[, c("预测变量", "预测变量原始", "分层", "N", "统计值", "P值", "分层差异P值"), drop = FALSE]
      } else {
        facet_vals <- facet_levels_all
        for (fval in facet_vals) {
          sub_data <- strata_data[strata_data[[facet_var]] == fval, , drop = FALSE]
          if (nrow(sub_data) == 0) next
          fit <- tryCatch(glm(formula, data = sub_data, family = binomial()), error = function(e) {
            add_note(paste0("分层[", sval, "]分组[", fval, "]建模失败: ", conditionMessage(e)))
            NULL
          })
          if (is.null(fit)) {
            skipped_models <- skipped_models + 1
            next
          }
          tid <- tryCatch(broom::tidy(fit), error = function(e) {
            add_note(paste0("分层[", sval, "]分组[", fval, "]结果整理失败: ", conditionMessage(e)))
            NULL
          })
          if (is.null(tid)) {
            skipped_models <- skipped_models + 1
            next
          }
          tid <- tid[tid$term != "(Intercept)", , drop = FALSE]
          if (nrow(tid) == 0) next
          beta <- if ("estimate" %in% names(tid)) tid$estimate else rep(NA_real_, nrow(tid))
          se <- if ("std.error" %in% names(tid)) tid$std.error else rep(NA_real_, nrow(tid))
          beta <- suppressWarnings(as.numeric(beta))
          se <- suppressWarnings(as.numeric(se))
          est <- exp(beta)
          low <- exp(beta - 1.96 * se)
          high <- exp(beta + 1.96 * se)
          pvals <- if ("p.value" %in% names(tid)) tid$p.value else rep(NA_real_, nrow(tid))
          tid$预测变量 <- vapply(tid$term, term_to_display, character(1))
          tid$预测变量原始 <- vapply(tid$term, predictor_key, character(1))
          tid$分层 <- if (is.null(strata_var)) "总体" else as.character(sval)
          tid$列分组 <- as.character(fval)
          tid$N <- as.character(count_effective_n(sub_data))
          tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_or_ci(est[i], low[i], high[i]), character(1))
          tid$P值 <- vapply(pvals, format_p, character(1))
          tid$分层差异P值 <- if (!is.null(strata_var)) int_p[tid$预测变量原始] else ""
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
      if (length(dummy_preds) == 0) dummy_preds <- logistic_predictors
      final_df <- data.frame(
        预测变量 = dummy_preds,
        预测变量原始 = logistic_predictors,
        分层 = if (is.null(strata_var)) "总体" else strata_vals[1],
        N = "0",
        统计值 = "NA",
        P值 = "NA",
        分层差异P值 = if (!is.null(strata_var)) int_p[logistic_predictors] else "",
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
          分层差异P值 = ifelse(is.na(分层差异P值), "", 分层差异P值)
        )
    }
    if ("列分组" %in% names(final_df)) {
      facet_n_map <- sapply(facet_levels_all, function(x) {
        sum(as.character(df_in[[facet_var]]) == x, na.rm = TRUE)
      }, USE.NAMES = TRUE)
      final_df <- final_df %>%
        tidyr::pivot_wider(names_from = 列分组, values_from = c(N, 统计值, P值), names_glue = "{列分组}__{.value}", values_fill = "NA")
      expected_cols <- as.vector(rbind(paste0(facet_levels_all, "__N"), paste0(facet_levels_all, "__统计值"), paste0(facet_levels_all, "__P值")))
      missing_cols <- setdiff(expected_cols, names(final_df))
      if (length(missing_cols) == length(expected_cols)) {
        stop("列分组结果展开失败：未生成任何预期列，请检查分组变量取值与模型输出。")
      }
      if (length(missing_cols) > 0) {
        for (mc in missing_cols) final_df[[mc]] <- if (grepl("__N$", mc)) "0" else "NA"
      }
      final_df <- final_df %>% dplyr::select(预测变量, 分层, dplyr::all_of(expected_cols), 分层差异P值)
      label_map <- list(分层 = "")
      spanner_map <- list()
      for (lv in facet_levels_all) {
        n_col <- paste0(lv, "__N")
        stat_col <- paste0(lv, "__统计值")
        p_col <- paste0(lv, "__P值")
        label_map[[n_col]] <- "N"
        label_map[[stat_col]] <- "OR (95% CI)"
        label_map[[p_col]] <- "P值"
        lv_text <- if (grepl("组$", lv)) lv else paste0(lv, "组")
        spanner_map[[lv]] <- list(
          label = gt::md(paste0(lv_text, "<br><span style='font-weight:normal'>(N = ", facet_n_map[[lv]], ")</span>")),
          columns = c(n_col, stat_col, p_col)
        )
      }
    } else {
      final_df <- final_df %>% dplyr::select(预测变量, 分层, N, 统计值, P值, 分层差异P值)
      label_map <- list(分层 = "", N = "N", 统计值 = "OR (95% CI)", P值 = "P值")
      spanner_map <- list()
    }
    if (!is.null(strata_var)) {
      label_map[["分层差异P值"]] <- "分层差异P值"
    }
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
    model <- glm(formula, data = data, family = binomial())
    tbl <- gtsummary::tbl_regression(model, exponentiate = TRUE) %>%
      gtsummary::add_global_p() %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "**预测变量**", p.value = "**P值**")
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
          facet_headers <- c(facet_headers, paste0("**", val_text, " (N=", n_val, ")**"))
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
  if (!is.null(strata_var)) interpretation <- paste0(interpretation, "<li><b>行分组(分层):</b> ", strata_var, "</li>")
  if (!is.null(facet_var)) interpretation <- paste0(interpretation, "<li><b>列分组(分组):</b> ", facet_var, "</li>")
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
    model_notes = model_notes
  ))
}
