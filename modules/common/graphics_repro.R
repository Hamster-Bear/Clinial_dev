graphics_quote_value <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return("NULL")
  val <- as.character(x[[1]])
  if (!nzchar(trimws(val)) || identical(val, "None") || identical(val, "无")) return("NULL")
  paste0("\"", gsub("\"", "\\\\\"", val), "\"")
}

graphics_quote_vector <- function(x) {
  if (is.null(x) || length(x) == 0) return("character(0)")
  vals <- as.character(x)
  vals <- vals[!is.na(vals) & nzchar(trimws(vals))]
  if (length(vals) == 0) return("character(0)")
  paste0("c(", paste(sprintf("\"%s\"", gsub("\"", "\\\\\"", vals)), collapse = ", "), ")")
}

generate_graphics_repro_code <- function(fig_type, state = list(), data_name = "data") {
  state <- if (is.list(state)) state else list()
  figure_label <- switch(
    fig_type,
    "km" = "生存曲线 (Kaplan-Meier)",
    "boxplot" = "箱线图",
    "forest" = "森林图",
    "heatmap" = "热图",
    "correlation" = "相关性矩阵",
    "combo" = "组合图形",
    "waterfall" = "瀑布图",
    "swimmer" = "泳道图",
    "spider" = "蜘蛛图",
    "图形分析"
  )
  base_steps <- list(
    list(
      title = "Load packages",
      lines = c("library(ggplot2)", "library(dplyr)")
    ),
    list(
      title = "Prepare analysis data",
      lines = c(
        paste0("data <- ", data_name),
        "stopifnot(is.data.frame(data))"
      )
    )
  )
  specific_steps <- switch(
    fig_type,
    "km" = list(
      list(
        title = "Set Kaplan-Meier parameters",
        lines = c(
          paste0("time_var <- ", graphics_quote_value(state$time_var)),
          paste0("status_var <- ", graphics_quote_value(state$status_var)),
          paste0("km_censor_value <- ", graphics_quote_value(state$km_censor_value)),
          paste0("strata_var <- ", graphics_quote_value(state$strata_var)),
          paste0("facet_var <- ", graphics_quote_value(state$facet_var)),
          paste0("facet_value <- ", graphics_quote_value(state$facet_value))
        )
      ),
      list(
        title = "Run Kaplan-Meier model (same as UI pipeline)",
        lines = c(
          "library(survival)",
          "library(survminer)",
          "df <- data",
          "if (!is.null(facet_var) && !is.null(facet_value) && facet_var %in% names(df)) {",
          "  df <- df[as.character(df[[facet_var]]) == as.character(facet_value), , drop = FALSE]",
          "}",
          "time_vec <- df[[time_var]]",
          "status_vec <- df[[status_var]]",
          "if (!is.null(km_censor_value) && km_censor_value == \"1\") {",
          "  status_vec <- ifelse(status_vec == 1, 0, ifelse(status_vec == 0, 1, status_vec))",
          "}",
          "valid_status <- unique(status_vec[!is.na(status_vec)])",
          "if (length(valid_status) > 0 && !all(valid_status %in% c(0, 1))) {",
          "  min_status <- min(valid_status, na.rm = TRUE)",
          "  status_vec <- ifelse(status_vec == min_status, 0, 1)",
          "}",
          "surv_obj <- survival::Surv(time_vec, status_vec)",
          "formula_terms <- if (is.null(strata_var)) \"1\" else strata_var",
          "km_formula <- as.formula(paste(\"surv_obj ~\", formula_terms))",
          "fit <- survminer::surv_fit(km_formula, data = df)",
          "extract_median_ci <- function(fit_obj) {",
          "  tbl <- summary(fit_obj)$table",
          "  if (is.null(dim(tbl))) {",
          "    tbl <- t(as.matrix(tbl))",
          "    rownames(tbl) <- \"all\"",
          "  } else {",
          "    tbl <- as.matrix(tbl)",
          "  }",
          "  cn <- colnames(tbl)",
          "  med_col <- if (\"median\" %in% cn) \"median\" else grep(\"median\", cn, ignore.case = TRUE, value = TRUE)[1]",
          "  low_col <- if (\"0.95LCL\" %in% cn) \"0.95LCL\" else grep(\"LCL|lower\", cn, ignore.case = TRUE, value = TRUE)[1]",
          "  up_col <- if (\"0.95UCL\" %in% cn) \"0.95UCL\" else grep(\"UCL|upper\", cn, ignore.case = TRUE, value = TRUE)[1]",
          "  data.frame(",
          "    strata = rownames(tbl),",
          "    median = as.numeric(tbl[, med_col]),",
          "    lower = as.numeric(tbl[, low_col]),",
          "    upper = as.numeric(tbl[, up_col]),",
          "    stringsAsFactors = FALSE",
          "  )",
          "}",
          "median_df <- extract_median_ci(fit)",
          "print(median_df)",
          "p <- survminer::ggsurvplot(fit, data = df, risk.table = TRUE)",
          "print(p$plot)"
        )
      )
    ),
    "boxplot" = list(
      list(
        title = "Set boxplot parameters",
        lines = c(
          paste0("x_var <- ", graphics_quote_value(state$x_var)),
          paste0("y_var <- ", graphics_quote_value(state$y_var))
        )
      ),
      list(
        title = "Draw boxplot",
        lines = c(
          "p <- ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]])) +",
          "  geom_boxplot(fill = \"lightblue\", alpha = 0.7) +",
          "  theme_minimal()",
          "print(p)"
        )
      )
    ),
    "forest" = list(
      list(
        title = "Set forest plot parameters",
        lines = c(
          paste0("subgroup_col <- ", graphics_quote_value(state$subgroup_col)),
          paste0("study_col <- ", graphics_quote_value(state$study_col)),
          paste0("estimate_col <- ", graphics_quote_value(state$estimate_col)),
          paste0("lower_col <- ", graphics_quote_value(state$lower_col)),
          paste0("upper_col <- ", graphics_quote_value(state$upper_col))
        )
      ),
      list(
        title = "Prepare forest plot data",
        lines = c(
          "forest_df <- data %>%",
          "  dplyr::select(dplyr::all_of(c(subgroup_col, study_col, estimate_col, lower_col, upper_col))) %>%",
          "  dplyr::rename_with(~ c(\"Subgroup\", \"Study\", \"Estimate\", \"Lower\", \"Upper\"))",
          "print(head(forest_df))"
        )
      )
    ),
    "heatmap" = list(
      list(
        title = "Set heatmap parameters",
        lines = c(
          paste0("selected_vars <- ", graphics_quote_vector(state$selected_vars)),
          paste0("cluster_method <- ", graphics_quote_value(state$clustering))
        )
      ),
      list(
        title = "Draw heatmap",
        lines = c(
          "mat <- stats::cor(data[, selected_vars, drop = FALSE], use = \"pairwise.complete.obs\")",
          "library(pheatmap)",
          "pheatmap::pheatmap(mat, clustering_method = if (is.null(cluster_method)) \"complete\" else gsub('^\"|\"$', '', cluster_method))"
        )
      )
    ),
    "correlation" = list(
      list(
        title = "Set correlation parameters",
        lines = c(
          paste0("selected_vars <- ", graphics_quote_vector(state$selected_vars)),
          paste0("corr_method <- ", graphics_quote_value(state$method))
        )
      ),
      list(
        title = "Run correlation analysis",
        lines = c(
          "corr_mat <- stats::cor(data[, selected_vars, drop = FALSE], use = \"pairwise.complete.obs\", method = if (is.null(corr_method)) \"pearson\" else gsub('^\"|\"$', '', corr_method))",
          "corr_df <- as.data.frame(as.table(corr_mat))",
          "names(corr_df) <- c(\"Var1\", \"Var2\", \"Correlation\")",
          "print(head(corr_df))"
        )
      )
    ),
    "combo" = list(
      list(
        title = "Set combo plot parameters",
        lines = c(
          paste0("plot_types <- ", graphics_quote_vector(state$plot_types)),
          paste0("combine_method <- ", graphics_quote_value(state$method))
        )
      ),
      list(
        title = "Compose plot workflow",
        lines = c(
          "library(cowplot)",
          "plot_list <- list()",
          "for (tp in plot_types) {",
          "  if (tp == \"scatter\") plot_list[[length(plot_list) + 1L]] <- ggplot(data, aes(1, 1)) + geom_point()",
          "  if (tp == \"line\") plot_list[[length(plot_list) + 1L]] <- ggplot(data, aes(1, 1)) + geom_line()",
          "  if (tp == \"bar\") plot_list[[length(plot_list) + 1L]] <- ggplot(data, aes(1, 1)) + geom_col()",
          "}",
          "print(cowplot::plot_grid(plotlist = plot_list, nrow = if (identical(combine_method, \"side_by_side\")) 1 else length(plot_list)))"
        )
      )
    ),
    "waterfall" = list(
      list(
        title = "Set waterfall parameters",
        lines = c(
          paste0("subject_id <- ", graphics_quote_value(state$subject_id)),
          paste0("value_var <- ", graphics_quote_value(state$value_var)),
          paste0("color_by <- ", graphics_quote_value(state$color_by)),
          paste0("track_vars <- ", graphics_quote_vector(state$tracks))
        )
      ),
      list(
        title = "Draw waterfall plot",
        lines = c(
          "wf_df <- data %>% dplyr::arrange(.data[[value_var]])",
          "wf_df$.order <- seq_len(nrow(wf_df))",
          "p <- ggplot(wf_df, aes(x = .data$.order, y = .data[[value_var]], fill = if (is.null(color_by)) NULL else .data[[gsub('^\"|\"$', '', color_by)]])) +",
          "  geom_col() +",
          "  theme_minimal()",
          "print(p)"
        )
      )
    ),
    "swimmer" = list(
      list(
        title = "Set swimmer parameters",
        lines = c(
          paste0("subject_id <- ", graphics_quote_value(state$subject_id)),
          paste0("start_time <- ", graphics_quote_value(state$start_time)),
          paste0("end_time <- ", graphics_quote_value(state$end_time)),
          paste0("event_time <- ", graphics_quote_value(state$event_time)),
          paste0("event_type <- ", graphics_quote_value(state$event_type)),
          paste0("track_vars <- ", graphics_quote_vector(state$tracks))
        )
      ),
      list(
        title = "Draw swimmer plot",
        lines = c(
          "lane_df <- data %>% dplyr::arrange(.data[[subject_id]])",
          "lane_df$.lane <- seq_len(nrow(lane_df))",
          "p <- ggplot(lane_df) +",
          "  geom_segment(aes(y = .data$.lane, yend = .data$.lane, x = .data[[start_time]], xend = .data[[end_time]]), linewidth = 5, lineend = \"round\") +",
          "  theme_minimal()",
          "print(p)"
        )
      )
    ),
    "spider" = list(
      list(
        title = "Set spider plot parameters",
        lines = c(
          paste0("subject_id <- ", graphics_quote_value(state$subject_id)),
          paste0("time_var <- ", graphics_quote_value(state$time_var)),
          paste0("value_var <- ", graphics_quote_value(state$value_var)),
          paste0("line_color_by <- ", graphics_quote_value(state$line_color_by)),
          paste0("facet_var <- ", graphics_quote_value(state$facet_var))
        )
      ),
      list(
        title = "Draw spider plot",
        lines = c(
          "sp_df <- data %>% dplyr::arrange(.data[[subject_id]], .data[[time_var]])",
          "p <- ggplot(sp_df, aes(x = .data[[time_var]], y = .data[[value_var]], group = .data[[subject_id]], color = if (!is.null(line_color_by)) .data[[gsub('^\"|\"$', '', line_color_by)]] else NULL)) +",
          "  geom_line(alpha = 0.8) +",
          "  theme_minimal()",
          "print(p)"
        )
      )
    ),
    list(
      list(
        title = "Inspect selected figure",
        lines = c(
          paste0("figure_type <- ", graphics_quote_value(fig_type)),
          "str(data)"
        )
      )
    )
  )
  footer_steps <- list(
    list(
      title = "Output",
      lines = c(
        paste0("message(\"Reproducible code generated for: ", figure_label, "\")")
      )
    )
  )
  build_repro_code_template(c(base_steps, specific_steps, footer_steps))
}
