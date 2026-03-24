ensure_stat_analysis_dependencies <- function() {
  if (!exists("%>%", mode = "function")) {
    assign("%>%", dplyr::`%>%`, envir = .GlobalEnv)
  }
  if (!exists("apply_sci_gt_style", mode = "function") || !exists("format_p_value_ama", mode = "function")) {
    source("modules/common/table_export.R")
  }
  if (!exists("format_p_value_regression", mode = "function") || !exists("build_repro_code_template", mode = "function")) {
    source("modules/common/analysis_format.R")
  }
  invisible(TRUE)
}

get_levels_all <- function(x) {
  if (is.factor(x)) {
    levels(x)
  } else {
    u <- unique(as.character(x))
    u[!is.na(u)]
  }
}

normalize_optional_var <- function(x) {
  if (is.null(x)) return(NULL)
  txt <- trimws(as.character(x)[1])
  if (!nzchar(txt) || txt %in% c("None", "无")) return(NULL)
  txt
}

validate_regression_inputs <- function(data, response, predictors, split_var = NULL, facet_var = NULL, model_strata_var = NULL, analysis_name = "回归") {
  if (!is.data.frame(data)) stop(paste0(analysis_name, "输入数据必须是 data.frame。"))
  if (is.null(response) || !nzchar(trimws(as.character(response)))) stop(paste0(analysis_name, "未设置响应变量。"))
  if (!response %in% names(data)) stop(paste0("响应变量 ", response, " 不存在。"))
  if (is.null(predictors) || length(predictors) == 0) stop(paste0(analysis_name, "至少需要一个预测变量。"))
  missing_preds <- predictors[!predictors %in% names(data)]
  if (length(missing_preds) > 0) stop(paste0("预测变量不存在: ", paste(missing_preds, collapse = ", ")))
  if (response %in% predictors) stop("响应变量不能同时作为预测变量。")
  overlap_ctrl <- intersect(predictors, setdiff(c(split_var, facet_var, model_strata_var), NULL))
  if (length(overlap_ctrl) > 0) stop(paste0("预测变量不能与亚组/分组/分层变量重复: ", paste(overlap_ctrl, collapse = ", ")))
  if (!is.null(split_var) && !split_var %in% names(data)) stop(paste0("亚组变量 ", split_var, " 不存在。"))
  if (!is.null(facet_var) && !facet_var %in% names(data)) stop(paste0("分组变量 ", facet_var, " 不存在。"))
  if (!is.null(model_strata_var) && !model_strata_var %in% names(data)) stop(paste0("分层变量 ", model_strata_var, " 不存在。"))
  if (!is.null(split_var) && !is.null(facet_var) && identical(split_var, facet_var)) stop("亚组变量与分组变量不能相同。")
  invisible(TRUE)
}

get_regression_candidate_predictors <- function(df, response_var = NULL, split_var = NULL, facet_var = NULL, model_strata_var = NULL) {
  all_vars <- names(df)
  excluded <- unique(na.omit(c(response_var, split_var, facet_var, model_strata_var)))
  setdiff(all_vars, excluded)
}

compute_interaction_p_map <- function(
  df_in,
  predictors,
  strata_nm,
  strata_levels,
  fit_tidy_fn,
  facet_var = NULL
) {
  if (is.null(strata_nm) || length(strata_levels) <= 1) return(character(0))
  ref_level <- as.character(strata_levels[1])
  facet_tags <- if (is.null(facet_var)) "__ALL__" else get_levels_all(df_in[[facet_var]])
  out <- character(0)
  for (tg in facet_tags) {
    dsub <- if (is.null(facet_var)) df_in else df_in[as.character(df_in[[facet_var]]) == as.character(tg), , drop = FALSE]
    if (nrow(dsub) == 0) next
    for (pred in predictors) {
      td <- fit_tidy_fn(dsub, pred, strata_nm)
      for (lv in as.character(strata_levels[as.character(strata_levels) != ref_level])) {
        p_fmt <- "NA"
        if (!is.null(td) && is.data.frame(td) && nrow(td) > 0 && "p.value" %in% names(td)) {
          idx <- which(
            grepl(":", td$term, fixed = TRUE) &
              grepl(pred, td$term, fixed = TRUE) &
              grepl(strata_nm, td$term, fixed = TRUE) &
              grepl(lv, td$term, fixed = TRUE)
          )
          if (length(idx) > 0) p_fmt <- format_p_value_regression(td$p.value[idx[1]])
        }
        out[[paste0(pred, "||", lv, "||", as.character(tg))]] <- p_fmt
      }
    }
  }
  out
}

get_interaction_p_value <- function(int_map, pred_key, sval, facet_tag = "__ALL__") {
  key <- paste0(pred_key, "||", as.character(sval), "||", facet_tag)
  if (key %in% names(int_map)) unname(int_map[[key]]) else "NA"
}

build_regression_split_facet_gt <- function(
  df_in,
  predictors,
  strata_var = NULL,
  facet_var = NULL,
  strata_vals,
  metric_label,
  fit_tidy_fn,
  term_to_display_fn,
  predictor_key_fn,
  count_effective_n_fn,
  format_estimate_fn,
  format_p_fn,
  apply_style_fn,
  add_note_fn = NULL,
  int_p_map = character(0),
  get_int_p_fn = NULL
) {
  out_list <- list()
  skipped_models <- 0L
  facet_levels_all <- if (!is.null(facet_var)) {
    get_levels_all(df_in[[facet_var]])
  } else character(0)
  for (sval in strata_vals) {
    strata_data <- if (is.null(strata_var)) df_in else df_in[df_in[[strata_var]] == sval, , drop = FALSE]
    if (nrow(strata_data) == 0) {
      if (!is.null(add_note_fn)) add_note_fn(paste0("亚组[", sval, "]无可用样本，已以占位形式展示。"))
      next
    }
    facet_values <- if (is.null(facet_var)) "__ALL__" else facet_levels_all
    for (fval in facet_values) {
      sub_data <- if (is.null(facet_var)) strata_data else strata_data[as.character(strata_data[[facet_var]]) == as.character(fval), , drop = FALSE]
      if (nrow(sub_data) == 0) next
      tid <- fit_tidy_fn(sub_data, sval, fval)
      if (is.null(tid) || !is.data.frame(tid) || nrow(tid) == 0) {
        skipped_models <- skipped_models + 1L
        next
      }
      if ("term" %in% names(tid)) tid <- tid[tid$term != "(Intercept)", , drop = FALSE]
      if (nrow(tid) == 0) next
      est <- if ("estimate" %in% names(tid)) tid$estimate else rep(NA_real_, nrow(tid))
      low <- if ("conf.low" %in% names(tid)) tid$conf.low else rep(NA_real_, nrow(tid))
      high <- if ("conf.high" %in% names(tid)) tid$conf.high else rep(NA_real_, nrow(tid))
      pvals <- if ("p.value" %in% names(tid)) tid$p.value else rep(NA_real_, nrow(tid))
      tid$预测变量 <- vapply(tid$term, term_to_display_fn, character(1))
      tid$预测变量原始 <- vapply(tid$term, predictor_key_fn, character(1))
      tid$亚组 <- if (is.null(strata_var)) "总体" else as.character(sval)
      tid$N <- as.character(count_effective_n_fn(sub_data))
      tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_estimate_fn(est[i], low[i], high[i]), character(1))
      tid$P值 <- vapply(pvals, format_p_fn, character(1))
      if (!is.null(strata_var)) {
        if (as.character(sval) != as.character(strata_vals[1]) && !is.null(get_int_p_fn)) {
          tid$亚组差异P值 <- vapply(
            tid$预测变量原始,
            function(pk) get_int_p_fn(int_p_map, pk, as.character(sval), if (is.null(facet_var)) "__ALL__" else as.character(fval)),
            character(1)
          )
        } else {
          tid$亚组差异P值 <- ""
        }
      }
      if (!is.null(facet_var)) tid$列分组 <- as.character(fval)
      keep_cols <- c("预测变量", "预测变量原始", "亚组", if (!is.null(facet_var)) "列分组", "N", "统计值", "P值", if (!is.null(strata_var)) "亚组差异P值")
      out_list[[length(out_list) + 1L]] <- tid[, keep_cols, drop = FALSE]
    }
  }
  if (length(out_list) == 0) {
    stop("无法为任何亚组生成模型结果，请检查各组样本量。")
  }
  final_df <- dplyr::bind_rows(out_list)
  if (nrow(final_df) == 0) {
    final_df <- data.frame(
      预测变量 = predictors,
      预测变量原始 = predictors,
      亚组 = if (is.null(strata_var)) "总体" else as.character(strata_vals[1]),
      N = "0",
      统计值 = "NA",
      P值 = "NA",
      stringsAsFactors = FALSE
    )
    if (!is.null(strata_var)) final_df$亚组差异P值 <- ""
  }
  if (!is.null(strata_var)) {
    all_preds <- unique(final_df$预测变量)
    complete_grid <- expand.grid(预测变量 = all_preds, 亚组 = strata_vals, stringsAsFactors = FALSE)
    final_df <- dplyr::left_join(complete_grid, final_df, by = c("预测变量", "亚组"))
    final_df$预测变量原始 <- ifelse(is.na(final_df$预测变量原始), "", final_df$预测变量原始)
    final_df$N <- ifelse(is.na(final_df$N), "0", final_df$N)
    final_df$统计值 <- ifelse(is.na(final_df$统计值), "NA", final_df$统计值)
    final_df$P值 <- ifelse(is.na(final_df$P值), "NA", final_df$P值)
    if (!is.null(get_int_p_fn)) {
      final_df$亚组差异P值 <- ifelse(
        as.character(final_df$亚组) == as.character(strata_vals[1]) | !nzchar(final_df$预测变量原始),
        "",
        vapply(
          seq_len(nrow(final_df)),
          function(i) get_int_p_fn(int_p_map, final_df$预测变量原始[i], as.character(final_df$亚组[i]), "__ALL__"),
          character(1)
        )
      )
    } else {
      final_df$亚组差异P值 <- ""
    }
  }
  if ("列分组" %in% names(final_df)) {
    facet_n_map <- sapply(facet_levels_all, function(x) sum(as.character(df_in[[facet_var]]) == x, na.rm = TRUE), USE.NAMES = TRUE)
    vals_from <- if (!is.null(strata_var)) c("N", "统计值", "P值", "亚组差异P值") else c("N", "统计值", "P值")
    final_df <- tidyr::pivot_wider(final_df, names_from = 列分组, values_from = dplyr::all_of(vals_from), names_glue = "{列分组}__{.value}", values_fill = "NA")
    expected_cols <- if (!is.null(strata_var)) {
      as.vector(rbind(paste0(facet_levels_all, "__N"), paste0(facet_levels_all, "__统计值"), paste0(facet_levels_all, "__P值"), paste0(facet_levels_all, "__亚组差异P值")))
    } else {
      as.vector(rbind(paste0(facet_levels_all, "__N"), paste0(facet_levels_all, "__统计值"), paste0(facet_levels_all, "__P值")))
    }
    missing_cols <- setdiff(expected_cols, names(final_df))
    if (length(missing_cols) == length(expected_cols)) {
      stop("列分组结果展开失败：未生成任何预期列，请检查分组变量取值与模型输出。")
    }
    if (length(missing_cols) > 0) {
      for (mc in missing_cols) final_df[[mc]] <- if (grepl("__N$", mc)) "0" else "NA"
    }
    if (!is.null(strata_var)) {
      pdiff_cols <- grep("__亚组差异P值$", names(final_df), value = TRUE)
      for (pc in pdiff_cols) {
        final_df[[pc]] <- ifelse(as.character(final_df$亚组) == as.character(strata_vals[1]), "", as.character(final_df[[pc]]))
      }
    }
    final_df <- final_df[, c("预测变量", "亚组", expected_cols), drop = FALSE]
    label_map <- list(亚组 = "")
    spanner_map <- list()
    for (lv in facet_levels_all) {
      n_col <- paste0(lv, "__N")
      stat_col <- paste0(lv, "__统计值")
      p_col <- paste0(lv, "__P值")
      pd_col <- paste0(lv, "__亚组差异P值")
      label_map[[n_col]] <- "N"
      label_map[[stat_col]] <- metric_label
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
      final_df <- final_df[, c("预测变量", "亚组", "N", "统计值", "P值", "亚组差异P值"), drop = FALSE]
      label_map <- list(亚组 = "", N = "N", 统计值 = metric_label, P值 = "P值", 亚组差异P值 = "亚组差异P值")
    } else {
      final_df <- final_df[, c("预测变量", "亚组", "N", "统计值", "P值"), drop = FALSE]
      label_map <- list(亚组 = "", N = "N", 统计值 = metric_label, P值 = "P值")
    }
    spanner_map <- list()
  }
  if (!is.null(strata_var)) final_df$亚组 <- factor(as.character(final_df$亚组), levels = strata_vals)
  final_df <- final_df[order(final_df$预测变量, final_df$亚组), , drop = FALSE]
  final_df <- dplyr::group_by(final_df, 预测变量, 亚组)
  final_df <- dplyr::mutate(final_df, 亚组 = ifelse(dplyr::row_number() == 1, paste0("\u00A0\u00A0\u00A0\u00A0", 亚组), ""))
  final_df <- dplyr::ungroup(final_df)
  gt_tbl <- do.call(gt::cols_label, c(list(.data = gt::gt(final_df, groupname_col = "预测变量")), label_map))
  if (length(spanner_map) > 0) {
    for (sp in spanner_map) {
      gt_tbl <- gt::tab_spanner(gt_tbl, label = sp$label, columns = sp$columns)
    }
  }
  gt_tbl <- apply_style_fn(gt_tbl)
  attr(gt_tbl, "skipped_models") <- skipped_models
  gt_tbl
}
