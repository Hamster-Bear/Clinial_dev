ensure_stat_analysis_dependencies <- function() {
  resolve_module_path <- function(rel_path) {
    if (file.exists(rel_path)) return(rel_path)
    alt <- file.path("..", rel_path)
    if (file.exists(alt)) return(alt)
    rel_path
  }
  if (!exists("%>%", mode = "function")) {
    assign("%>%", dplyr::`%>%`, envir = .GlobalEnv)
  }
  if (!exists("apply_sci_gt_style", mode = "function") || !exists("format_p_value_ama", mode = "function")) {
    source(resolve_module_path("modules/common/table_export.R"))
  }
  if (!exists("format_p_value_regression", mode = "function") || !exists("build_repro_code_template", mode = "function")) {
    source(resolve_module_path("modules/common/analysis_format.R"))
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

prepare_predictor_reference_levels <- function(data, predictors, reference_map = NULL) {
  df <- data
  pred_is_cat <- rep(FALSE, length(predictors))
  names(pred_is_cat) <- predictors
  pred_ref_level <- rep(NA_character_, length(predictors))
  names(pred_ref_level) <- predictors
  if (is.null(reference_map)) reference_map <- character(0)
  for (v in predictors) {
    if (!v %in% names(df)) next
    is_cat <- is.factor(df[[v]]) || is.character(df[[v]]) || is.logical(df[[v]])
    pred_is_cat[[v]] <- is_cat
    if (!is_cat) next
    lv <- get_levels_all(df[[v]])
    lv <- lv[nzchar(as.character(lv))]
    if (length(lv) == 0) next
    selected_ref <- unname(reference_map[v])
    chosen_ref <- if (length(selected_ref) > 0 && !is.na(selected_ref) && as.character(selected_ref) %in% as.character(lv)) as.character(selected_ref) else as.character(lv[1])
    pred_ref_level[[v]] <- chosen_ref
    new_lv <- c(chosen_ref, setdiff(as.character(lv), chosen_ref))
    df[[v]] <- factor(as.character(df[[v]]), levels = new_lv)
  }
  list(data = df, pred_is_cat = pred_is_cat, pred_ref_level = pred_ref_level)
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
    dsub[[strata_nm]] <- factor(as.character(dsub[[strata_nm]]), levels = as.character(strata_levels))
    dsub[[strata_nm]] <- stats::relevel(dsub[[strata_nm]], ref = ref_level)
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
          if (length(idx) > 0) p_fmt <- format_p_value_ama(td$p.value[idx[1]])
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

#' 通用回归结果提取与后备方案
#' @param fit 拟合好的模型对象 (如 lm, glm, coxph)
#' @param conf.int 是否计算置信区间
#' @param exponentiate 是否对估计值及置信区间进行指数化(例如OR, HR)
#' @param facet_var 分组变量名，用于日志提示
#' @param sval 亚组值，用于日志提示
#' @param fval 分组值，用于日志提示
#' @param add_note_fn 写入日志的函数
extract_broom_tidy_with_fallback <- function(fit, conf.int = TRUE, exponentiate = FALSE,
                                             facet_var = NULL, sval = NULL, fval = NULL, add_note_fn = NULL) {
  # 辅助函数：格式化提示前缀
  get_msg_prefix <- function() {
    if (is.null(facet_var)) paste0("亚组[", sval, "]") else paste0("亚组[", sval, "]分组[", fval, "]")
  }

  # 1. 尝试使用 broom::tidy
  tid <- tryCatch(
    broom::tidy(fit, conf.int = conf.int, exponentiate = exponentiate),
    error = function(e) {
      if (!is.null(add_note_fn)) {
        add_note_fn(paste0(get_msg_prefix(), " 结果整理失败(broom::tidy): ", conditionMessage(e)))
      }
      NULL
    }
  )

  # 2. 如果 tidy 失败或为空，启动完全备选方案
  if (is.null(tid) || nrow(tid) == 0) {
    if (!is.null(add_note_fn)) {
      add_note_fn(paste0(get_msg_prefix(), " 启动备选结果提取方案(summary$coefficients)。"))
    }
    
    sm0 <- tryCatch(summary(fit)$coefficients, error = function(e) {
      if (!is.null(add_note_fn)) {
         add_note_fn(paste0(get_msg_prefix(), " 备选方案(summary)也失败: ", conditionMessage(e)))
      }
      NULL
    })
    
    if (!is.null(sm0) && is.matrix(sm0) && nrow(sm0) > 0) {
      tid <- data.frame(term = rownames(sm0), stringsAsFactors = FALSE)
      
      # 适配不同模型的 summary 列名
      est_col <- if ("Estimate" %in% colnames(sm0)) "Estimate" else if ("coef" %in% colnames(sm0)) "coef" else colnames(sm0)[1]
      se_col <- if ("Std. Error" %in% colnames(sm0)) "Std. Error" else if ("se(coef)" %in% colnames(sm0)) "se(coef)" else colnames(sm0)[2]
      p_col <- if ("Pr(>|z|)" %in% colnames(sm0)) "Pr(>|z|)" else if ("Pr(>|t|)" %in% colnames(sm0)) "Pr(>|t|)" else if ("p" %in% colnames(sm0)) "p" else colnames(sm0)[ncol(sm0)]
      
      est_val <- as.numeric(sm0[, est_col])
      se_val <- as.numeric(sm0[, se_col])
      p_val <- as.numeric(sm0[, p_col])
      
      tid$estimate <- if (exponentiate) exp(est_val) else est_val
      tid$conf.low <- NA_real_
      tid$conf.high <- NA_real_
      tid$p.value <- p_val
      
      if (conf.int) {
        # 默认使用 95% Wald CI
        ci_low <- est_val - 1.96 * se_val
        ci_high <- est_val + 1.96 * se_val
        tid$conf.low <- if (exponentiate) exp(ci_low) else ci_low
        tid$conf.high <- if (exponentiate) exp(ci_high) else ci_high
      }
    }
  }

  if (is.null(tid) || nrow(tid) == 0) return(NULL)

  # 3. 如果部分值存在 NA (如 profile likelihood CI 计算失败)，进行填补
  sm <- tryCatch(summary(fit)$coefficients, error = function(e) NULL)
  if (!is.null(sm) && is.matrix(sm)) {
    rn <- rownames(sm)
    idx <- match(as.character(tid$term), rn)
    
    est_col <- if ("Estimate" %in% colnames(sm)) "Estimate" else if ("coef" %in% colnames(sm)) "coef" else colnames(sm)[1]
    se_col <- if ("Std. Error" %in% colnames(sm)) "Std. Error" else if ("se(coef)" %in% colnames(sm)) "se(coef)" else colnames(sm)[2]
    p_col <- if ("Pr(>|z|)" %in% colnames(sm)) "Pr(>|z|)" else if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else if ("p" %in% colnames(sm)) "p" else colnames(sm)[ncol(sm)]
    
    est_beta <- suppressWarnings(as.numeric(sm[idx, est_col]))
    se_beta <- suppressWarnings(as.numeric(sm[idx, se_col]))
    p_wald <- suppressWarnings(as.numeric(sm[idx, p_col]))
    
    # 填补 estimate
    if (!"estimate" %in% names(tid)) tid$estimate <- if (exponentiate) exp(est_beta) else est_beta
    if ("estimate" %in% names(tid)) {
      bad_est <- is.na(tid$estimate) & !is.na(est_beta)
      if (any(bad_est)) tid$estimate[bad_est] <- if (exponentiate) exp(est_beta[bad_est]) else est_beta[bad_est]
    }
    
    # 填补 CI
    if (!"conf.low" %in% names(tid)) tid$conf.low <- NA_real_
    if (!"conf.high" %in% names(tid)) tid$conf.high <- NA_real_
    bad_ci <- (is.na(tid$conf.low) | is.na(tid$conf.high)) & !is.na(est_beta) & !is.na(se_beta)
    if (any(bad_ci)) {
      ci_low_calc <- est_beta[bad_ci] - 1.96 * se_beta[bad_ci]
      ci_high_calc <- est_beta[bad_ci] + 1.96 * se_beta[bad_ci]
      tid$conf.low[bad_ci] <- if (exponentiate) exp(ci_low_calc) else ci_low_calc
      tid$conf.high[bad_ci] <- if (exponentiate) exp(ci_high_calc) else ci_high_calc
    }
    
    # 填补 p.value
    if (!"p.value" %in% names(tid)) tid$p.value <- p_wald
    if ("p.value" %in% names(tid)) {
      bad_p <- is.na(tid$p.value) & !is.na(p_wald)
      if (any(bad_p)) tid$p.value[bad_p] <- p_wald[bad_p]
    }
  }

  # 4. 最终校验并提示不可稳定估计项
  if ((("p.value" %in% names(tid)) && any(is.na(tid$p.value))) || (("conf.low" %in% names(tid)) && any(is.na(tid$conf.low))) || (("conf.high" %in% names(tid)) && any(is.na(tid$conf.high)))) {
    if (!is.null(add_note_fn)) {
      add_note_fn(paste0(get_msg_prefix(), " 存在不可稳定估计项，部分统计量显示为NA。"))
    }
  }

  tid
}

compute_regression_context <- function(df_in, facet_var = NULL, total_cols_settings = list()) {
  facet_levels_all <- if (!is.null(facet_var)) {
    get_levels_all(df_in[[facet_var]])
  } else character(0)
  valid_total_settings <- list()
  if (!is.null(facet_var) && length(total_cols_settings) > 0) {
    for (i in seq_along(total_cols_settings)) {
      setting <- total_cols_settings[[i]]
      col_name <- if (!is.null(setting$name)) trimws(as.character(setting$name)) else ""
      if (nchar(col_name) == 0) col_name <- paste0("总计", i)
      groups <- if (!is.null(setting$groups)) intersect(as.character(setting$groups), facet_levels_all) else character(0)
      if (length(groups) > 0) {
        internal_name <- paste0(".__TOTAL__", i)
        valid_total_settings[[length(valid_total_settings) + 1]] <- list(
          internal_name = internal_name,
          display_name = col_name,
          groups = groups
        )
      }
    }
  }
  facet_values_to_run <- if (is.null(facet_var)) "__ALL__" else facet_levels_all
  if (length(valid_total_settings) > 0) {
    total_internal_names <- vapply(valid_total_settings, function(x) x$internal_name, character(1))
    facet_values_to_run <- c(facet_values_to_run, total_internal_names)
  }
  list(
    facet_levels_all = facet_levels_all,
    valid_total_settings = valid_total_settings,
    facet_values_to_run = facet_values_to_run
  )
}

compute_regression_rows <- function(
  df_in,
  predictors,
  response_var_name = NULL,
  strata_var = NULL,
  facet_var = NULL,
  strata_vals,
  facet_values_to_run,
  valid_total_settings,
  fit_tidy_fn,
  term_to_display_fn,
  predictor_key_fn,
  count_effective_n_fn,
  format_estimate_fn,
  format_p_fn,
  add_note_fn = NULL,
  categorical_ref_map = NULL
) {
  out_list <- list()
  skipped_models <- 0L
  for (sval in strata_vals) {
    strata_data <- if (is.null(strata_var)) df_in else df_in[df_in[[strata_var]] == sval, , drop = FALSE]
    if (nrow(strata_data) == 0) {
      if (!is.null(add_note_fn)) add_note_fn(paste0("亚组[", sval, "]无可用样本，已以占位形式展示。"))
      next
    }
    for (fval in facet_values_to_run) {
      if (is.null(facet_var)) {
        sub_data <- strata_data
      } else if (startsWith(fval, ".__TOTAL__")) {
        setting_idx <- match(fval, vapply(valid_total_settings, function(x) x$internal_name, character(1)))
        groups_to_include <- valid_total_settings[[setting_idx]]$groups
        sub_data <- strata_data[as.character(strata_data[[facet_var]]) %in% groups_to_include, , drop = FALSE]
      } else {
        sub_data <- strata_data[as.character(strata_data[[facet_var]]) == as.character(fval), , drop = FALSE]
      }
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
      tid$预测变量原始 <- vapply(tid$term, predictor_key_fn, character(1))
      tid$预测变量 <- paste0("\U00A0\U00A0\U00A0\U00A0", vapply(tid$term, term_to_display_fn, character(1)))
      tid$亚组 <- if (is.null(strata_var)) "总体" else as.character(sval)
      model_vars_in_sub <- unique(c(predictors, response_var_name))
      model_vars_in_sub <- model_vars_in_sub[model_vars_in_sub %in% names(sub_data)]
      cc_sub_data <- if (length(model_vars_in_sub) > 0) sub_data[stats::complete.cases(sub_data[, model_vars_in_sub, drop = FALSE]), , drop = FALSE] else sub_data
      tid_n_vals <- rep(as.character(count_effective_n_fn(sub_data)), nrow(tid))
      if (!is.null(categorical_ref_map) && length(categorical_ref_map) > 0) {
        for (i in seq_len(nrow(tid))) {
          v_raw <- tid$预测变量原始[i]
          if (v_raw %in% names(categorical_ref_map)) {
            term_str <- tid$term[i]
            aliases <- unique(c(v_raw, make.names(v_raw)))
            hit_alias <- aliases[startsWith(term_str, aliases)]
            if (length(hit_alias) > 0) {
              alias_used <- hit_alias[1]
              lvl <- substring(term_str, nchar(alias_used) + 1)
              level_n <- sum(as.character(cc_sub_data[[v_raw]]) == lvl, na.rm = TRUE)
              tid_n_vals[i] <- as.character(level_n)
            }
          }
        }
      }
      tid$N <- tid_n_vals
      tid$统计值 <- vapply(seq_len(nrow(tid)), function(i) format_estimate_fn(est[i], low[i], high[i]), character(1))
      tid$P值 <- vapply(pvals, function(p) {
        format_p_fn(p)
      }, character(1))
      tid$.__row_order <- 1L
      tid$.__row_key <- paste(tid$预测变量原始, tid$.__row_order, tid$预测变量, sep = "||")
      if (!is.null(facet_var)) tid$列分组 <- as.character(fval)
      if (!is.null(categorical_ref_map) && length(categorical_ref_map) > 0) {
        ref_rows <- list()
        for (cv in names(categorical_ref_map)) {
          idx_cv <- which(tid$预测变量原始 == cv)
          if (length(idx_cv) == 0) next
          ref_val <- as.character(categorical_ref_map[[cv]])
          if (!nzchar(ref_val)) next
          rr <- tid[idx_cv[1], , drop = FALSE]
          rr$预测变量 <- paste0("\U00A0\U00A0\U00A0\U00A0", ref_val, " (Reference)")
          rr$预测变量原始 <- cv
          ref_level_n <- sum(as.character(cc_sub_data[[cv]]) == ref_val, na.rm = TRUE)
          rr$N <- as.character(ref_level_n)
          rr$统计值 <- "Reference"
          rr$P值 <- ""
          rr$.__row_order <- 0L
          rr$.__row_key <- paste(rr$预测变量原始, rr$.__row_order, rr$预测变量, sep = "||")
          ref_rows[[length(ref_rows) + 1L]] <- rr
        }
        if (length(ref_rows) > 0) {
          tid <- dplyr::bind_rows(ref_rows, tid)
        }
      }
      keep_cols <- c("预测变量", "预测变量原始", "亚组", if (!is.null(facet_var)) "列分组", "N", "统计值", "P值", ".__row_order", ".__row_key")
      out_list[[length(out_list) + 1L]] <- tid[, keep_cols, drop = FALSE]
    }
  }
  if (length(out_list) == 0) {
    stop("所有子模型均未能稳定估计，请检查分层/分组设置、分类变量水平与模型复杂度。")
  }
  list(
    final_df = dplyr::bind_rows(out_list),
    skipped_models = skipped_models
  )
}

apply_regression_header_rows <- function(
  final_df,
  df_in,
  predictors,
  response_var_name = NULL,
  strata_var = NULL,
  facet_var = NULL,
  strata_vals,
  facet_values_to_run,
  valid_total_settings,
  count_effective_n_fn,
  categorical_ref_map = NULL
) {
  var_labels <- sapply(unique(final_df$预测变量原始), function(v) {
    lv <- attr(df_in[[v]], "label", exact = TRUE)
    if (is.null(lv) || !nzchar(trimws(as.character(lv)[1]))) v else trimws(as.character(lv)[1])
  }, USE.NAMES = TRUE)
  unique_strata <- if (is.null(strata_var)) "总体" else strata_vals
  unique_facets <- if (is.null(facet_var)) "__ALL__" else facet_values_to_run
  cat_vars <- if (!is.null(categorical_ref_map)) names(categorical_ref_map) else character(0)
  header_rows <- list()
  for (sval in unique_strata) {
    for (fval in unique_facets) {
      for (v_raw in unique(final_df$预测变量原始)) {
        if (!nzchar(v_raw)) next
        if (v_raw %in% cat_vars) {
          clean_var_name <- unname(var_labels[v_raw])
          if (is.null(clean_var_name) || is.na(clean_var_name)) clean_var_name <- v_raw
          hr <- data.frame(
            预测变量 = clean_var_name,
            预测变量原始 = v_raw,
            亚组 = sval,
            N = as.character(count_effective_n_fn(df_in)),
            统计值 = "",
            P值 = "",
            .__row_order = -1L,
            stringsAsFactors = FALSE
          )
          hr$.__row_key <- paste(hr$预测变量原始, hr$.__row_order, hr$预测变量, sep = "||")
          hr_sub_data <- if (is.null(strata_var)) df_in else df_in[df_in[[strata_var]] == sval, , drop = FALSE]
          if (!is.null(facet_var)) {
            if (startsWith(fval, ".__TOTAL__")) {
              setting_idx <- match(fval, vapply(valid_total_settings, function(x) x$internal_name, character(1)))
              groups_to_include <- valid_total_settings[[setting_idx]]$groups
              hr_sub_data <- hr_sub_data[as.character(hr_sub_data[[facet_var]]) %in% groups_to_include, , drop = FALSE]
            } else if (fval != "总体") {
              hr_sub_data <- hr_sub_data[as.character(hr_sub_data[[facet_var]]) == as.character(fval), , drop = FALSE]
            }
          }
          model_vars_in_sub <- unique(c(predictors, response_var_name))
          model_vars_in_sub <- model_vars_in_sub[model_vars_in_sub %in% names(hr_sub_data)]
          if (length(model_vars_in_sub) > 0) {
            hr_sub_data <- hr_sub_data[stats::complete.cases(hr_sub_data[, model_vars_in_sub, drop = FALSE]), , drop = FALSE]
          }
          hr$N <- as.character(sum(!is.na(hr_sub_data[[v_raw]])))
          if (!is.null(facet_var)) hr$列分组 <- fval
          header_rows[[length(header_rows) + 1L]] <- hr
        } else {
          if (!is.null(facet_var)) {
            idx_cont <- which(final_df$预测变量原始 == v_raw & final_df$亚组 == sval & final_df$列分组 == fval)
          } else {
            idx_cont <- which(final_df$预测变量原始 == v_raw & final_df$亚组 == sval)
          }
          if (length(idx_cont) > 0) {
            clean_var_name <- unname(var_labels[v_raw])
            if (is.null(clean_var_name) || is.na(clean_var_name)) clean_var_name <- v_raw
            final_df$预测变量[idx_cont] <- clean_var_name
            final_df$.__row_order[idx_cont] <- -1L
          }
        }
      }
    }
  }
  dplyr::bind_rows(final_df, dplyr::bind_rows(header_rows))
}

complete_regression_rows_grid <- function(final_df, strata_var = NULL, facet_var = NULL, strata_vals, facet_values_to_run) {
  row_map <- final_df[!is.na(final_df$.__row_key), c(".__row_key", "预测变量", "预测变量原始", ".__row_order"), drop = FALSE]
  row_map <- row_map[!duplicated(row_map$.__row_key), , drop = FALSE]
  all_row_keys <- unique(final_df$.__row_key)
  if (!is.null(strata_var)) {
    if (!is.null(facet_var)) {
      grid_list <- list(.__row_key = all_row_keys)
      grid_list$亚组 <- strata_vals
      grid_list$列分组 <- facet_values_to_run
      complete_grid <- do.call(expand.grid, c(grid_list, list(stringsAsFactors = FALSE)))
      final_df <- dplyr::left_join(complete_grid, final_df, by = names(grid_list))
    } else {
      grid_list <- list(.__row_key = all_row_keys)
      grid_list$亚组 <- strata_vals
      complete_grid <- do.call(expand.grid, c(grid_list, list(stringsAsFactors = FALSE)))
      final_df <- dplyr::left_join(complete_grid, final_df, by = names(grid_list))
    }
    final_df <- dplyr::left_join(final_df, row_map, by = ".__row_key", suffix = c("", ".map"))
    final_df$预测变量 <- dplyr::coalesce(final_df$预测变量, final_df$预测变量.map)
    final_df$预测变量原始 <- dplyr::coalesce(final_df$预测变量原始, final_df$预测变量原始.map)
    final_df$.__row_order <- dplyr::coalesce(final_df$.__row_order, final_df$.__row_order.map)
    final_df$预测变量.map <- NULL
    final_df$预测变量原始.map <- NULL
    final_df$.__row_order.map <- NULL
    final_df$N <- ifelse(is.na(final_df$N), "", final_df$N)
    final_df$统计值 <- ifelse(is.na(final_df$统计值), "", final_df$统计值)
    final_df$P值 <- ifelse(is.na(final_df$P值), "", final_df$P值)
  } else if (!is.null(facet_var)) {
    grid_list <- list(.__row_key = all_row_keys)
    grid_list$列分组 <- facet_values_to_run
    complete_grid <- do.call(expand.grid, c(grid_list, list(stringsAsFactors = FALSE)))
    final_df <- dplyr::left_join(complete_grid, final_df, by = names(grid_list))
    final_df <- dplyr::left_join(final_df, row_map, by = ".__row_key", suffix = c("", ".map"))
    final_df$预测变量 <- dplyr::coalesce(final_df$预测变量, final_df$预测变量.map)
    final_df$预测变量原始 <- dplyr::coalesce(final_df$预测变量原始, final_df$预测变量原始.map)
    final_df$.__row_order <- dplyr::coalesce(final_df$.__row_order, final_df$.__row_order.map)
    final_df$预测变量.map <- NULL
    final_df$预测变量原始.map <- NULL
    final_df$.__row_order.map <- NULL
    final_df$亚组 <- "总体"
    final_df$N <- ifelse(is.na(final_df$N), "", final_df$N)
    final_df$统计值 <- ifelse(is.na(final_df$统计值), "", final_df$统计值)
    final_df$P值 <- ifelse(is.na(final_df$P值), "", final_df$P值)
  }
  final_df$预测变量原始 <- ifelse(is.na(final_df$预测变量原始), "", final_df$预测变量原始)
  final_df$.__row_order <- ifelse(is.na(final_df$.__row_order), 1L, final_df$.__row_order)
  final_df$预测变量 <- ifelse(is.na(final_df$预测变量), final_df$预测变量原始, final_df$预测变量)
  final_df
}

apply_interaction_p_values <- function(final_df, strata_var = NULL, facet_var = NULL, strata_vals, get_int_p_fn = NULL, int_p_map = character(0)) {
  if (is.null(strata_var) || is.null(get_int_p_fn)) return(final_df)
  if (!is.null(facet_var)) {
    final_df$亚组差异P值 <- ""
    ref_level <- as.character(strata_vals[1])
    non_ref_levels <- as.character(strata_vals[as.character(strata_vals) != ref_level])
    p_level <- if (length(non_ref_levels) > 0) non_ref_levels[1] else ref_level
    facet_tags <- if ("列分组" %in% names(final_df)) unique(as.character(final_df$列分组)) else "__ALL__"
    for (facet_tag in facet_tags) {
      for (v_raw in unique(final_df$预测变量原始)) {
        if (!nzchar(v_raw)) next
        idx_base <- final_df$预测变量原始 == v_raw & as.character(final_df$亚组) == p_level
        if ("列分组" %in% names(final_df)) {
          idx_base <- idx_base & as.character(final_df$列分组) == facet_tag
        }
        idx_title <- which(idx_base & final_df$.__row_order == -1L)
        if (length(idx_title) == 0L) {
          idx_fallback <- which(idx_base)
          if (length(idx_fallback) > 0L) idx_title <- idx_fallback[1]
        }
        if (length(idx_title) > 0L) {
          pval <- get_int_p_fn(int_p_map, v_raw, p_level, facet_tag)
          final_df$亚组差异P值[idx_title[1]] <- pval
        }
      }
    }
  } else {
    int_rows <- list()
    ref_level <- as.character(strata_vals[1])
    non_ref_levels <- as.character(strata_vals[as.character(strata_vals) != ref_level])
    p_level <- if (length(non_ref_levels) > 0) non_ref_levels[1] else ref_level
    for (v_raw in unique(final_df$预测变量原始)) {
      if (!nzchar(v_raw)) next
      pval <- get_int_p_fn(int_p_map, v_raw, p_level, "__ALL__")
      if (nzchar(pval) && pval != "NA") {
        ir <- data.frame(
          预测变量 = paste0("\U00A0\U00A0*P for interaction*"),
          预测变量原始 = v_raw,
          亚组 = as.character(strata_vals[length(strata_vals)]),
          N = "",
          统计值 = "",
          P值 = paste0("*", pval, "*"),
          .__row_order = 999L,
          stringsAsFactors = FALSE
        )
        int_rows[[length(int_rows) + 1L]] <- ir
      }
    }
    if (length(int_rows) > 0) {
      final_df <- dplyr::bind_rows(final_df, dplyr::bind_rows(int_rows))
    }
  }
  final_df
}

compute_regression_columns <- function(final_df, df_in, facet_var = NULL, facet_levels_all, valid_total_settings, count_effective_n_fn, metric_label) {
  if ("列分组" %in% names(final_df)) {
    facet_n_map <- sapply(facet_levels_all, function(x) {
      df_lv <- df_in[as.character(df_in[[facet_var]]) == as.character(x), , drop = FALSE]
      count_effective_n_fn(df_lv)
    }, USE.NAMES = TRUE)
    if (length(valid_total_settings) > 0) {
      for (setting in valid_total_settings) {
        facet_n_map[[setting$internal_name]] <- count_effective_n_fn(df_in[as.character(df_in[[facet_var]]) %in% setting$groups, , drop = FALSE])
      }
    }
    vals_from <- if ("亚组差异P值" %in% names(final_df)) c("N", "统计值", "P值", "亚组差异P值") else c("N", "统计值", "P值")
    final_df <- tidyr::pivot_wider(final_df, names_from = 列分组, values_from = dplyr::all_of(vals_from), names_glue = "{列分组}__{.value}", values_fill = "")
    expected_cols <- character(0)
    display_facet_levels <- facet_levels_all
    if (length(valid_total_settings) > 0) {
      display_facet_levels <- c(display_facet_levels, vapply(valid_total_settings, function(x) x$internal_name, character(1)))
    }
    for (lv in display_facet_levels) {
      expected_cols <- c(expected_cols, paste0(lv, "__N"), paste0(lv, "__统计值"), paste0(lv, "__P值"))
      if ("亚组差异P值" %in% names(final_df) || paste0(lv, "__亚组差异P值") %in% names(final_df)) {
        expected_cols <- c(expected_cols, paste0(lv, "__亚组差异P值"))
      }
    }
    missing_cols <- setdiff(expected_cols, names(final_df))
    if (length(missing_cols) > 0) {
      for (mc in missing_cols) final_df[[mc]] <- ""
    }
    final_df <- final_df[, c("预测变量", "预测变量原始", ".__row_order", "亚组", expected_cols), drop = FALSE]
    label_map <- list(亚组 = "亚组")
    spanner_map <- list()
    for (lv in display_facet_levels) {
      n_col <- paste0(lv, "__N")
      stat_col <- paste0(lv, "__统计值")
      p_col <- paste0(lv, "__P值")
      pd_col <- paste0(lv, "__亚组差异P值")
      label_map[[n_col]] <- "n"
      label_map[[stat_col]] <- metric_label
      label_map[[p_col]] <- "P值"
      cols_for_spanner <- c(n_col, stat_col, p_col)
      if (pd_col %in% names(final_df)) {
        if (lv == display_facet_levels[1]) {
          label_map[[pd_col]] <- "P for interaction"
          cols_for_spanner <- c(cols_for_spanner, pd_col)
        } else {
          final_df[[pd_col]] <- NULL
        }
      }
      if (startsWith(lv, ".__TOTAL__")) {
        setting_idx <- match(lv, vapply(valid_total_settings, function(x) x$internal_name, character(1)))
        lv_text <- valid_total_settings[[setting_idx]]$display_name
      } else if (grepl("组$", lv)) {
        lv_text <- lv
      } else {
        lv_text <- paste0(lv, "组")
      }
      n_val_disp <- if (lv %in% names(facet_n_map)) facet_n_map[[lv]] else ""
      spanner_map[[lv]] <- list(
        label = gt::md(paste0(lv_text, "<br><span style='font-weight:normal'>(N = ", n_val_disp, ")</span>")),
        columns = cols_for_spanner
      )
    }
  } else {
    keep_cols <- c("预测变量", "预测变量原始", ".__row_order", "亚组", "N", "统计值", "P值")
    final_df <- final_df[, keep_cols, drop = FALSE]
    label_map <- list(亚组 = "亚组", N = "n", 统计值 = metric_label, P值 = "P值")
    spanner_map <- list()
  }
  list(final_df = final_df, label_map = label_map, spanner_map = spanner_map)
}

finalize_regression_display <- function(final_df, label_map, strata_var = NULL, strata_vals, df_in) {
  if (!is.null(strata_var)) {
    final_df$亚组 <- factor(as.character(final_df$亚组), levels = strata_vals)
  }
  final_df <- final_df[order(final_df$亚组, final_df$预测变量原始, final_df$.__row_order), , drop = FALSE]
  if (!is.null(strata_var)) {
    strata_label <- attr(df_in[[strata_var]], "label", exact = TRUE)
    if (is.null(strata_label) || !nzchar(trimws(as.character(strata_label)[1]))) {
      strata_label <- strata_var
    } else {
      strata_label <- trimws(as.character(strata_label)[1])
    }
    first_occurrences <- !duplicated(final_df$亚组)
    final_df$亚组_disp <- paste0("\U00A0\U00A0\U00A0\U00A0", as.character(final_df$亚组))
    final_df$亚组_disp[!first_occurrences] <- ""
    final_df$亚组 <- NULL
    names(final_df)[names(final_df) == "亚组_disp"] <- "亚组"
    if (nrow(final_df) > 0) {
      strata_title_row <- final_df[1, , drop = FALSE]
      for (col in names(strata_title_row)) {
        if (is.numeric(strata_title_row[[col]])) {
          strata_title_row[[col]] <- NA_real_
        } else if (is.integer(strata_title_row[[col]])) {
          strata_title_row[[col]] <- NA_integer_
        } else {
          strata_title_row[[col]] <- ""
        }
      }
      strata_title_row$亚组 <- strata_label
      final_df <- dplyr::bind_rows(strata_title_row, final_df)
    }
    label_map[["亚组"]] <- "亚组"
    cols <- names(final_df)
    cols <- c("亚组", setdiff(cols, "亚组"))
    final_df <- final_df[, cols]
  } else {
    final_df$亚组 <- NULL
    label_map$亚组 <- NULL
  }
  final_df$预测变量原始 <- NULL
  final_df$.__row_order <- NULL
  list(final_df = final_df, label_map = label_map)
}

compute_regression_stats <- function(
  df_in,
  predictors,
  response_var_name = NULL, # 新增参数，用于过滤 complete.cases
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
  add_note_fn = NULL,
  int_p_map = character(0),
  get_int_p_fn = NULL,
  categorical_ref_map = NULL,
  total_cols_settings = list()
) {
  ctx <- compute_regression_context(
    df_in = df_in,
    facet_var = facet_var,
    total_cols_settings = total_cols_settings
  )
  facet_levels_all <- ctx$facet_levels_all
  valid_total_settings <- ctx$valid_total_settings
  facet_values_to_run <- ctx$facet_values_to_run
  rows_res <- compute_regression_rows(
    df_in = df_in,
    predictors = predictors,
    response_var_name = response_var_name,
    strata_var = strata_var,
    facet_var = facet_var,
    strata_vals = strata_vals,
    facet_values_to_run = facet_values_to_run,
    valid_total_settings = valid_total_settings,
    fit_tidy_fn = fit_tidy_fn,
    term_to_display_fn = term_to_display_fn,
    predictor_key_fn = predictor_key_fn,
    count_effective_n_fn = count_effective_n_fn,
    format_estimate_fn = format_estimate_fn,
    format_p_fn = format_p_fn,
    add_note_fn = add_note_fn,
    categorical_ref_map = categorical_ref_map
  )
  final_df <- rows_res$final_df
  skipped_models <- rows_res$skipped_models
  
  final_df <- apply_regression_header_rows(
    final_df = final_df,
    df_in = df_in,
    predictors = predictors,
    response_var_name = response_var_name,
    strata_var = strata_var,
    facet_var = facet_var,
    strata_vals = strata_vals,
    facet_values_to_run = facet_values_to_run,
    valid_total_settings = valid_total_settings,
    count_effective_n_fn = count_effective_n_fn,
    categorical_ref_map = categorical_ref_map
  )
  
  final_df <- complete_regression_rows_grid(
    final_df = final_df,
    strata_var = strata_var,
    facet_var = facet_var,
    strata_vals = strata_vals,
    facet_values_to_run = facet_values_to_run
  )

  final_df <- apply_interaction_p_values(
    final_df = final_df,
    strata_var = strata_var,
    facet_var = facet_var,
    strata_vals = strata_vals,
    get_int_p_fn = get_int_p_fn,
    int_p_map = int_p_map
  )

  column_res <- compute_regression_columns(
    final_df = final_df,
    df_in = df_in,
    facet_var = facet_var,
    facet_levels_all = facet_levels_all,
    valid_total_settings = valid_total_settings,
    count_effective_n_fn = count_effective_n_fn,
    metric_label = metric_label
  )
  final_df <- column_res$final_df
  label_map <- column_res$label_map
  spanner_map <- column_res$spanner_map
  final_res <- finalize_regression_display(
    final_df = final_df,
    label_map = label_map,
    strata_var = strata_var,
    strata_vals = strata_vals,
    df_in = df_in
  )
  final_df <- final_res$final_df
  label_map <- final_res$label_map
  
  md_cols <- grep("P值$", names(final_df), value = TRUE)
  list(
    final_df = final_df,
    label_map = label_map,
    spanner_map = spanner_map,
    md_cols = md_cols,
    skipped_models = skipped_models
  )
}

render_clinical_table <- function(stats_payload, apply_style_fn) {
  final_df <- stats_payload$final_df
  label_map <- stats_payload$label_map
  spanner_map <- stats_payload$spanner_map
  md_cols <- stats_payload$md_cols
  skipped_models <- stats_payload$skipped_models
  gt_tbl <- gt::gt(final_df)
  gt_tbl <- do.call(gt::cols_label, c(list(.data = gt_tbl), label_map))
  if (length(spanner_map) > 0) {
    for (sp in spanner_map) {
      gt_tbl <- gt::tab_spanner(gt_tbl, label = sp$label, columns = sp$columns)
    }
  }
  gt_tbl <- apply_style_fn(gt_tbl)
  attr(gt_tbl, "skipped_models") <- skipped_models
  gt_tbl
}

build_unified_regression_table <- function(
  df_in,
  predictors,
  response_var_name = NULL,
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
  get_int_p_fn = NULL,
  categorical_ref_map = NULL,
  total_cols_settings = list()
) {
  stats_payload <- compute_regression_stats(
    df_in = df_in,
    predictors = predictors,
    response_var_name = response_var_name,
    strata_var = strata_var,
    facet_var = facet_var,
    strata_vals = strata_vals,
    metric_label = metric_label,
    fit_tidy_fn = fit_tidy_fn,
    term_to_display_fn = term_to_display_fn,
    predictor_key_fn = predictor_key_fn,
    count_effective_n_fn = count_effective_n_fn,
    format_estimate_fn = format_estimate_fn,
    format_p_fn = format_p_fn,
    add_note_fn = add_note_fn,
    int_p_map = int_p_map,
    get_int_p_fn = get_int_p_fn,
    categorical_ref_map = categorical_ref_map,
    total_cols_settings = total_cols_settings
  )
  render_clinical_table(stats_payload = stats_payload, apply_style_fn = apply_style_fn)
}

# -------------------------------------------------------------------------
# 公共 UI/Server 逻辑抽象
# -------------------------------------------------------------------------

# 统一的自定义总计列 UI 生成器
render_regression_total_cols_ui <- function(ns, ns_prefix, facet_var_id, input_data, input_list) {
  facet_var <- input_list[[facet_var_id]]
  if (is.null(facet_var) || facet_var == "None" || facet_var == "无") return(NULL)
  
  levels_choices <- unique(as.character(input_data[[facet_var]]))
  levels_choices <- levels_choices[!is.na(levels_choices)]
  
  ui_elements <- list(
    shiny::tags$div(
      class = "total-cols-controls",
      style = "margin-bottom: 15px;",
      shiny::tags$label("自定义总计列 (Total Columns)", class = "control-label"),
      shiny::tags$br(),
      shiny::actionButton(ns(paste0("add_total_col_", ns_prefix)), "添加列", icon = shiny::icon("plus"), class = "btn-sm btn-primary"),
      shiny::actionButton(ns(paste0("remove_total_col_", ns_prefix)), "移除列", icon = shiny::icon("minus"), class = "btn-sm btn-danger")
    )
  )
  
  # 此处不能直接使用 reactiveVal，我们需要依赖调用方传入当前的 count_val
  count_val_id <- paste0("total_cols_count_", ns_prefix)
  count_val <- if (!is.null(input_list[[count_val_id]])) input_list[[count_val_id]] else 0
  
  # 为了在模块化中保持状态，我们将使用更直接的参数传递
  # 见下方的修改版本
}

# 生成回归参数的总计列设置提取
get_regression_total_cols_settings <- function(input_list, ns_prefix, count_val) {
  settings <- list()
  if (count_val > 0) {
    for (i in 1:count_val) {
      name_val <- input_list[[paste0("total_name_", ns_prefix, "_", i)]]
      groups_val <- input_list[[paste0("total_groups_", ns_prefix, "_", i)]]
      if (!is.null(groups_val) && length(groups_val) > 0) {
        settings[[length(settings) + 1]] <- list(name = name_val, groups = groups_val)
      }
    }
  }
  settings
}

# UI 生成器 (重构版本)
generate_total_cols_ui <- function(ns, ns_prefix, facet_var, data, count_val) {
  if (is.null(facet_var) || facet_var == "None" || facet_var == "无") return(NULL)
  
  levels_choices <- unique(as.character(data[[facet_var]]))
  levels_choices <- levels_choices[!is.na(levels_choices)]
  
  ui_elements <- list(
    shiny::tags$div(
      class = "total-cols-controls",
      style = "margin-bottom: 15px;",
      shiny::tags$label("自定义总计列 (Total Columns)", class = "control-label"),
      shiny::tags$br(),
      shiny::actionButton(ns(paste0("add_total_col_", ns_prefix)), "添加列", icon = shiny::icon("plus"), class = "btn-sm btn-primary"),
      shiny::actionButton(ns(paste0("remove_total_col_", ns_prefix)), "移除列", icon = shiny::icon("minus"), class = "btn-sm btn-danger")
    )
  )
  
  if (count_val > 0) {
    for (i in 1:count_val) {
      ui_elements[[length(ui_elements) + 1]] <- shiny::wellPanel(
        style = "padding: 10px; margin-bottom: 10px; background-color: #f8f9fa;",
        shiny::textInput(ns(paste0("total_name_", ns_prefix, "_", i)), paste("列", i, "名称 (例如: 所有给药组)"), value = paste("自定义总计", i)),
        shiny::selectInput(ns(paste0("total_groups_", ns_prefix, "_", i)), paste("包含的分组 (属于", facet_var, ")"), 
                    choices = levels_choices, multiple = TRUE, selectize = TRUE)
      )
    }
  }
  shiny::tagList(ui_elements)
}
