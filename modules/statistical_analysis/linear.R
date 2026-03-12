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
             selectInput(ns("linear_strata"), "分层变量 (Strata, 行分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("linear_strata"), "按该变量分层后，以行分组方式展示各层回归结果", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("linear_facet"), "分组变量 (Facet, 列分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("linear_facet"), "按该变量分组后，以列分组方式并排展示回归结果", placement = "top", trigger = "hover")
      )
    ),
    
    selectizeInput(ns("linear_predictors"), "预测变量 (Predictors)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("linear_predictors"), "自变量 (可多选)", placement = "top", trigger = "hover")
  )
}

# 线性回归分析
perform_linear_analysis <- function(data, linear_response, linear_predictors, linear_strata = NULL, linear_facet = NULL) {
  req(linear_response, linear_predictors)
  
  # 验证变量
  if (!linear_response %in% names(data)) stop(paste("响应变量", linear_response, "不存在"))
  missing_preds <- linear_predictors[!linear_predictors %in% names(data)]
  if (length(missing_preds) > 0) stop(paste("预测变量不存在:", paste(missing_preds, collapse = ", ")))
  
  strata_var <- if (!is.null(linear_strata) && linear_strata != "None") linear_strata else NULL
  facet_var <- if (!is.null(linear_facet) && linear_facet != "None") linear_facet else NULL
  if (!is.null(strata_var) && !strata_var %in% names(data)) stop(paste("分层变量", strata_var, "不存在"))
  if (!is.null(facet_var) && !facet_var %in% names(data)) stop(paste("分组变量", facet_var, "不存在"))
  if (!is.null(strata_var) && !is.null(facet_var) && identical(strata_var, facet_var)) {
    stop("分层变量与分组变量不能相同")
  }

  formula_str <- paste(linear_response, "~", paste(linear_predictors, collapse = "+"))
  formula <- as.formula(formula_str)

  build_tbl <- function(df_sub) {
    model <- lm(formula, data = df_sub)
    gtsummary::tbl_regression(model) %>%
      gtsummary::add_global_p() %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "**预测变量**", p.value = "**P值**")
  }

  format_p <- function(p) {
    if (is.na(p)) return("NA")
    if (p < 0.001) return("<0.001")
    sprintf("%.3f", p)
  }

  format_beta_ci <- function(est, low, high) {
    if (any(is.na(c(est, low, high)))) return("NA")
    paste0(sprintf("%.3f", est), " (", sprintf("%.3f", low), ", ", sprintf("%.3f", high), ")")
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
    styled %>% gt::tab_source_note(gt::md("注：Beta(95%CI)为回归系数及区间估计，P值用于显著性判断。"))
  }

  build_strata_first_gt <- function(df_in, strata_var = NULL, facet_var = NULL) {
    if (is.null(strata_var)) {
      strata_vals <- "总体"
    } else {
      strata_vals <- unique(df_in[[strata_var]])
      strata_vals <- strata_vals[!is.na(strata_vals)]
    }
    out_list <- list()
    skipped_models <- 0

    for (sval in strata_vals) {
      strata_data <- if (is.null(strata_var)) df_in else df_in[df_in[[strata_var]] == sval, , drop = FALSE]
      if (nrow(strata_data) == 0) next
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
        tid$预测变量 <- tid$term
        tid$分层 <- if (is.null(strata_var)) "总体" else as.character(sval)
        tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_beta_ci(est[i], low[i], high[i]), character(1))
        tid$P值 <- vapply(pvals, format_p, character(1))
        out_list[[length(out_list) + 1]] <- tid[, c("预测变量", "分层", "统计值", "P值"), drop = FALSE]
      } else {
        facet_vals <- unique(strata_data[[facet_var]])
        facet_vals <- facet_vals[!is.na(facet_vals)]
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
          tid$预测变量 <- tid$term
          tid$分层 <- if (is.null(strata_var)) "总体" else as.character(sval)
          tid$列分组 <- as.character(fval)
          tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_beta_ci(est[i], low[i], high[i]), character(1))
          tid$P值 <- vapply(pvals, format_p, character(1))
          out_list[[length(out_list) + 1]] <- tid[, c("预测变量", "分层", "列分组", "统计值", "P值"), drop = FALSE]
        }
      }
    }

    if (length(out_list) == 0) {
      stop("无法为任何分层生成模型结果，请检查各层样本量。")
    }

    final_df <- dplyr::bind_rows(out_list)
    if ("列分组" %in% names(final_df)) {
      facet_levels_all <- unique(as.character(df_in[[facet_var]]))
      facet_levels_all <- facet_levels_all[!is.na(facet_levels_all)]
      facet_n_map <- sapply(facet_levels_all, function(x) {
        sum(as.character(df_in[[facet_var]]) == x, na.rm = TRUE)
      }, USE.NAMES = TRUE)
      final_df <- final_df %>%
        tidyr::pivot_wider(names_from = 列分组, values_from = c(统计值, P值), names_sep = "__", values_fill = "NA")
      expected_cols <- as.vector(rbind(paste0(facet_levels_all, "__统计值"), paste0(facet_levels_all, "__P值")))
      missing_cols <- setdiff(expected_cols, names(final_df))
      if (length(missing_cols) > 0) {
        for (mc in missing_cols) final_df[[mc]] <- "NA"
      }
      final_df <- final_df %>% dplyr::select(预测变量, 分层, dplyr::all_of(expected_cols))
      label_map <- list(分层 = "")
      spanner_map <- list()
      for (lv in facet_levels_all) {
        stat_col <- paste0(lv, "__统计值")
        p_col <- paste0(lv, "__P值")
        label_map[[stat_col]] <- "Beta (95% CI)"
        label_map[[p_col]] <- "P值"
        lv_text <- if (grepl("组$", lv)) lv else paste0(lv, "组")
        spanner_map[[lv]] <- list(
          label = gt::md(paste0(lv_text, "<br><span style='font-weight:normal'>(N = ", facet_n_map[[lv]], ")</span>")),
          columns = c(stat_col, p_col)
        )
      }
    } else {
      label_map <- list(分层 = "", 统计值 = "Beta (95% CI)", P值 = "P值")
      spanner_map <- list()
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
    model <- lm(formula, data = data)
    tbl <- gtsummary::tbl_regression(model) %>%
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
  }
  interpretation <- paste0(interpretation, "</ul>")
  
  return(list(
    table = gt_table,
    interpretation = HTML(interpretation)
  ))
}
