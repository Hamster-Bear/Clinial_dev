if (!exists("build_repro_code_template", mode = "function")) {
  if (file.exists("modules/common/analysis/analysis_format.R")) {
    source("modules/common/analysis/analysis_format.R")
  } else {
    source(file.path("..", "modules", "common", "analysis", "analysis_format.R"))
  }
}

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

graphics_quote_bool <- function(x) {
  if (isTRUE(x)) "TRUE" else "FALSE"
}

graphics_quote_bool_default <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0) {
    return(if (isTRUE(default)) "TRUE" else "FALSE")
  }
  graphics_quote_bool(x)
}

graphics_quote_number <- function(x, default) {
  if (is.null(x) || length(x) == 0) return(format(default, scientific = FALSE, trim = TRUE))
  value <- suppressWarnings(as.numeric(x[[1]]))
  if (is.na(value) || !is.finite(value)) value <- default
  format(value, scientific = FALSE, trim = TRUE)
}

graphics_quote_value_default <- function(x, default) {
  quoted <- graphics_quote_value(x)
  if (identical(quoted, "NULL")) {
    return(graphics_quote_value(default))
  }
  quoted
}

graphics_first_non_null <- function(...) {
  values <- list(...)
  for (value in values) {
    if (!is.null(value)) return(value)
  }
  NULL
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
          "fit <- survminer::surv_fit(km_formula, data = df, conf.type = \"log-log\")",
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
          paste0("y_var <- ", graphics_quote_value(state$y_var)),
          paste0("plot_title <- ", graphics_quote_value(state$plot_title)),
          paste0("plot_xlab <- ", graphics_quote_value(state$plot_xlab)),
          paste0("plot_ylab <- ", graphics_quote_value(state$plot_ylab)),
          paste0("plot_palette <- ", graphics_quote_value_default(state$plot_palette, "lancet")),
          paste0("line_size <- ", graphics_quote_number(state$line_size, 0.6)),
          paste0("line_type <- ", graphics_quote_value_default(state$line_type, "solid")),
          paste0("point_size <- ", graphics_quote_number(state$point_size, 1))
        )
      ),
      list(
        title = "Draw boxplot",
        lines = c(
          "title_text <- if (is.null(plot_title) || !nzchar(plot_title)) \"箱线图\" else plot_title",
          "xlab_text <- if (is.null(plot_xlab) || !nzchar(plot_xlab)) x_var else plot_xlab",
          "ylab_text <- if (is.null(plot_ylab) || !nzchar(plot_ylab)) y_var else plot_ylab",
          "p <- ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]], fill = .data[[x_var]])) +",
          "  geom_boxplot(alpha = 0.7, linewidth = line_size, linetype = line_type, outlier.size = point_size) +",
          "  theme_minimal() +",
          "  labs(title = title_text, x = xlab_text, y = ylab_text, fill = x_var)",
          "fill_scale <- switch(",
          "  plot_palette,",
          "  lancet = ggsci::scale_fill_lancet(),",
          "  jama = ggsci::scale_fill_jama(),",
          "  nejm = ggsci::scale_fill_nejm(),",
          "  viridis = ggplot2::scale_fill_viridis_d(),",
          "  NULL",
          ")",
          "if (!is.null(fill_scale)) p <- p + fill_scale",
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
          paste0("cluster_heatmap <- ", graphics_quote_bool(state$clustering))
        )
      ),
      list(
        title = "Draw heatmap",
        lines = c(
          "mat <- stats::cor(data[, selected_vars, drop = FALSE], use = \"complete.obs\")",
          "if (isTRUE(cluster_heatmap) && nrow(mat) > 1 && ncol(mat) > 1) {",
          "  distance_source <- mat",
          "  distance_source[!is.finite(distance_source)] <- 0",
          "  diag(distance_source) <- 1",
          "  order_idx <- tryCatch(",
          "    stats::hclust(stats::as.dist(1 - distance_source))$order,",
          "    error = function(e) seq_len(ncol(mat))",
          "  )",
          "  mat <- mat[order_idx, order_idx, drop = FALSE]",
          "}",
          "cor_long <- as.data.frame(as.table(mat))",
          "names(cor_long) <- c(\"Var1\", \"Var2\", \"Correlation\")",
          "p <- ggplot(cor_long, aes(Var1, Var2, fill = Correlation)) +",
          "  geom_tile(linewidth = 0.8) +",
          "  scale_fill_gradient2(low = \"blue\", high = \"red\", mid = \"white\", midpoint = 0, limit = c(-1, 1)) +",
          "  theme_minimal() +",
          "  labs(title = \"相关性热图\", x = \"变量\", y = \"变量\")",
          "print(p)"
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
          "corr_mat <- stats::cor(data[, selected_vars, drop = FALSE], use = \"complete.obs\", method = if (is.null(corr_method)) \"pearson\" else gsub('^\"|\"$', '', corr_method))",
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
          paste0("x_var <- ", graphics_quote_value(state$main_x_var)),
          paste0("y_var <- ", graphics_quote_value(state$main_y_var)),
          paste0("group_var <- ", graphics_quote_value(state$group_var)),
          paste0("facet_var <- ", graphics_quote_value(state$facet_var)),
          paste0("plot_types <- ", graphics_quote_vector(state$plot_types)),
          paste0("combine_method <- ", graphics_quote_value_default(graphics_first_non_null(state$method, state$combo_method), "overlay")),
          paste0("scatter_size <- ", graphics_quote_number(state$scatter_size, 2)),
          paste0("scatter_alpha <- ", graphics_quote_number(state$scatter_alpha, 0.6)),
          paste0("scatter_jitter <- ", graphics_quote_bool_default(state$scatter_jitter, FALSE)),
          paste0("line_width <- ", graphics_quote_number(state$line_width, 1)),
          paste0("line_type <- ", graphics_quote_value_default(state$line_type, "solid")),
          paste0("line_smooth <- ", graphics_quote_bool_default(state$line_smooth, FALSE)),
          paste0("bar_position <- ", graphics_quote_value_default(state$bar_position, "stack")),
          paste0("bar_width <- ", graphics_quote_number(state$bar_width, 0.7)),
          paste0("bar_alpha <- ", graphics_quote_number(state$bar_alpha, 0.8)),
          paste0("boxplot_width <- ", graphics_quote_number(state$boxplot_width, 0.5)),
          paste0("boxplot_outliers <- ", graphics_quote_bool_default(state$boxplot_outliers, TRUE)),
          paste0("boxplot_notch <- ", graphics_quote_bool_default(state$boxplot_notch, FALSE)),
          paste0("density_alpha <- ", graphics_quote_number(state$density_alpha, 0.4)),
          paste0("density_position <- ", graphics_quote_value_default(state$density_position, "identity")),
          paste0("density_adjust <- ", graphics_quote_number(state$density_adjust, 1)),
          paste0("hist_bins <- ", graphics_quote_number(state$hist_bins, 30)),
          paste0("hist_position <- ", graphics_quote_value_default(state$hist_position, "stack")),
          paste0("hist_alpha <- ", graphics_quote_number(state$hist_alpha, 0.6)),
          paste0("area_position <- ", graphics_quote_value_default(state$area_position, "stack")),
          paste0("area_alpha <- ", graphics_quote_number(state$area_alpha, 0.4)),
          paste0("violin_trim <- ", graphics_quote_bool_default(state$violin_trim, TRUE)),
          paste0("violin_draw_quantiles <- ", graphics_quote_bool_default(state$violin_draw_quantiles, TRUE)),
          paste0("violin_alpha <- ", graphics_quote_number(state$violin_alpha, 0.7))
        )
      ),
      list(
        title = "Compose plot workflow",
        lines = c(
          "library(cowplot)",
          "normalize_combo_var <- function(value) {",
          "  if (is.null(value) || length(value) == 0 || is.na(value[[1]])) return(NULL)",
          "  value <- as.character(value[[1]])",
          "  if (!nzchar(trimws(value)) || value %in% c(\"none\", \"None\", \"无\", \"无分组\", \"无分面\")) return(NULL)",
          "  value",
          "}",
          "x_var <- normalize_combo_var(x_var)",
          "y_var <- normalize_combo_var(y_var)",
          "group_var <- normalize_combo_var(group_var)",
          "facet_var <- normalize_combo_var(facet_var)",
          "add_combo_mapping <- function(plot_obj) {",
          "  if (!is.null(x_var) && !is.null(y_var) && !is.null(group_var)) {",
          "    return(plot_obj + aes(x = .data[[x_var]], y = .data[[y_var]], color = .data[[group_var]], fill = .data[[group_var]], group = .data[[group_var]]))",
          "  }",
          "  if (!is.null(x_var) && !is.null(y_var)) {",
          "    return(plot_obj + aes(x = .data[[x_var]], y = .data[[y_var]]))",
          "  }",
          "  if (!is.null(x_var) && !is.null(group_var)) {",
          "    return(plot_obj + aes(x = .data[[x_var]], color = .data[[group_var]], fill = .data[[group_var]], group = .data[[group_var]]))",
          "  }",
          "  if (!is.null(x_var)) return(plot_obj + aes(x = .data[[x_var]]))",
          "  plot_obj",
          "}",
          "add_combo_layer <- function(plot_obj, tp) {",
          "  if (identical(tp, \"scatter\")) {",
          "    pos <- if (isTRUE(scatter_jitter)) position_jitter(width = 0.2, height = 0.2) else \"identity\"",
          "    return(plot_obj + geom_point(size = scatter_size, alpha = scatter_alpha, position = pos))",
          "  }",
          "  if (identical(tp, \"line\")) {",
          "    if (is.null(group_var)) plot_obj <- plot_obj + aes(group = 1)",
          "    plot_obj <- plot_obj + geom_line(linewidth = line_width, linetype = line_type)",
          "    if (isTRUE(line_smooth)) plot_obj <- plot_obj + geom_smooth(se = FALSE)",
          "    return(plot_obj)",
          "  }",
          "  if (identical(tp, \"bar\")) {",
          "    stat_method <- if (!is.null(y_var)) \"identity\" else \"count\"",
          "    return(plot_obj + geom_bar(stat = stat_method, position = bar_position, width = bar_width, alpha = bar_alpha))",
          "  }",
          "  if (identical(tp, \"boxplot\")) {",
          "    outlier_shape <- if (isTRUE(boxplot_outliers)) 19 else NA",
          "    return(plot_obj + geom_boxplot(width = boxplot_width, outlier.shape = outlier_shape, notch = isTRUE(boxplot_notch)))",
          "  }",
          "  if (identical(tp, \"density\")) {",
          "    return(plot_obj + geom_density(alpha = density_alpha, position = density_position, adjust = density_adjust))",
          "  }",
          "  if (identical(tp, \"histogram\")) {",
          "    return(plot_obj + geom_histogram(bins = hist_bins, position = hist_position, alpha = hist_alpha))",
          "  }",
          "  if (identical(tp, \"area\")) {",
          "    stat_method <- if (!is.null(y_var)) \"identity\" else \"count\"",
          "    return(plot_obj + geom_area(stat = stat_method, position = area_position, alpha = area_alpha))",
          "  }",
          "  if (identical(tp, \"violin\")) {",
          "    draw_q <- if (isTRUE(violin_draw_quantiles)) c(0.25, 0.5, 0.75) else NULL",
          "    return(plot_obj + geom_violin(trim = isTRUE(violin_trim), draw_quantiles = draw_q, alpha = violin_alpha))",
          "  }",
          "  plot_obj",
          "}",
          "finalize_combo_plot <- function(plot_obj, title) {",
          "  if (!is.null(facet_var)) plot_obj <- plot_obj + facet_wrap(as.formula(paste(\"~\", facet_var)))",
          "  plot_obj + theme_minimal() + labs(title = title)",
          "}",
          "build_combo_plot <- function(tp) {",
          "  plot_obj <- ggplot(data)",
          "  plot_obj <- add_combo_mapping(plot_obj)",
          "  plot_obj <- add_combo_layer(plot_obj, tp)",
          "  finalize_combo_plot(plot_obj, paste0(tp, \" plot\"))",
          "}",
          "if (identical(combine_method, \"overlay\")) {",
          "  p <- ggplot(data)",
          "  p <- add_combo_mapping(p)",
          "  for (tp in plot_types) p <- add_combo_layer(p, tp)",
          "  p <- finalize_combo_plot(p, \"组合图形 (叠加模式)\")",
          "  print(p)",
          "} else {",
          "  plot_list <- lapply(plot_types, build_combo_plot)",
          "  combo_plot <- cowplot::plot_grid(plotlist = plot_list, nrow = if (identical(combine_method, \"side_by_side\")) 1 else length(plot_list))",
          "  print(combo_plot)",
          "}"
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
