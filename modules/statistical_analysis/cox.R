# Cox回归分析模块
# 使用 gtsummary 生成 SCI 级表格并提供结果解读

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
    selectInput(ns("cox_strata"), "行分组变量 (Row Group) - 可选", choices = c("None", factor_vars)),
            bsTooltip(ns("cox_strata"), "按该变量分组后，分别拟合并以行分组方式展示结果（非strata()分层项）", placement = "top", trigger = "hover")
      ),
      column(6,
             selectInput(ns("cox_facet"), "分组变量 (Facet, 列分组) - 可选", choices = c("None", factor_vars)),
             bsTooltip(ns("cox_facet"), "按该变量分组后，以列分组方式并排展示Cox回归结果", placement = "top", trigger = "hover")
      )
    ),
    uiOutput(ns("cox_status_mapping_ui")),
    
    selectizeInput(ns("cox_covariates"), "协变量 (Covariates)", choices = names(data), multiple = TRUE),
    bsTooltip(ns("cox_covariates"), "纳入模型的自变量，可多选", placement = "top", trigger = "hover")
  )
}

# Cox回归分析
perform_cox_analysis <- function(data, cox_time, cox_status, cox_covariates, cox_strata, cox_facet = NULL, cox_event_value = NULL) {
  req(cox_time, cox_status)
  
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
  model_notes <- character(0)
  add_note <- function(msg) {
    txt <- trimws(as.character(msg))
    if (nzchar(txt) && !(txt %in% model_notes)) model_notes <<- c(model_notes, txt)
  }

  var_labels <- sapply(cox_covariates, function(v) {
    lv <- attr(data[[v]], "label", exact = TRUE)
    if (is.null(lv) || !nzchar(trimws(as.character(lv)[1]))) v else trimws(as.character(lv)[1])
  }, USE.NAMES = TRUE)
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
    paste0(unname(var_labels[[v]]), suffix)
  }
  get_levels_all <- function(x) {
    if (is.factor(x)) levels(x) else {u <- unique(as.character(x)); u[!is.na(u)]}
  }
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
  interaction_p_map <- function(df_in, strata_nm) {
    if (is.null(strata_nm)) return(setNames(character(0), character(0)))
    out <- setNames(rep("NA", length(cox_covariates)), cox_covariates)
    for (pred in cox_covariates) {
      base_terms <- setdiff(cox_covariates, pred)
      f0 <- stats::reformulate(c(base_terms, pred, strata_nm), response = paste0("survival::Surv(", cox_time, ",", cox_status, ")"))
      f1 <- stats::reformulate(c(base_terms, pred, strata_nm, paste0(pred, ":", strata_nm)), response = paste0("survival::Surv(", cox_time, ",", cox_status, ")"))
      pval <- tryCatch({
        m0 <- survival::coxph(f0, data = df_in)
        m1 <- survival::coxph(f1, data = df_in)
        a <- suppressWarnings(stats::anova(m0, m1, test = "Chisq"))
        pcol <- grep("P", names(a), value = TRUE)
        if (length(pcol) == 0) NA_real_ else as.numeric(a[2, pcol[1]])
      }, warning = function(w) {
        add_note(paste0("分层交互检验提示(", pred, "): ", conditionMessage(w))); NA_real_
      }, error = function(e) {
        add_note(paste0("分层交互检验失败(", pred, "): ", conditionMessage(e))); NA_real_
      })
      out[[pred]] <- format_p(pval)
    }
    out
  }
  if (!is.null(strata_var) && !strata_var %in% names(data)) stop(paste("分层变量", strata_var, "不存在于数据中"))
  if (!is.null(facet_var) && !facet_var %in% names(data)) stop(paste("分组变量", facet_var, "不存在于数据中"))
  if (!is.null(strata_var) && !is.null(facet_var) && identical(strata_var, facet_var)) {
    stop("分层变量与分组变量不能相同")
  }

  # 构建公式字符串
  if (length(cox_covariates) > 0) {
    formula_str <- paste("survival::Surv(", cox_time, ",", cox_status, ") ~", paste(cox_covariates, collapse = "+"))
  } else {
    formula_str <- paste("survival::Surv(", cox_time, ",", cox_status, ") ~ 1")
  }
  
  formula <- as.formula(formula_str)

  build_tbl <- function(df_sub) {
    sub_model <- survival::coxph(formula, data = df_sub)
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

  format_p <- function(p) {
    format_p_value_ama(p)
  }
  ph_global_p <- tryCatch({
    ph_model <- survival::coxph(formula, data = data)
    ph_obj <- survival::cox.zph(ph_model)
    ph_tbl <- as.data.frame(ph_obj$table)
    if ("GLOBAL" %in% rownames(ph_tbl)) as.numeric(ph_tbl["GLOBAL", ncol(ph_tbl)]) else as.numeric(ph_tbl[nrow(ph_tbl), ncol(ph_tbl)])
  }, error = function(e) NA_real_)
  if (!is.na(ph_global_p)) {
    add_note(paste0("比例风险假设检验（Schoenfeld，全局）P=", format_p(ph_global_p), "。"))
    if (is.finite(ph_global_p) && ph_global_p < 0.05) {
      add_note("比例风险假设可能不满足（全局P<0.05），建议结合临床背景与诊断图进一步评估。")
    }
  }

  format_hr_ci <- function(est, low, high) {
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
        fit <- tryCatch(survival::coxph(formula, data = strata_data), error = function(e) NULL)
        if (is.null(fit)) {
          skipped_models <- skipped_models + 1
          next
        }
        tid <- tryCatch(broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE), error = function(e) NULL)
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
        tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_hr_ci(est[i], low[i], high[i]), character(1))
        tid$P值 <- vapply(pvals, format_p, character(1))
        tid$分层差异P值 <- ""
        out_list[[length(out_list) + 1]] <- tid[, c("预测变量", "预测变量原始", "分层", "N", "统计值", "P值", "分层差异P值"), drop = FALSE]
      } else {
        facet_vals <- facet_levels_all
        for (fval in facet_vals) {
          sub_data <- strata_data[strata_data[[facet_var]] == fval, , drop = FALSE]
          if (nrow(sub_data) == 0) next
          fit <- tryCatch(survival::coxph(formula, data = sub_data), error = function(e) NULL)
          if (is.null(fit)) {
            skipped_models <- skipped_models + 1
            next
          }
          tid <- tryCatch(broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE), error = function(e) NULL)
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
          tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_hr_ci(est[i], low[i], high[i]), character(1))
          tid$P值 <- vapply(pvals, format_p, character(1))
          tid$分层差异P值 <- ""
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
      if (length(dummy_preds) == 0) dummy_preds <- cox_covariates
      final_df <- data.frame(
        预测变量 = dummy_preds,
        预测变量原始 = cox_covariates,
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
          分层差异P值 = ""
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
        label_map[[stat_col]] <- "HR (95% CI)"
        label_map[[p_col]] <- "P值"
        lv_text <- if (grepl("组$", lv)) lv else paste0(lv, "组")
        spanner_map[[lv]] <- list(
          label = gt::md(paste0(lv_text, "<br><span style='font-weight:normal'>(N = ", facet_n_map[[lv]], ")</span>")),
          columns = c(n_col, stat_col, p_col)
        )
      }
    } else {
      final_df <- final_df %>% dplyr::select(预测变量, 分层, N, 统计值, P值, 分层差异P值)
      label_map <- list(分层 = "", N = "N", 统计值 = "HR (95% CI)", P值 = "P值")
      spanner_map <- list()
    }
    if (!is.null(strata_var)) label_map[["分层差异P值"]] <- "分层差异P值"
    if (!is.null(strata_var) && length(int_p) > 0) {
      int_keys <- names(int_p)
      interaction_rows <- data.frame(
        预测变量 = paste0(vapply(int_keys, term_to_display, character(1)), " × ", strata_var, " 交互作用检验"),
        分层 = "Overall",
        stringsAsFactors = FALSE
      )
      for (cn in setdiff(names(final_df), names(interaction_rows))) {
        interaction_rows[[cn]] <- ""
      }
      interaction_rows$分层差异P值 <- unname(int_p[int_keys])
      interaction_rows <- interaction_rows[, names(final_df), drop = FALSE]
      final_df <- dplyr::bind_rows(final_df, interaction_rows)
    }
    final_df <- final_df %>%
      dplyr::arrange(预测变量, 分层) %>%
      dplyr::group_by(预测变量, 分层) %>%
      dplyr::mutate(
        分层 = dplyr::case_when(
          grepl("交互作用检验$", 预测变量) ~ 分层,
          dplyr::row_number() == 1 ~ paste0("\u00A0\u00A0\u00A0\u00A0", 分层),
          TRUE ~ ""
        )
      ) %>%
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
    model <- survival::coxph(formula, data = data)
    tbl <- gtsummary::tbl_regression(model, exponentiate = TRUE)
    tbl <- tryCatch(gtsummary::add_global_p(tbl), error = function(e) tbl)
    tbl <- tbl %>%
      gtsummary::bold_p(t = 0.05) %>%
      gtsummary::bold_labels() %>%
      gtsummary::italicize_levels() %>%
      gtsummary::modify_header(label = "预测变量", p.value = "P值")
    gt_table <- gtsummary::as_gt(tbl) %>% apply_clinical_style()
  } else {
    gt_table <- build_strata_first_gt(data, strata_var, facet_var)
  }

  interpretation <- "<h4><b>结果解读 (Result Interpretation):</b></h4><ul>"
  if (!is.null(strata_var)) interpretation <- paste0(interpretation, "<li><b>行分组:</b> ", strata_var, "（按变量分组独立拟合，并非strata()）</li>")
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
    model_notes = model_notes,
    code = generate_cox_code("data", cox_time, cox_status, cox_covariates, strata_var, facet_var, cox_event_value)
  ))
}

# 生成可复现R代码
generate_cox_code <- function(data_name = "data", cox_time, cox_status, cox_covariates, cox_strata, cox_facet = NULL, cox_event_value = "1") {
  covariates_txt <- if (length(cox_covariates) > 0) paste0("c(", paste(sprintf("\"%s\"", cox_covariates), collapse = ", "), ")") else "character(0)"
  strata_txt <- if (is.null(cox_strata)) "NULL" else paste0("\"", cox_strata, "\"")
  facet_txt <- if (is.null(cox_facet)) "NULL" else paste0("\"", cox_facet, "\"")
  lines <- c(
    "library(survival)",
    "library(gtsummary)",
    "library(dplyr)",
    "library(gt)",
    "library(broom)",
    "library(tidyr)",
    "",
    paste0("data <- ", data_name),
    paste0("cox_time <- \"", cox_time, "\""),
    paste0("cox_status <- \"", cox_status, "\""),
    paste0("cox_covariates <- ", covariates_txt),
    paste0("cox_strata <- ", strata_txt),
    paste0("cox_facet <- ", facet_txt),
    paste0("cox_event_value <- \"", cox_event_value, "\""),
    "",
    "format_p <- function(p) {",
    "  p <- suppressWarnings(as.numeric(p))",
    "  if (is.na(p)) return(\"NA\")",
    "  if (p < 0.001) return(\"<0.001\")",
    "  sub(\"\\\\.?0+$\", \"\", sprintf(\"%.3f\", p))",
    "}",
    "format_hr_ci <- function(est, low, high) {",
    "  est <- suppressWarnings(as.numeric(est))",
    "  low <- suppressWarnings(as.numeric(low))",
    "  high <- suppressWarnings(as.numeric(high))",
    "  if (is.na(est)) return(\"NA\")",
    "  if (any(is.na(c(low, high)))) return(sub(\"\\\\.?0+$\", \"\", sprintf(\"%.4f\", est)))",
    "  paste0(sub(\"\\\\.?0+$\", \"\", sprintf(\"%.4f\", est)), \" (\", sub(\"\\\\.?0+$\", \"\", sprintf(\"%.4f\", low)), \", \", sub(\"\\\\.?0+$\", \"\", sprintf(\"%.4f\", high)), \")\")",
    "}",
    "count_effective_n <- function(df_sub) {",
    "  vars <- unique(c(cox_time, cox_status, cox_covariates))",
    "  vars <- vars[vars %in% names(df_sub)]",
    "  if (length(vars) == 0) return(0L)",
    "  sum(stats::complete.cases(df_sub[, vars, drop = FALSE]))",
    "}",
    "status_vals <- unique(as.character(data[[cox_status]][!is.na(data[[cox_status]])]))",
    "event_val <- as.character(cox_event_value)",
    "if (is.null(cox_event_value) || !event_val %in% status_vals) event_val <- if (\"1\" %in% status_vals) \"1\" else status_vals[1]",
    "data[[cox_status]] <- ifelse(as.character(data[[cox_status]]) == event_val, 1, ifelse(!is.na(data[[cox_status]]), 0, NA_real_))",
    "strata_var <- if (!is.null(cox_strata) && cox_strata != \"None\") cox_strata else NULL",
    "facet_var <- if (!is.null(cox_facet) && cox_facet != \"None\") cox_facet else NULL",
    "formula_obj <- if (length(cox_covariates) > 0) {",
    "  as.formula(paste0(\"survival::Surv(\", cox_time, \",\", cox_status, \") ~ \", paste(cox_covariates, collapse = \" + \")))",
    "} else {",
    "  as.formula(paste0(\"survival::Surv(\", cox_time, \",\", cox_status, \") ~ 1\"))",
    "}",
    "",
    "if (is.null(strata_var) && is.null(facet_var)) {",
    "  model <- survival::coxph(formula_obj, data = data)",
    "  tbl <- gtsummary::tbl_regression(model, exponentiate = TRUE)",
    "  tbl <- tryCatch(gtsummary::add_global_p(tbl), error = function(e) tbl)",
    "  tbl <- tbl %>%",
    "    gtsummary::bold_p(t = 0.05) %>%",
    "    gtsummary::bold_labels() %>%",
    "    gtsummary::italicize_levels() %>%",
    "    gtsummary::modify_header(label = \"预测变量\", p.value = \"P值\")",
    "  gt_table <- gtsummary::as_gt(tbl)",
    "} else {",
    "  term_to_display <- function(term) {",
    "    ordered <- cox_covariates[order(nchar(cox_covariates), decreasing = TRUE)]",
    "    hit <- ordered[startsWith(as.character(term), ordered)]",
    "    if (length(hit) == 0) return(as.character(term))",
    "    v <- hit[1]",
    "    suffix <- substring(as.character(term), nchar(v) + 1)",
    "    paste0(v, suffix)",
    "  }",
    "  predictor_key <- function(term_raw) {",
    "    ordered <- cox_covariates[order(nchar(cox_covariates), decreasing = TRUE)]",
    "    hit <- ordered[startsWith(as.character(term_raw), ordered)]",
    "    if (length(hit) == 0) return(NA_character_)",
    "    hit[1]",
    "  }",
    "  get_levels_all <- function(x) { if (is.factor(x)) levels(x) else {u <- unique(as.character(x)); u[!is.na(u)]} }",
    "  interaction_p_map <- function(df_in, strata_nm) {",
    "    if (is.null(strata_nm)) return(setNames(character(0), character(0)))",
    "    out <- setNames(rep(\"NA\", length(cox_covariates)), cox_covariates)",
    "    for (pred in cox_covariates) {",
    "      base_terms <- setdiff(cox_covariates, pred)",
    "      f0 <- stats::reformulate(c(base_terms, pred, strata_nm), response = paste0(\"survival::Surv(\", cox_time, \",\", cox_status, \")\"))",
    "      f1 <- stats::reformulate(c(base_terms, pred, strata_nm, paste0(pred, \":\", strata_nm)), response = paste0(\"survival::Surv(\", cox_time, \",\", cox_status, \")\"))",
    "      pval <- tryCatch({",
    "        m0 <- survival::coxph(f0, data = df_in)",
    "        m1 <- survival::coxph(f1, data = df_in)",
    "        a <- suppressWarnings(stats::anova(m0, m1, test = \"Chisq\"))",
    "        pcol <- grep(\"P\", names(a), value = TRUE)",
    "        if (length(pcol) == 0) NA_real_ else as.numeric(a[2, pcol[1]])",
    "      }, error = function(e) NA_real_)",
    "      out[[pred]] <- format_p(pval)",
    "    }",
    "    out",
    "  }",
    "  strata_vals <- if (is.null(strata_var)) \"总体\" else get_levels_all(data[[strata_var]])",
    "  facet_levels_all <- if (!is.null(facet_var)) get_levels_all(data[[facet_var]]) else character(0)",
    "  int_p <- interaction_p_map(data, strata_var)",
    "  out_list <- list()",
    "  for (sval in strata_vals) {",
    "    strata_data <- if (is.null(strata_var)) data else data[data[[strata_var]] == sval, , drop = FALSE]",
    "    if (nrow(strata_data) == 0) next",
    "    if (is.null(facet_var)) {",
    "      fit <- tryCatch(survival::coxph(formula_obj, data = strata_data), error = function(e) NULL)",
    "      if (is.null(fit)) next",
    "      tid <- tryCatch(broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE), error = function(e) NULL)",
    "      if (is.null(tid)) next",
    "      tid <- tid[tid$term != \"(Intercept)\", , drop = FALSE]",
    "      if (nrow(tid) == 0) next",
    "      tid$预测变量 <- vapply(tid$term, term_to_display, character(1))",
    "      tid$预测变量原始 <- vapply(tid$term, predictor_key, character(1))",
    "      tid$分层 <- if (is.null(strata_var)) \"总体\" else as.character(sval)",
    "      tid$N <- as.character(count_effective_n(strata_data))",
    "      tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_hr_ci(tid$estimate[i], tid$conf.low[i], tid$conf.high[i]), character(1))",
    "      tid$P值 <- vapply(tid$p.value, format_p, character(1))",
    "      tid$分层差异P值 <- \"\"",
    "      out_list[[length(out_list) + 1]] <- tid[, c(\"预测变量\", \"分层\", \"N\", \"统计值\", \"P值\", \"分层差异P值\"), drop = FALSE]",
    "    } else {",
    "      for (fval in facet_levels_all) {",
    "        sub_data <- strata_data[strata_data[[facet_var]] == fval, , drop = FALSE]",
    "        if (nrow(sub_data) == 0) next",
    "        fit <- tryCatch(survival::coxph(formula_obj, data = sub_data), error = function(e) NULL)",
    "        if (is.null(fit)) next",
    "        tid <- tryCatch(broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE), error = function(e) NULL)",
    "        if (is.null(tid)) next",
    "        tid <- tid[tid$term != \"(Intercept)\", , drop = FALSE]",
    "        if (nrow(tid) == 0) next",
    "        tid$预测变量 <- vapply(tid$term, term_to_display, character(1))",
    "        tid$预测变量原始 <- vapply(tid$term, predictor_key, character(1))",
    "        tid$分层 <- if (is.null(strata_var)) \"总体\" else as.character(sval)",
    "        tid$列分组 <- as.character(fval)",
    "        tid$N <- as.character(count_effective_n(sub_data))",
    "        tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_hr_ci(tid$estimate[i], tid$conf.low[i], tid$conf.high[i]), character(1))",
    "        tid$P值 <- vapply(tid$p.value, format_p, character(1))",
    "        tid$分层差异P值 <- \"\"",
    "        out_list[[length(out_list) + 1]] <- tid[, c(\"预测变量\", \"分层\", \"列分组\", \"N\", \"统计值\", \"P值\", \"分层差异P值\"), drop = FALSE]",
    "      }",
    "    }",
    "  }",
    "  final_df <- dplyr::bind_rows(out_list)",
    "  if (\"列分组\" %in% names(final_df)) {",
    "    final_df <- final_df %>% tidyr::pivot_wider(names_from = 列分组, values_from = c(N, 统计值, P值), names_glue = \"{列分组}__{.value}\", values_fill = \"NA\")",
    "  }",
    "  if (!is.null(strata_var) && length(int_p) > 0) {",
    "    int_keys <- names(int_p)",
    "    interaction_rows <- data.frame(预测变量 = paste0(vapply(int_keys, term_to_display, character(1)), \" × \", strata_var, \" 交互作用检验\"), 分层 = \"Overall\", stringsAsFactors = FALSE)",
    "    for (cn in setdiff(names(final_df), names(interaction_rows))) interaction_rows[[cn]] <- \"\"",
    "    interaction_rows$分层差异P值 <- unname(int_p[int_keys])",
    "    interaction_rows <- interaction_rows[, names(final_df), drop = FALSE]",
    "    final_df <- dplyr::bind_rows(final_df, interaction_rows)",
    "  }",
    "  gt_table <- gt::gt(final_df, groupname_col = \"预测变量\")",
    "}",
    "print(gt_table)"
  )
  paste(lines, collapse = "\n")
}
