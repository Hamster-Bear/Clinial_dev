# 生存分析图形子模块
# 负责生成生存曲线（Kaplan-Meier曲线）

# 加载必要的包
# survival/survminer 仅在用户使用生存分析时按需加载，避免拖慢启动
library(plotly)
library(DT)
library(cowplot)

if (!exists("app_card_box", mode = "function") ||
    !exists("app_card_note", mode = "function") ||
    !exists("app_result_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}
if (file.exists("modules/common/graphics_result_copy.R")) {
  source("modules/common/graphics_result_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics_result_copy.R"))
}
if (file.exists("modules/common/graphics_export_copy.R")) {
  source("modules/common/graphics_export_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics_export_copy.R"))
}

.resolve_survival_choice <- function(input_value, state_value, choices, default_value = NULL) {
  if (length(choices) == 0) return(default_value %||% NULL)
  if (!is.null(input_value) && input_value %in% choices) return(input_value)
  if (!is.null(state_value) && state_value %in% choices) return(state_value)
  if (!is.null(default_value) && default_value %in% choices) return(default_value)
  choices[1]
}

.survival_strata_label_input_id <- function(value) {
  paste0("strata_label_", digest::digest(as.character(value %||% ""), algo = "crc32"))
}

.strip_survival_strata_value <- function(strata_name, strata_var = NULL) {
  label <- as.character(strata_name %||% "all")
  if (!nzchar(label)) return(label)
  if (!is.null(strata_var) && nzchar(strata_var)) {
    prefixes <- c(
      paste0(strata_var, "="),
      paste0("`", strata_var, "`=")
    )
    for (prefix in prefixes) {
      if (startsWith(label, prefix)) {
        return(substr(label, nchar(prefix) + 1, nchar(label)))
      }
    }
  }
  label
}

.format_survival_group_label <- function(strata_name, strata_var = NULL, strata_labels = list(), overall_label = "all") {
  label <- as.character(strata_name %||% "all")
  if (!nzchar(label) || identical(tolower(label), "all")) return(overall_label %||% "all")
  label <- .strip_survival_strata_value(label, strata_var)
  mapped <- strata_labels[[label]]
  if (!is.null(mapped) && length(mapped) >= 1 && !is.na(as.character(mapped[[1]]))) as.character(mapped[[1]]) else label
}

.build_survival_strata_labeler <- function(strata_var = NULL, strata_labels = list(), overall_label = "all") {
  force(strata_var)
  force(strata_labels)
  force(overall_label)
  function(x) {
    vapply(
      x,
      function(val) .format_survival_group_label(val, strata_var, strata_labels, overall_label),
      character(1)
    )
  }
}

.resolve_survival_risk_table_scale <- function(risk_table_plot, labeler) {
  y_scale_idx <- which(vapply(risk_table_plot$scales$scales, function(x) "y" %in% x$aesthetics, logical(1)))
  if (length(y_scale_idx) == 0) {
    return(list(breaks = waiver(), labels = labeler))
  }
  orig_scale <- risk_table_plot$scales$scales[[y_scale_idx[1]]]
  orig_breaks <- orig_scale$breaks
  if (inherits(orig_breaks, "waiver") || is.null(orig_breaks)) {
    return(list(breaks = waiver(), labels = labeler))
  }

  orig_labels <- tryCatch({
    if (is.function(orig_scale$labels)) {
      orig_scale$labels(orig_breaks)
    } else if (!is.null(orig_scale$labels) && !inherits(orig_scale$labels, "waiver")) {
      orig_scale$labels
    } else {
      orig_breaks
    }
  }, error = function(e) orig_breaks)

  list(
    breaks = orig_breaks,
    labels = unname(labeler(orig_labels))
  )
}

.extract_survival_legend_labs <- function(fit_obj, strata_var = NULL, strata_labels = list(), overall_label = "all") {
  if (is.null(fit_obj$strata)) return(overall_label %||% "all")
  vapply(
    names(fit_obj$strata),
    function(x) .format_survival_group_label(x, strata_var, strata_labels, overall_label),
    character(1)
  )
}

.survival_aux_legend_compact_spec <- utils::modifyList(
  graphics_aux_legend_compact_defaults,
  list(
    row_gap = 1,
    secondary_rel_height = 0.68,
    default_inside_anchor = c(0.95, 0.85, 0.13, 0.14)
  )
)

.extract_survival_legend_breaks <- function(fit_obj, strata_var = NULL, overall_label = "all") {
  if (is.null(fit_obj$strata)) return(overall_label %||% "all")
  as.character(names(fit_obj$strata))
}

.build_survival_legend_colors <- function(breaks, palette_name = "Set1") {
  breaks <- as.character(breaks %||% character(0))
  if (length(breaks) == 0) return(setNames(character(0), character(0)))
  if (requireNamespace("RColorBrewer", quietly = TRUE) && palette_name %in% rownames(RColorBrewer::brewer.pal.info)) {
    max_n <- RColorBrewer::brewer.pal.info[palette_name, "maxcolors"]
    base_vals <- RColorBrewer::brewer.pal(max(3, min(max_n, length(breaks))), palette_name)
    vals <- rep(base_vals, length.out = length(breaks))
  } else {
    vals <- scales::hue_pal()(length(breaks))
  }
  stats::setNames(vals, breaks)
}

.resolve_survival_legend_colors <- function(plot_obj, raw_breaks, display_breaks) {
  raw_breaks <- as.character(raw_breaks %||% character(0))
  display_breaks <- as.character(display_breaks %||% character(0))
  if (length(display_breaks) == 0) return(setNames(character(0), character(0)))
  scale_obj <- plot_obj$scales$get_scales("colour")
  if (is.null(scale_obj)) scale_obj <- plot_obj$scales$get_scales("color")
  mapped <- tryCatch({
    if (is.null(scale_obj) || length(raw_breaks) == 0) return(NULL)
    as.character(scale_obj$map(raw_breaks))
  }, error = function(e) NULL)
  if (is.null(mapped) || length(mapped) != length(display_breaks) || any(is.na(mapped) | !nzchar(mapped))) {
    mapped <- scales::hue_pal()(length(display_breaks))
  }
  stats::setNames(mapped, display_breaks)
}

.resolve_survival_censor_legend_layout <- function(position = "right", inside_anchor = NULL) {
  if (identical(position, "none")) {
    return(list(position = "none", anchor = NULL))
  }
  if (position %in% c("right", "left", "top", "bottom")) {
    return(list(position = position, anchor = NULL))
  }
  if (identical(position, "inside_custom")) {
    anchor_vals <- if (exists("graphics_normalize_anchor", mode = "function")) {
      graphics_normalize_anchor(inside_anchor, .survival_aux_legend_compact_spec$default_inside_anchor)
    } else {
      inside_anchor %||% .survival_aux_legend_compact_spec$default_inside_anchor
    }
    return(list(position = "inside_custom", anchor = graphics_resolve_inside_anchor(
      x_ratio = anchor_vals[[1]],
      y_ratio = anchor_vals[[2]],
      width_ratio = anchor_vals[[3]],
      height_ratio = anchor_vals[[4]]
    )))
  }
  anchor_map <- list(
    "top-right" = graphics_resolve_inside_anchor(0.72, 0.58, 0.24, 0.22),
    "top-left" = graphics_resolve_inside_anchor(0.02, 0.58, 0.24, 0.22),
    "bottom-left" = graphics_resolve_inside_anchor(0.02, 0.03, 0.24, 0.22),
    "bottom-right" = graphics_resolve_inside_anchor(0.72, 0.03, 0.24, 0.22)
  )
  list(
    position = if (position %in% names(anchor_map)) "inside_custom" else "right",
    anchor = anchor_map[[position]] %||% NULL
  )
}

.resolve_survival_censor_shape_value <- function(shape_value, fallback = 3) {
  resolved <- suppressWarnings(as.numeric(shape_value %||% fallback))
  if (is.na(resolved) || !is.finite(resolved)) fallback else resolved
}

.resolve_survival_font_spec <- function(base_family = "sans", cjk_family = "Noto Sans SC") {
  if (exists("graphics_resolve_font_spec", mode = "function")) {
    return(graphics_resolve_font_spec(base_family = base_family, cjk_family = cjk_family))
  }
  latin <- trimws(as.character(graphics_first_value_or_default(base_family, "sans")))
  list(latin = latin, cjk = latin, layout = latin, unified = latin)
}

.resolve_survival_base_family <- function(base_family = "sans", cjk_family = "Noto Sans SC") {
  if (exists("graphics_resolve_font_spec", mode = "function")) {
    return(.resolve_survival_font_spec(base_family = base_family, cjk_family = cjk_family)$unified)
  }
  if (exists("graphics_resolve_device_safe_family", mode = "function")) {
    return(graphics_resolve_device_safe_family(base_family))
  }
  trimws(as.character(graphics_first_value_or_default(base_family, "sans")))
}

.resolve_survival_layout_family <- function(base_family = "sans", cjk_family = "Noto Sans SC") {
  if (exists("graphics_resolve_font_spec", mode = "function")) {
    return(.resolve_survival_font_spec(base_family = base_family, cjk_family = cjk_family)$layout)
  }
  .resolve_survival_base_family(base_family = base_family, cjk_family = cjk_family)
}

.resolve_survival_text_size_pt <- function(size_pt = 10, fallback = 10) {
  resolved <- suppressWarnings(as.numeric(size_pt %||% fallback))
  fallback_resolved <- suppressWarnings(as.numeric(fallback))
  if (is.na(fallback_resolved) || !is.finite(fallback_resolved) || fallback_resolved <= 0) fallback_resolved <- 10
  if (is.na(resolved) || !is.finite(resolved) || resolved <= 0) fallback_resolved else resolved
}

.resolve_survival_risk_table_geom_size <- function(size_pt = 10, fallback = 10) {
  resolved_pt <- .resolve_survival_text_size_pt(size_pt, fallback = fallback)
  if (exists("graphics_pt_to_geom_text_size", mode = "function")) {
    return(graphics_pt_to_geom_text_size(resolved_pt, fallback = fallback))
  }
  resolved_pt / ggplot2::.pt
}

.build_survival_risk_table_axis_text_element <- function(existing = NULL, size_pt = 10, family = "sans", face = "plain") {
  resolved_size <- .resolve_survival_text_size_pt(size_pt, fallback = 10)
  resolved_family <- .resolve_survival_base_family(family)
  resolved_face <- if (isTRUE(face %in% c("plain", "bold", "italic", "bold.italic"))) face else "plain"

  if (inherits(existing, "element_text") || inherits(existing, "element_markdown")) {
    existing$size <- resolved_size
    existing$family <- resolved_family
    existing$face <- resolved_face
    return(existing)
  }

  element_text(size = resolved_size, family = resolved_family, face = resolved_face)
}

.apply_survival_risk_table_text_style <- function(risk_table_plot, number_size_pt = 10, y_text_size = 10, base_family = "sans", cjk_family = "Noto Sans SC", bold = FALSE) {
  if (is.null(risk_table_plot)) return(risk_table_plot)
  plot_family <- .resolve_survival_base_family(base_family, cjk_family = cjk_family)
  number_size <- .resolve_survival_risk_table_geom_size(number_size_pt, fallback = 10)
  y_axis_size <- .resolve_survival_text_size_pt(y_text_size, fallback = 10)
  number_face <- if (isTRUE(bold)) "bold" else "plain"

  risk_table_plot <- risk_table_plot +
    theme(
      text = element_text(family = plot_family, face = "plain")
    )
  risk_table_plot$theme$axis.text.y <- .build_survival_risk_table_axis_text_element(
    existing = risk_table_plot$theme$axis.text.y,
    size_pt = y_axis_size,
    family = plot_family,
    face = "plain"
  )

  if (length(risk_table_plot$layers) > 0) {
    for (idx in seq_along(risk_table_plot$layers)) {
      geom_name <- class(risk_table_plot$layers[[idx]]$geom)[1] %||% ""
      if (identical(geom_name, "GeomText")) {
        risk_table_plot$layers[[idx]]$aes_params$family <- plot_family
        risk_table_plot$layers[[idx]]$aes_params$fontface <- number_face
        risk_table_plot$layers[[idx]]$aes_params$size <- number_size
        risk_table_plot$layers[[idx]]$geom_params$family <- plot_family
        risk_table_plot$layers[[idx]]$geom_params$fontface <- number_face
        risk_table_plot$layers[[idx]]$geom_params$size <- number_size
      }
    }
  }

  risk_table_plot
}

.build_survival_legend_rows <- function(labels, row_gap = .survival_aux_legend_compact_spec$row_gap) {
  graphics_build_legend_rows(labels, row_gap = row_gap)
}

.build_survival_censor_legend_plot <- function(labels, colors, shape_value = 3, title = "Censor", base_font_size = 10, row_gap = 1.0, font_family = "sans") {
  graphics_build_point_legend_plot(
    labels = labels,
    colors = colors,
    shape_value = .resolve_survival_censor_shape_value(shape_value),
    title = title,
    base_font_size = base_font_size,
    row_gap = row_gap,
    compact_spec = .survival_aux_legend_compact_spec,
    font_family = .resolve_survival_base_family(font_family)
  )
}

.build_survival_line_legend_plot <- function(labels, colors, title = "", line_size = 0.6, line_type = "solid", base_font_size = 10, row_gap = 1.0, font_family = "sans") {
  graphics_build_line_legend_plot(
    labels = labels,
    colors = colors,
    title = title,
    line_size = line_size,
    line_type = line_type,
    base_font_size = base_font_size,
    row_gap = row_gap,
    compact_spec = .survival_aux_legend_compact_spec,
    font_family = .resolve_survival_base_family(font_family)
  )
}

.compose_survival_static_legend <- function(main_legend_plot = NULL, censor_legend_plot = NULL, legend_position = "right", inside_anchor = NULL, primary_rows = 1, secondary_rows = 1) {
  if (identical(legend_position, "none")) {
    return(list(legend_plot = NULL, layout = .resolve_survival_censor_legend_layout("none", inside_anchor = inside_anchor)))
  }
  legend_plot <- graphics_compose_stacked_legends(
    primary_plot = main_legend_plot,
    secondary_plot = censor_legend_plot,
    compact_spec = .survival_aux_legend_compact_spec,
    primary_rows = primary_rows,
    secondary_rows = secondary_rows
  )
  list(
    legend_plot = legend_plot,
    layout = .resolve_survival_censor_legend_layout(legend_position, inside_anchor = inside_anchor)
  )
}

.survival_annotation_line_gap <- function() {
  0.055
}

.build_survival_annotation_y_positions <- function(start_y, n_groups, lower_bound, gap = .survival_annotation_line_gap()) {
  if (is.null(n_groups) || n_groups <= 0) return(numeric(0))
  gap <- suppressWarnings(as.numeric(gap %||% .survival_annotation_line_gap()))
  if (is.na(gap) || !is.finite(gap) || gap <= 0) gap <- .survival_annotation_line_gap()
  seq(start_y, max(lower_bound, start_y - (n_groups - 1) * gap), length.out = n_groups)
}

.survival_median_text_hjust <- function() {
  0
}

.build_survival_logrank_interpretation <- function(logrank_p, n_groups = 0) {
  if (is.na(logrank_p)) return(character(0))
  logrank_text <- .compose_survival_p_text("Log-rank 检验 P值", logrank_p, with_spaces = FALSE)
  result_line <- if (logrank_p < 0.05) {
    paste0(logrank_text, "，提示组间生存曲线差异具有统计学意义。")
  } else {
    paste0(logrank_text, "，未见组间生存曲线显著差异。")
  }
  if (isTRUE(n_groups > 3)) {
    return(c(
      result_line,
      "当前为多组全局 Log-rank 检验；显著时仅表示至少一组生存曲线与其他组存在差异，不代表所有两两组别均显著，需结合 Cox 参考组比较或后续两两比较解释。"
    ))
  }
  result_line
}

.resolve_survival_median_label <- function(label_value = NULL, fallback = "mPFS") {
  label_value <- graphics_text_or_default(label_value, default = fallback, allow_blank_string = TRUE)
  if (identical(label_value, "")) fallback else label_value
}

.resolve_survival_censor_point_colors <- function(raw_strata, display_strata, main_legend_colors = NULL, fallback_colors = NULL) {
  display_strata <- as.character(display_strata %||% character(0))
  raw_strata <- as.character(raw_strata %||% character(0))
  color_vals <- unname((main_legend_colors %||% character(0))[display_strata])
  if (length(color_vals) != length(display_strata)) {
    color_vals <- rep(NA_character_, length(display_strata))
  }
  if (!is.null(fallback_colors) && length(fallback_colors) > 0) {
    fallback_vals <- unname(fallback_colors[raw_strata])
    replace_idx <- is.na(color_vals) | !nzchar(color_vals)
    color_vals[replace_idx] <- fallback_vals[replace_idx]
  }
  color_vals
}

.build_survival_median_summary_label <- function(display_strata, median_label, median_txt, lower_txt, upper_txt, overall_label = "all") {
  prefix <- .resolve_survival_median_label(median_label)
  stats_part <- paste0(prefix, ": ", median_txt, " (95%CI ", lower_txt, "-", upper_txt, ")")
  if (!nzchar(display_strata) || identical(display_strata, overall_label)) {
    return(stats_part)
  }
  paste0(display_strata, ": ", stats_part)
}

.format_survival_p_value <- function(p) {
  if (exists("format_p_value_ama", mode = "function")) {
    return(format_p_value_ama(p))
  }
  val <- suppressWarnings(as.numeric(p))
  if (is.na(val)) return("—")
  if (val < 0.001) return("<0.001")
  if (val > 0.99) return(">0.99")
  sprintf("%.3f", val)
}

.compose_survival_p_text <- function(prefix, p, with_spaces = TRUE) {
  formatted <- .format_survival_p_value(p)
  if (!nzchar(formatted) || identical(formatted, "—")) return(NULL)
  operator <- if (startsWith(formatted, "<") || startsWith(formatted, ">")) "" else "="
  if (with_spaces) {
    pieces <- c(prefix, operator, formatted)
    return(paste(pieces[nzchar(pieces)], collapse = " "))
  }
  paste0(prefix, operator, formatted)
}

.build_survival_hr_summary_line <- function(
    contrast_label,
    reference_label,
    hr,
    hr_low,
    hr_up,
    p_val = NULL,
    show_cox_p = TRUE
) {
  hr_line <- paste0(
    contrast_label, " vs ", reference_label,
    ": HR = ", formatC(hr, format = "f", digits = 2),
    " (95%CI: ", formatC(hr_low, format = "f", digits = 2), "-",
    formatC(hr_up, format = "f", digits = 2), ")"
  )
  if (isTRUE(show_cox_p)) {
    p_text <- .compose_survival_p_text("P", p_val)
    if (!is.null(p_text)) {
      hr_line <- paste0(hr_line, ", ", p_text)
    }
  }
  hr_line
}

.apply_survival_line_style <- function(plot_obj, line_size, line_type) {
  plot_obj$layers <- lapply(plot_obj$layers, function(layer) {
    if (any(class(layer$geom) %in% c("GeomStep", "GeomLine"))) {
      layer$aes_params$linewidth <- line_size
      layer$aes_params$size <- line_size
      layer$aes_params$linetype <- line_type
    }
    layer
  })
  plot_obj
}

.build_survival_mapping_tab <- function(ns) {
  tabsetPanel(
    tabPanel(
      "核心映射",
      br(),
      graphics_column_mapping_panel_ui(
        ns,
        title = "核心映射",
        fields = list(
          list(list(id = "km_time", label = tags$span("生存时间变量 [数值]", title = "用于构建 Surv(time, status) 的时间变量"), type = "selectize")),
          list(list(id = "km_status", label = tags$span("事件状态变量 [数值编码]", title = "二值状态变量，具体 0/1 含义由“状态变量编码含义”指定"), type = "selectize"))
        )
      )
    ),
    tabPanel(
      "分组/分面/轨道/附加变量",
      br(),
      graphics_column_mapping_panel_ui(
        ns,
        title = "分组/分面/附加变量",
        fields = list(
          list(
            list(id = "strata_var", label = tags$span("分层变量 [分组，可选]", title = "用于分组绘制 KM 曲线与 HR"), type = "selectize", choices = c("无" = "None"), column = 6),
            list(id = "facet_var", label = tags$span("分面变量 [分组，可选]", title = "用于拆分多个子图，仅显示一个分面值"), type = "selectize", choices = c("无" = "None"), column = 6)
          )
        ),
        extra_ui = tagList(
          conditionalPanel(
            condition = paste0("input['", ns("strata_var"), "'] != 'None'"),
            uiOutput(ns("hr_reference_ui"))
          ),
          conditionalPanel(
            condition = paste0("input['", ns("facet_var"), "'] != 'None'"),
            uiOutput(ns("facet_value_ui"))
          )
        )
      ),
      graphics_card_panel_ui(
        "处理与筛选",
        tagList(
          radioButtons(
            ns("km_censor_value"), "状态变量编码含义",
            choices = c("0 = 删失, 1 = 事件" = "0", "1 = 删失, 0 = 事件" = "1"),
            selected = "0", inline = TRUE
          ),
          helpText("这里定义状态变量中 0/1 的业务含义，不改变原始数据，只影响生存对象构造。"),
          hr(),
          graphics_time_axis_controls_ui(ns)
        )
      )
    )
  )
}

.build_survival_analysis_tab <- function(ns) {
  list(
    tabPanel(
      "显示与坐标",
      br(),
      graphics_card_panel_ui(
        "曲线、删失点与风险表",
        tagList(
          fluidRow(
            column(6, numericInput(ns("line_size"), "线条粗细", value = 0.6, min = 0.1, max = 5, step = 0.1, width = "100%")),
            column(
              6,
              selectInput(
                ns("line_type"), "线条类型",
                choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted", "点虚线" = "dotdash", "长虚线" = "longdash"),
                width = "100%"
              )
            )
          ),
          checkboxInput(ns("km_show_censor"), "显示删失点", value = TRUE),
          conditionalPanel(
            condition = paste0("input['", ns("km_show_censor"), "'] == true"),
            fluidRow(
              column(6, numericInput(ns("km_censor_size"), "删失点大小", value = 2, min = 1, max = 10, step = 0.5, width = "100%")),
              column(
                6,
                selectInput(
                  ns("km_censor_shape"), "删失点形状",
                  choices = graphics_point_shape_choices(),
                  selected = 3, width = "100%"
                )
              )
            )
          ),
          checkboxInput(ns("km_show_risktable"), "显示风险表", value = TRUE),
          conditionalPanel(
            condition = paste0("input['", ns("km_show_risktable"), "'] == true"),
            tagList(
              helpText("这些设置只影响下方风险表的高度、间距与分组排布。"),
              fluidRow(
                column(6, numericInput(ns("risk_table_height_ratio"), "风险表高度比例", value = 0.15, min = 0.1, max = 0.8, step = 0.05, width = "100%")),
                column(6, numericInput(ns("risk_table_plot_gap"), "主图与表间距(pt)", value = 0, min = 0, max = 100, step = 5, width = "100%"))
              ),
              numericInput(ns("risk_table_group_gap"), "风险表组别间隙", value = 1.2, min = 0, max = 2.0, step = 0.1, width = "100%")
            )
          ),
          checkboxInput(ns("show_grid"), "显示网格线", value = FALSE),
          selectInput(ns("surv_median_line"), "中位生存辅助线", choices = c("无" = "none", "水平和垂直" = "hv", "仅水平" = "h", "仅垂直" = "v"), selected = "none", width = "100%"),
          helpText("该设置控制主图中的中位生存辅助线；与“显示中位生存时间标注”相互独立。")
        )
      ),
      graphics_card_panel_ui(
        "坐标与标签格式",
        tagList(
          fluidRow(
            column(4, numericInput(ns("y_break_step"), "Y轴步长", value = 0.25, min = 0.05, max = 1, step = 0.05, width = "100%")),
            column(4, checkboxInput(ns("y_as_percent"), "Y轴显示百分比", value = FALSE, width = "100%")),
            column(4, numericInput(ns("y_decimals"), "Y轴保留小数位数", value = 2, min = 0, max = 5, step = 1, width = "100%"))
          ),
          selectInput(ns("axis_style"), "坐标轴样式", choices = c("默认" = "default", "经典坐标轴(不带箭头)" = "classic", "经典XY轴(箭头)" = "classic_arrow"), selected = "default", width = "100%"),
          conditionalPanel(
            condition = paste0("input['", ns("y_as_percent"), "'] == true"),
            checkboxInput(ns("y_show_percent_sign"), "带百分号(%)", value = TRUE)
          )
        )
      )
    ),
    tabPanel(
      "参考线与阈值",
      br(),
      graphics_card_panel_ui(
        "统计标注与位置",
        tagList(
          checkboxInput(ns("show_median"), "显示中位生存时间文本标注", value = TRUE),
          conditionalPanel(
            condition = paste0("input['", ns("show_median"), "'] == true"),
            textInput(ns("median_label_text"), "中位生存标签前缀", value = "mPFS", placeholder = "例如 mPFS / mOS", width = "100%"),
            helpText("用于主图和统计报告中的中位生存时间文本前缀，不控制辅助线显示。")
          ),
          checkboxInput(ns("show_stats"), "显示统计摘要（Log-rank P；分层时附加 HR）", value = TRUE),
          conditionalPanel(
            condition = paste0("input['", ns("show_stats"), "'] == true"),
            checkboxInput(ns("show_cox_p"), "显示 Cox 回归 P值", value = TRUE)
          ),
          selectInput(
            ns("text_position_preset"), "统计/中位标注位置预设",
            choices = c("自动（默认）" = "auto", "左上" = "top-left", "右上" = "top-right", "左下" = "bottom-left", "右下" = "bottom-right", "自定义" = "custom"),
            selected = "bottom-left", width = "100%"
          ),
          helpText("该位置预设同时作用于中位生存文本标注和统计摘要文本。"),
          graphics_aux_legend_anchor_controls_ui(
            ns,
            position_id = "text_position_preset",
            x_ratio_id = "median_x",
            y_ratio_id = "median_y",
            default_anchor = c(0.98, 0.95, 0.13, 0.14),
            condition_positions = "custom",
            x_label = "中位生存X",
            y_label = "中位生存Y",
            include_size = FALSE,
            header = "自定义坐标 (0-1相对位置)"
          ),
          graphics_aux_legend_anchor_controls_ui(
            ns,
            position_id = "text_position_preset",
            x_ratio_id = "stats_x",
            y_ratio_id = "stats_y",
            default_anchor = c(0.02, 0.95, 0.13, 0.14),
            condition_positions = "custom",
            x_label = "统计量X",
            y_label = "统计量Y",
            include_size = FALSE,
            header = ""
          )
        )
      )
    )
  )
}

.build_survival_theme_tab <- function(ns) {
  list(
    tabPanel(
      "标题与说明",
      br(),
      graphics_text_label_panel_ui(
        ns,
        title = "标题与说明",
        fields = list(
          list(list(id = "plot_title", label = "主标题", type = "text", selected = "", placeholder = "输入标题")),
          list(
            list(id = "title_size", label = "标题大小", type = "numeric", value = 14, min = 8, max = 24, step = 1, column = 6),
            list(id = "caption_size", label = "脚注大小", type = "numeric", value = 10, min = 8, max = 20, step = 1, column = 6)
          ),
          list(list(id = "plot_caption", label = "脚注", type = "textarea", selected = "", rows = 2)),
          list(
            list(id = "plot_xlab", label = "X轴标签", type = "text", selected = "Duration", column = 6),
            list(id = "xlab_size", label = "X轴字号", type = "numeric", value = 12, min = 8, max = 20, step = 1, column = 6)
          ),
          list(
            list(id = "plot_ylab", label = "Y轴标签", type = "text", selected = "", column = 6),
            list(id = "ylab_size", label = "Y轴字号", type = "numeric", value = 12, min = 8, max = 20, step = 1, column = 6)
          )
        )
      )
    ),
    tabPanel(
      "图层样式",
      br(),
      graphics_card_panel_ui(
        "图形与图例文字",
        tagList(
          fluidRow(
            column(4, numericInput(ns("axis_text_size"), "坐标刻度字号", value = 10, min = 6, max = 20, step = 1, width = "100%")),
            column(4, numericInput(ns("legend_text_size"), "图例文本字号", value = 10, min = 6, max = 20, step = 1, width = "100%")),
            column(4, numericInput(ns("stats_text_size"), "统计标注字号", value = 10, min = 6, max = 20, step = 1, width = "100%"))
          ),
          numericInput(ns("legend_row_gap"), "图例行间距(row_gap)", value = 1.0, min = 0.1, max = 3.0, step = 0.1, width = "100%"),
          graphics_font_family_pair_ui(ns, latin_id = "base_family", cjk_id = "cjk_family"),
          graphics_legend_controls_ui(ns, title_id = "legend_title", position_id = "legend_position", position_kind = "corners_aux_none", default_position = "top-right"),
          graphics_aux_legend_anchor_controls_ui(
            ns,
            position_id = "legend_position",
            x_ratio_id = "legend_x_ratio",
            y_ratio_id = "legend_y_ratio",
            width_ratio_id = "legend_width_ratio",
            height_ratio_id = "legend_height_ratio",
            default_anchor = .survival_aux_legend_compact_spec$default_inside_anchor,
            condition_positions = "inside_custom"
          ),
          conditionalPanel(
            condition = paste0("input['", ns("strata_var"), "'] == 'None'"),
            textInput(ns("overall_group_label"), "总体组显示名称", value = "all", width = "100%"),
            helpText("仅在未分层时生效；统一用于主图图例、风险表、数据表与统计报告。分层后的组名请在“输出与导出”页签中逐项设置。")
          )
        )
      ),
      graphics_card_panel_ui(
        "风险表文字",
        tagList(
          helpText("这些设置只影响风险表与其分组标签，不影响主图图例与统计标注。"),
          conditionalPanel(
            condition = paste0("input['", ns("km_show_risktable"), "'] == true"),
            fluidRow(
              column(4, numericInput(ns("y_text_size"), "风险表Y轴标签大小", value = 10, min = 6, max = 20, step = 1, width = "100%")),
              column(4, numericInput(ns("risk_table_fontsize"), "风险表数字字号", value = 10, min = 6, max = 20, step = 1, width = "100%")),
              column(4, tags$div(style = "margin-top: 25px;", checkboxInput(ns("risk_table_fontbold"), "风险表数字加粗", value = FALSE)))
            )
          )
        )
      )
    )
  )
}

.build_survival_export_tab <- function(ns) {
  tabsetPanel(
    tabPanel(
      "尺寸与画布",
      br(),
      graphics_card_panel_ui(
        "尺寸与画布",
        tagList(
          selectInput(ns("size_mode"), "尺寸模式", choices = c("宽图标准" = "wide_standard", "自定义尺寸" = "custom"), selected = "wide_standard", width = "100%"),
          conditionalPanel(
            condition = sprintf("input['%s'] === 'custom'", ns("size_mode")),
            tagList(
              fluidRow(
                column(6, numericInput(ns("static_width_px"), "静态图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                column(6, numericInput(ns("static_height_px"), "静态图基础高度(px)", value = 760, min = 400, max = 1800, step = 20, width = "100%"))
              ),
              fluidRow(
                column(6, numericInput(ns("interactive_width_px"), "交互图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                column(6, numericInput(ns("interactive_height_px"), "交互图高度(px)", value = 620, min = 350, max = 1600, step = 20, width = "100%"))
              ),
              fluidRow(
                column(4, checkboxInput(ns("sync_export_size"), "导出尺寸跟随前端画布", value = TRUE, width = "100%")),
                column(4, numericInput(ns("size_sync_ppi"), "PX/英寸换算", value = 96, min = 72, max = 300, step = 1, width = "100%")),
                column(4, checkboxInput(ns("canvas_border"), "显示画布边框", value = TRUE, width = "100%"))
              ),
              fluidRow(
                column(3, numericInput(ns("page_margin_top_px"), "上边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
                column(3, numericInput(ns("page_margin_right_px"), "右边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
                column(3, numericInput(ns("page_margin_bottom_px"), "下边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
                column(3, numericInput(ns("page_margin_left_px"), "左边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%"))
              )
            )
          )
        )
      )
    ),
    tabPanel(
      "导出参数",
      br(),
      graphics_card_panel_ui(
        "导出参数",
        tagList(
          fluidRow(
            column(6, selectInput(ns("export_format"), "导出格式", choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")),
            column(6, numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] === false", ns("sync_export_size")),
            fluidRow(
              column(6, numericInput(ns("export_width_in"), "导出宽度(英寸)", value = 12.5, min = 6, max = 30, step = 0.5, width = "100%")),
              column(6, numericInput(ns("export_height_in"), "导出高度(英寸)", value = 7.9, min = 4, max = 24, step = 0.5, width = "100%"))
            )
          ),
          conditionalPanel(
            condition = paste0("input['", ns("strata_var"), "'] != 'None'"),
            tagList(
              hr(),
              uiOutput(ns("strata_labels_ui"))
            )
          )
        )
      )
    )
  )
}

.build_survival_output_box <- function(ns) {
  copy <- GRAPHICS_RESULT_COPY$survival
  fluidRow(
    column(
      12,
      app_card_box(
        width = 12,
        title = "结果区",
          subtitle = copy$result_card$subtitle,
        tone = "success",
        status = "success",
        solidHeader = FALSE,
          app_card_note(copy$result_card$note),
        graphics_output_action_bar_ui(ns, render_button_id = "render_km_plot", download_id = "download_plot"),
        tabsetPanel(
          id = ns("km_output_tabs"),
          tabPanel(
            "静态图",
            app_result_panel(
              title = "静态图结果",
              note = copy$static_plot$note,
              tone = "success",
              uiOutput(ns("survPlotUI"))
            )
          ),
          tabPanel(
            "交互图",
            app_result_panel(
              title = "交互图结果",
              note = copy$interactive_plot$note,
              tone = "info",
              uiOutput(ns("interactiveSurvPlotUI"))
            )
          ),
          tabPanel(
            "数据",
            app_result_panel(
              title = "结果数据与统计报告",
              note = copy$data_tab$note,
              tone = "warning",
              tabsetPanel(
                tabPanel("数据表", DTOutput(ns("km_data_table"))),
                tabPanel("统计报告", uiOutput(ns("survival_report")))
              )
            )
          )
        )
      )
    )
  )
}

.build_survival_ui_script <- function() {
  tags$script(HTML("
      $(document).ready(function() {
        $(document).on('mousewheel DOMMouseScroll', '.selectize-control .selectize-input', function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
        $(document).on('mousewheel DOMMouseScroll', 'select', function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
        $(document).on('mousewheel DOMMouseScroll', 'input[type=number]', function(e) {
          if ($(this).is(':focus')) {
            e.preventDefault();
            e.stopPropagation();
            $(this).blur();
          }
        });
      });
    "))
}

survival_analysis_ui <- function(id) {
  ns <- NS(id)
  export_copy <- GRAPHICS_EXPORT_COPY$survival

  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "设置核心映射、分组分面与时间范围",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("选择时间变量、状态变量、分层参考组、分面值和时间轴范围。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            .build_survival_mapping_tab(ns)
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "图形与样式",
          subtitle = "设置坐标、标题、样式与阈值",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置中位生存辅助线、统计摘要、图例文字和风险表文字。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            do.call(
              tabsetPanel,
              c(
                .build_survival_theme_tab(ns),
                .build_survival_analysis_tab(ns)
              )
            )
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "输出与导出",
          subtitle = export_copy$subtitle,
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          app_card_note(export_copy$note),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            .build_survival_export_tab(ns)
          )
        )
      )
    ),
    .build_survival_output_box(ns),
    .build_survival_ui_script()
  )
}

survival_analysis_server <- function(input, output, session, data) {
  ns <- session$ns

  # 按需加载生存分析包（启动时延迟加载以加速启动）
  suppressPackageStartupMessages({
    library(survival, quietly = TRUE, warn.conflicts = FALSE)
    library(survminer, quietly = TRUE, warn.conflicts = FALSE)
  })

  # 存储图形参数状态
  graphics_state <- reactiveValues(
    km_time = NULL,
    km_status = NULL,
    time_range = NULL,
    km_censor_value = "0",
    km_show_censor = TRUE,
    km_strata = "None",
    km_facet = "None",
    km_facet_values = NULL,
    km_show_risktable = TRUE,
    risk_table_height_ratio = 0.15,
    risk_table_plot_gap = 0,
    risk_table_group_gap = 1.2,
    surv_median_line = "none",
    km_line_size = 0.6,
    km_line_type = "solid",
    km_censor_size = 3,
    km_censor_shape = 3,
    y_text_size = 10,
    risk_table_fontsize = 10,
    risk_table_fontbold = FALSE,
    title_size = 14,
    caption_size = 10,
    xlab_size = 12,
    ylab_size = 12,
    y_break_step = 0.25,
    y_decimals = 2,
    y_as_percent = FALSE,
    y_show_percent_sign = TRUE,
    axis_text_size = 10,
    legend_text_size = 10,
    stats_text_size = 10,
    axis_style = "default",
    show_grid = FALSE,
    time_step = NULL,
    show_median = TRUE,
    show_stats = TRUE,
    show_cox_p = TRUE,
    legend_position = "top-right",
    legend_title = "",
    legend_row_gap = 1.0,
    legend_inside_anchor = graphics_resolve_inside_anchor(
      x_ratio = .survival_aux_legend_compact_spec$default_inside_anchor[[1]],
      y_ratio = .survival_aux_legend_compact_spec$default_inside_anchor[[2]],
      width_ratio = .survival_aux_legend_compact_spec$default_inside_anchor[[3]],
      height_ratio = .survival_aux_legend_compact_spec$default_inside_anchor[[4]]
    ),
    text_position_preset = "bottom-left",
    median_x = 0.98,
    median_y = 0.95,
    stats_x = 0.02,
    stats_y = 0.95,
    median_label_text = "mPFS",
    hr_reference = NULL,
    strata_labels = list(),
    overall_group_label = "all",
    plot_title = "",
    plot_caption = "",
    plot_xlab = "Duration",
    plot_ylab = ""
  )
  view_state <- reactiveValues(
    km_time = NULL,
    km_status = NULL,
    time_range = NULL,
    km_strata = "None",
    km_facet = "None",
    km_facet_values = NULL
  )
  committed_params <- reactiveVal(NULL)
  size_config <- reactive({
    graphics_collect_size_config(input)
  })
  
  observe({
    req(data())
    categorical_vars <- get_categorical_vars(data(), include_logical = TRUE)
    numeric_vars <- get_numeric_vars(data())
    default_time <- if (length(numeric_vars) >= 1) numeric_vars[1] else NULL
    default_status <- if (length(numeric_vars) >= 2) numeric_vars[2] else default_time
    current_time_choice <- .resolve_survival_choice(input$km_time, view_state$km_time, numeric_vars, default_time)
    current_status_choice <- .resolve_survival_choice(input$km_status, view_state$km_status, numeric_vars, default_status)
    strata_choices <- c("无" = "None", categorical_vars)
    curr_strata <- .resolve_survival_choice(input$strata_var, view_state$km_strata, c("None", categorical_vars), "None")
    facet_choices <- c("无" = "None", categorical_vars)
    curr_facet <- .resolve_survival_choice(input$facet_var, view_state$km_facet, c("None", categorical_vars), "None")
    isolate({
      updateSelectizeInput(session, "km_time", choices = numeric_vars, selected = current_time_choice)
      updateSelectizeInput(session, "km_status", choices = numeric_vars, selected = current_status_choice)
      updateSelectizeInput(session, "strata_var", choices = strata_choices, selected = curr_strata)
      updateSelectizeInput(session, "facet_var", choices = facet_choices, selected = curr_facet)
    })
  })
  
  # 强制初始化默认值（在数据可用时立即设置状态）
  observeEvent(data(), {
    req(data())
    isolate({
      current_data <- data()
      if(!is.null(current_data) && nrow(current_data) > 0) {
        numeric_vars <- get_numeric_vars(current_data)
        if(length(numeric_vars) >= 2) {
          # 只有在当前状态为NULL时才设置默认值
          if(is.null(graphics_state$km_time) || !graphics_state$km_time %in% names(current_data)) {
            graphics_state$km_time <- numeric_vars[1]
          }
          if(is.null(graphics_state$km_status) || !graphics_state$km_status %in% names(current_data)) {
            graphics_state$km_status <- numeric_vars[2]
          }
          if(is.null(view_state$km_time) || !view_state$km_time %in% names(current_data)) {
            view_state$km_time <- numeric_vars[1]
          }
          if(is.null(view_state$km_status) || !view_state$km_status %in% names(current_data)) {
            view_state$km_status <- numeric_vars[2]
          }
        } else if(length(numeric_vars) == 1) {
          if(is.null(graphics_state$km_time) || !graphics_state$km_time %in% names(current_data)) {
            graphics_state$km_time <- numeric_vars[1]
          }
          if(is.null(graphics_state$km_status) || !graphics_state$km_status %in% names(current_data)) {
            graphics_state$km_status <- numeric_vars[1]
          }
          if(is.null(view_state$km_time) || !view_state$km_time %in% names(current_data)) {
            view_state$km_time <- numeric_vars[1]
          }
          if(is.null(view_state$km_status) || !view_state$km_status %in% names(current_data)) {
            view_state$km_status <- numeric_vars[1]
          }
        }
      }
    })
  })
  
  # 在会话开始时也尝试设置默认值
  observe({
    req(data())
    # 确保变量选择框已填充选项后设置默认选择
    current_data <- data()
    if(!is.null(current_data) && nrow(current_data) > 0 && is.null(input$km_time) && is.null(graphics_state$km_time)) {
      numeric_vars <- get_numeric_vars(current_data)
      if(length(numeric_vars) >= 1) {
        graphics_state$km_time <- numeric_vars[1]
        view_state$km_time <- numeric_vars[1]
      }
      if(length(numeric_vars) >= 2) {
        graphics_state$km_status <- numeric_vars[2]
        view_state$km_status <- numeric_vars[2]
      }
    }
  })
  
  
  # 动态分面值选择器UI
  output$facet_value_ui <- renderUI({
    req(data())
    
    if (!is.null(input$facet_var) && input$facet_var != "None" && input$facet_var %in% names(data())) {
      # 获取分面变量的唯一值
      facet_col <- data()[[input$facet_var]]
      facet_values <- unique(facet_col)
      facet_values <- facet_values[!is.na(facet_values)]
      
      # 转换为字符向量
      facet_values_char <- as.character(facet_values)
      # 过滤空值
      facet_values_char <- facet_values_char[facet_values_char != ""]
      
      # 创建选择列表，只包含实际的分面值（不包含"全部"）
      choices <- facet_values_char
      if (length(choices) > 0) {
        # 用当前可用选项决定分面值选择，避免旧 state 残留造成无效选项
        selectInput(ns("facet_value"), "分面值选择", choices = choices)
      } else {
        selectInput(ns("facet_value"), "分面值选择", choices = NULL)
      }
    } else {
      NULL
    }
  })
  
  # 动态HR参考组选择UI
  output$hr_reference_ui <- renderUI({
    req(data())
    
    if (!is.null(input$strata_var) && input$strata_var != "None" && input$strata_var %in% names(data())) {
      # 获取分层变量的唯一值
      strata_col <- data()[[input$strata_var]]
      strata_values <- unique(strata_col)
      strata_values <- strata_values[!is.na(strata_values)]
      
      # 转换为字符向量
      strata_values_char <- as.character(strata_values)
      # 过滤空值
      strata_values_char <- strata_values_char[strata_values_char != ""]
      
      if (length(strata_values_char) > 1) {
        selectInput(
          ns("hr_reference"),
          "HR参考组（与其他组比较）",
          choices = c("无（自动选择第一组）" = "auto", strata_values_char),
          selected = if(is.null(graphics_state$hr_reference) || !graphics_state$hr_reference %in% c("auto", strata_values_char)) "auto" else graphics_state$hr_reference
        )
      } else {
        NULL
      }
    } else {
      NULL
    }
  })
  
  # 动态分层变量标签映射UI
  output$strata_labels_ui <- renderUI({
    req(data())
    
    if (!is.null(input$strata_var) && input$strata_var != "None" && input$strata_var %in% names(data())) {
      # 获取分层变量的唯一值
      strata_col <- data()[[input$strata_var]]
      strata_values <- unique(strata_col)
      strata_values <- strata_values[!is.na(strata_values)]
      
      # 转换为字符向量
      strata_values_char <- as.character(strata_values)
      # 过滤空值
      strata_values_char <- strata_values_char[strata_values_char != ""]
      
      if (length(strata_values_char) > 0) {
        # 为每个值创建一个文本输入框
        tagList(
          h5("为每个分层值设置自定义标签"),
          p("留空则使用原始值"),
          lapply(strata_values_char, function(val) {
            textInput(ns(.survival_strata_label_input_id(val)),
                     label = paste("值:", val),
                     value = "",
                     placeholder = val)
          })
        )
      } else {
        p("没有可用的分层值")
      }
    } else {
      NULL
    }
  })
  
  observeEvent(input$render_km_plot, {
    progress_id <- graphics_progress_start("生存分析")
    ok <- FALSE
    err <- NULL
    on.exit({
      graphics_progress_end(progress_id)
      if (ok) {
        graphics_notify_success("生存分析")
      } else if (!is.null(err)) {
        graphics_notify_error("生存分析", err)
      }
    }, add = TRUE)
    tryCatch({
      withProgress(message = "Generating survival plot...", value = 0, {
        graphics_progress_update(progress_id, "生存分析", "提交参数", 0.2)
        incProgress(0.2, detail = "Committing UI state")
        req(data())
        current_data <- data()
        numeric_vars <- get_numeric_vars(current_data)
        categorical_vars <- get_categorical_vars(current_data, include_logical = TRUE)
        default_time <- if (length(numeric_vars) >= 1) numeric_vars[1] else NULL
        default_status <- if (length(numeric_vars) >= 2) numeric_vars[2] else default_time
        km_time <- .resolve_survival_choice(input$km_time, view_state$km_time, numeric_vars, default_time)
        km_status <- .resolve_survival_choice(input$km_status, view_state$km_status, numeric_vars, default_status)
        km_strata <- .resolve_survival_choice(input$strata_var, view_state$km_strata, c("None", categorical_vars), "None")
        km_facet <- .resolve_survival_choice(input$facet_var, view_state$km_facet, c("None", categorical_vars), "None")
        if (is.null(km_time) || !km_time %in% names(current_data)) stop("请选择有效的时间变量")
        if (is.null(km_status) || !km_status %in% names(current_data)) stop("请选择有效的状态变量")
        km_facet_values <- NULL
        if (!is.null(km_facet) && km_facet != "None") {
          facet_choices <- unique(as.character(current_data[[km_facet]]))
          facet_choices <- facet_choices[!is.na(facet_choices) & facet_choices != ""]
          km_facet_values <- .resolve_survival_choice(input$facet_value, view_state$km_facet_values, facet_choices, facet_choices[1] %||% NULL)
          if (is.null(km_facet_values) || !km_facet_values %in% facet_choices) stop("请选择有效的分面值")
        }
        overall_group_label <- graphics_text_or_default(input$overall_group_label, default = "all", allow_blank_string = TRUE)
        if (identical(overall_group_label, "")) overall_group_label <- "all"
        strata_labels <- list()
        if (!is.null(km_strata) && km_strata != "None") {
          strata_col <- current_data[[km_strata]]
          strata_values <- unique(strata_col)
          strata_values <- strata_values[!is.na(strata_values)]
          strata_values_char <- as.character(strata_values)
          strata_values_char <- strata_values_char[strata_values_char != ""]
          for (val in strata_values_char) {
            input_name <- .survival_strata_label_input_id(val)
            if (!is.null(input[[input_name]])) {
              strata_labels[[val]] <- input[[input_name]]
            }
          }
        }
        params <- list(
          km_time = km_time,
          km_status = km_status,
          time_range = input$time_range,
          km_strata = km_strata,
          km_facet = km_facet,
          km_facet_values = km_facet_values,
          km_censor_value = input$km_censor_value,
          km_show_censor = input$km_show_censor,
          km_show_risktable = input$km_show_risktable,
          risk_table_height_ratio = input$risk_table_height_ratio,
          risk_table_plot_gap = input$risk_table_plot_gap,
          risk_table_group_gap = input$risk_table_group_gap,
          surv_median_line = input$surv_median_line,
          km_line_size = input$line_size,
          km_line_type = input$line_type,
          km_censor_size = input$km_censor_size,
          km_censor_shape = input$km_censor_shape,
          y_text_size = input$y_text_size,
          title_size = input$title_size,
          caption_size = input$caption_size,
          xlab_size = input$xlab_size,
          ylab_size = input$ylab_size,
          y_break_step = input$y_break_step,
          y_decimals = input$y_decimals,
          y_as_percent = input$y_as_percent,
          y_show_percent_sign = input$y_show_percent_sign,
          axis_style = input$axis_style,
          base_family = input$base_family,
          cjk_family = input$cjk_family %||% "Noto Sans SC",
          axis_text_size = input$axis_text_size,
          legend_text_size = input$legend_text_size,
          stats_text_size = input$stats_text_size,
          risk_table_fontsize = input$risk_table_fontsize,
          risk_table_fontbold = input$risk_table_fontbold,
          show_grid = input$show_grid,
          time_step = input$time_step,
          show_median = input$show_median,
          show_stats = input$show_stats,
          show_cox_p = input$show_cox_p,
          legend_position = input$legend_position,
          legend_title = input$legend_title,
          legend_row_gap = input$legend_row_gap,
          legend_inside_anchor = graphics_resolve_inside_anchor(
            x_ratio = input$legend_x_ratio %||% .survival_aux_legend_compact_spec$default_inside_anchor[[1]],
            y_ratio = input$legend_y_ratio %||% .survival_aux_legend_compact_spec$default_inside_anchor[[2]],
            width_ratio = input$legend_width_ratio %||% .survival_aux_legend_compact_spec$default_inside_anchor[[3]],
            height_ratio = input$legend_height_ratio %||% .survival_aux_legend_compact_spec$default_inside_anchor[[4]]
          ),
          text_position_preset = input$text_position_preset,
          median_x = input$median_x,
          median_y = input$median_y,
          stats_x = input$stats_x,
          stats_y = input$stats_y,
          median_label_text = .resolve_survival_median_label(input$median_label_text, "mPFS"),
          hr_reference = input$hr_reference,
          strata_labels = strata_labels,
          overall_group_label = overall_group_label,
          plot_title = input$plot_title,
          plot_caption = input$plot_caption,
          plot_xlab = input$plot_xlab,
          plot_ylab = input$plot_ylab
        )
        graphics_state$km_time <- params$km_time
        graphics_state$km_status <- params$km_status
        graphics_state$time_range <- params$time_range
        graphics_state$km_strata <- params$km_strata
        graphics_state$km_facet <- params$km_facet
        graphics_state$km_facet_values <- params$km_facet_values
        graphics_state$km_censor_value <- params$km_censor_value
        graphics_state$km_show_censor <- params$km_show_censor
        graphics_state$km_show_risktable <- params$km_show_risktable
        graphics_state$risk_table_height_ratio <- params$risk_table_height_ratio
        graphics_state$risk_table_plot_gap <- params$risk_table_plot_gap
        graphics_state$risk_table_group_gap <- params$risk_table_group_gap
        graphics_state$km_line_size <- params$km_line_size
        graphics_state$km_line_type <- params$km_line_type
        graphics_state$surv_median_line <- params$surv_median_line
        graphics_state$km_censor_size <- params$km_censor_size
        graphics_state$km_censor_shape <- params$km_censor_shape
        graphics_state$y_text_size <- params$y_text_size
        graphics_state$title_size <- params$title_size
        graphics_state$caption_size <- params$caption_size
        graphics_state$xlab_size <- params$xlab_size
        graphics_state$ylab_size <- params$ylab_size
        graphics_state$y_break_step <- params$y_break_step
        graphics_state$y_decimals <- params$y_decimals
        graphics_state$y_as_percent <- params$y_as_percent
        graphics_state$y_show_percent_sign <- params$y_show_percent_sign
        graphics_state$base_family <- params$base_family
        graphics_state$cjk_family <- params$cjk_family
        graphics_state$axis_text_size <- params$axis_text_size
        graphics_state$axis_style <- params$axis_style
        graphics_state$risk_table_fontsize <- params$risk_table_fontsize
        graphics_state$risk_table_fontbold <- params$risk_table_fontbold
        graphics_state$legend_text_size <- params$legend_text_size
        graphics_state$stats_text_size <- params$stats_text_size
        graphics_state$show_grid <- params$show_grid
        graphics_state$time_step <- params$time_step
        graphics_state$show_median <- params$show_median
        graphics_state$show_stats <- params$show_stats
        graphics_state$show_cox_p <- params$show_cox_p
        graphics_state$legend_position <- params$legend_position
        graphics_state$legend_title <- params$legend_title
        graphics_state$legend_row_gap <- params$legend_row_gap
        graphics_state$legend_inside_anchor <- params$legend_inside_anchor
        graphics_state$text_position_preset <- params$text_position_preset
        graphics_state$median_x <- params$median_x
        graphics_state$median_y <- params$median_y
        graphics_state$stats_x <- params$stats_x
        graphics_state$stats_y <- params$stats_y
        graphics_state$median_label_text <- params$median_label_text
        graphics_state$hr_reference <- params$hr_reference
        graphics_state$strata_labels <- params$strata_labels
        graphics_state$overall_group_label <- params$overall_group_label
        graphics_state$plot_title <- params$plot_title
        graphics_state$plot_caption <- params$plot_caption
        graphics_state$plot_xlab <- params$plot_xlab
        graphics_state$plot_ylab <- params$plot_ylab
        committed_params(params)
        graphics_progress_update(progress_id, "生存分析", "模型拟合", 0.55)
        incProgress(0.35, detail = "Fitting survival model")
        surv_obj()
        fit()
        graphics_progress_update(progress_id, "生存分析", "统计计算", 0.8)
        incProgress(0.25, detail = "Computing statistics")
        surv_summary_data()
        stats_results()
        mapped_strata()
        base_surv_plot()
        graphics_progress_update(progress_id, "生存分析", "图形完成", 1)
        incProgress(0.2, detail = "Completed")
      })
      ok <- TRUE
    }, error = function(e) {
      err <<- e
    })
  })
  
  # 获取过滤后的数据（不再使用 eventReactive，恢复为 reactive，保证下拉框随时更新）
  filtered_data <- reactive({
    req(data())
    df <- data()
    
    # 如果选择了分面变量，则过滤数据
    facet_var_selected <- .resolve_survival_choice(input$facet_var, view_state$km_facet, c("None", names(df)), "None")
    facet_value_selected <- if (!is.null(input$facet_value)) input$facet_value else view_state$km_facet_values
    if (!is.null(facet_var_selected) && facet_var_selected != "None" && facet_var_selected %in% names(df) && !is.null(facet_value_selected)) {
      facet_col <- df[[facet_var_selected]]
      filtered_df <- df[as.character(facet_col) == as.character(facet_value_selected), ]
      return(filtered_df)
    }
    return(df)
  })
  committed_filtered_data <- reactive({
    req(data(), committed_params())
    df <- data()
    params <- committed_params()
    if (!is.null(params$km_facet) && params$km_facet != "None" && params$km_facet %in% names(df) && !is.null(params$km_facet_values)) {
      facet_col <- df[[params$km_facet]]
      return(df[as.character(facet_col) == as.character(params$km_facet_values), , drop = FALSE])
    }
    df
  })

  current_survival_time_var <- reactive({
    req(data())
    current_data <- data()
    numeric_vars <- get_numeric_vars(current_data)
    default_time <- if (length(numeric_vars) >= 1) numeric_vars[1] else NULL
    .resolve_survival_choice(
      input$km_time,
      view_state$km_time %||% graphics_state$km_time,
      numeric_vars,
      default_time
    )
  })
  
  # 动态时间范围滑块UI
  output$time_range_slider <- graphics_render_time_range_slider(
    ns,
    current_survival_time_var,
    data,
    selected_range = reactive(view_state$time_range %||% graphics_state$time_range %||% input$time_range)
  )
  
  extract_median_ci <- function(fit_obj) {
    tbl <- tryCatch(summary(fit_obj)$table, error = function(e) NULL)
    if (is.null(tbl)) return(NULL)
    if (is.null(dim(tbl))) {
      tbl <- t(as.matrix(tbl))
      rownames(tbl) <- "all"
    } else {
      tbl <- as.matrix(tbl)
    }
    cn <- colnames(tbl)
    med_col <- if ("median" %in% cn) "median" else grep("median", cn, ignore.case = TRUE, value = TRUE)[1]
    low_col <- if ("0.95LCL" %in% cn) "0.95LCL" else grep("LCL|lower", cn, ignore.case = TRUE, value = TRUE)[1]
    up_col <- if ("0.95UCL" %in% cn) "0.95UCL" else grep("UCL|upper", cn, ignore.case = TRUE, value = TRUE)[1]
    if (any(is.na(c(med_col, low_col, up_col)))) return(NULL)
    strata_name <- rownames(tbl)
    if (is.null(strata_name)) strata_name <- rep("all", nrow(tbl))
    data.frame(
      strata = strata_name,
      median = as.numeric(tbl[, med_col]),
      lower = as.numeric(tbl[, low_col]),
      upper = as.numeric(tbl[, up_col]),
      stringsAsFactors = FALSE
    )
  }

  # 创建生存对象（仅在点击“生成图形”后更新）
  surv_obj <- reactive({
    params <- committed_params()
    req(params)
    data <- committed_filtered_data()
    req(data)
    time_var_name <- params$km_time
    status_var_name <- params$km_status
    shiny::validate(
      shiny::need(time_var_name %in% names(data), "请选择有效的时间变量"),
      shiny::need(status_var_name %in% names(data), "请选择有效的状态变量"),
      shiny::need(nrow(data) > 0, "选择的分面值没有数据")
    )
    time_var <- data[[time_var_name]]
    status_var <- data[[status_var_name]]
    if (params$km_censor_value == "1") {
      status_var <- ifelse(status_var == 1, 0, ifelse(status_var == 0, 1, status_var))
    }
    unique_status <- unique(status_var)
    valid_status <- unique_status[!is.na(unique_status)]
    if (!all(valid_status %in% c(0, 1))) {
      min_status <- min(valid_status, na.rm = TRUE)
      status_var <- ifelse(status_var == min_status, 0, 1)
    }
    Surv(time_var, status_var)
  })
  
  fit <- reactive({
    params <- committed_params()
    req(params)
    req(surv_obj())
    data <- committed_filtered_data()
    req(data)
    
    if (nrow(data) == 0) {
      stop("没有足够的数据进行生存分析")
    }
    if (any(is.na(surv_obj()))) {
      stop("生存对象包含无效值")
    }
    strata_var <- params$km_strata
    if (is.null(strata_var) || strata_var == "None") {
      surv_fit(surv_obj() ~ 1, data = data, conf.type = "log-log")
    } else {
      shiny::validate(
        shiny::need(strata_var %in% names(data), "请选择有效的分层变量"),
        shiny::need(nrow(data) > 0, "选择的分面值没有数据")
      )
      formula_str <- paste("surv_obj() ~", strata_var)
      surv_fit(as.formula(formula_str), data = data, conf.type = "log-log")
    }
  })
  
  surv_summary_data <- reactive({
    req(fit())
    surv_summary(fit())
  })
  
  stats_results <- reactive({
    params <- committed_params()
    req(params)
    req(fit())
    data <- committed_filtered_data()
    req(data)
    
    res <- list(
      median_surv = extract_median_ci(fit()),
      logrank_p = NA_real_,
      hr_lines = character(0)
    )
    
    strata_var <- params$km_strata
    if (!is.null(strata_var) && strata_var != "None" && strata_var %in% names(data)) {
      try({
        sd <- survdiff(surv_obj() ~ data[[strata_var]], data = data)
        res$logrank_p <- pchisq(sd$chisq, length(sd$n) - 1, lower.tail = FALSE)
      }, silent = TRUE)
      try({
        strata_data <- data[[strata_var]]
        strata_levels <- unique(strata_data)
        reference_level <- if (!is.null(params$hr_reference) && params$hr_reference != "auto") {
          params$hr_reference
        } else {
          as.character(strata_levels[1])
        }
        strata_fac <- factor(strata_data)
        if (reference_level %in% levels(strata_fac)) {
          strata_fac <- relevel(strata_fac, ref = reference_level)
        }
        cox_fit <- coxph(surv_obj() ~ strata_fac, data = data)
        csum <- summary(cox_fit)
        
        if (!is.null(csum$coefficients) && nrow(csum$coefficients) > 0) {
          labels <- params$strata_labels
          map_label <- function(x) {
            stripped <- .strip_survival_strata_value(x, strata_var)
            if (stripped %in% names(labels) && labels[[stripped]] != "") return(labels[[stripped]])
            stripped
          }
          
          for (i in seq_len(nrow(csum$coefficients))) {
            hr <- exp(csum$coefficients[i, 1])
            hr_low <- exp(csum$coefficients[i, 1] - 1.96 * csum$coefficients[i, 3])
            hr_up <- exp(csum$coefficients[i, 1] + 1.96 * csum$coefficients[i, 3])
            p_val <- csum$coefficients[i, 5]
            
            contrast_name <- rownames(csum$coefficients)[i]
            contrast_clean <- gsub("^.*?([^.]+)$", "\\1", contrast_name)
            if (grepl("strata_fac", contrast_name)) contrast_clean <- gsub("strata_fac", "", contrast_name)
            
            contrast_mapped <- map_label(contrast_clean)
            reference_mapped <- map_label(reference_level)
            
            hr_line <- .build_survival_hr_summary_line(
              contrast_label = contrast_mapped,
              reference_label = reference_mapped,
              hr = hr,
              hr_low = hr_low,
              hr_up = hr_up,
              p_val = p_val,
              show_cox_p = isTRUE(params$show_cox_p)
            )
            res$hr_lines <- c(res$hr_lines, hr_line)
          }
        }
      }, silent = TRUE)
    }
    
    res
  })
  
  observeEvent(input$km_time, {
    if (!is.null(input$km_time) && nzchar(input$km_time)) {
      view_state$km_time <- input$km_time
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$km_status, {
    if (!is.null(input$km_status) && nzchar(input$km_status)) {
      view_state$km_status <- input$km_status
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$strata_var, {
    if (!is.null(input$strata_var) && nzchar(input$strata_var)) {
      view_state$km_strata <- input$strata_var
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$facet_var, {
    if (!is.null(input$facet_var) && nzchar(input$facet_var)) {
      view_state$km_facet <- input$facet_var
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$facet_value, {
    view_state$km_facet_values <- input$facet_value
  }, ignoreInit = TRUE)

  observeEvent(input$time_range, {
    if (!is.null(input$time_range) && length(input$time_range) == 2) {
      view_state$time_range <- input$time_range
    }
  }, ignoreInit = TRUE)
  
  # 获取标签映射后的分层变量值
  mapped_strata <- reactive({
    params <- committed_params()
    req(params)
    data <- committed_filtered_data()
    req(data)
    strata_var <- params$km_strata
    if (is.null(strata_var) || strata_var == "None" || !strata_var %in% names(data)) return(NULL)
    strata_col <- data[[strata_var]]
    strata_values <- as.character(strata_col)
    
    # 应用标签映射
    labels <- params$strata_labels
    if (length(labels) > 0) {
      for (orig in names(labels)) {
        if (labels[[orig]] != "") {
          strata_values[strata_values == orig] <- labels[[orig]]
        }
      }
    }
    return(strata_values)
  })
  
  base_surv_plot <- reactive({
    params <- committed_params()
    req(params, fit())
    data <- committed_filtered_data()
    req(data)
    time_var_name <- params$km_time
    status_var_name <- params$km_status
    strata_var <- params$km_strata
    overall_label <- params$overall_group_label %||% "all"
    time_range <- if (!is.null(params$time_range) && length(params$time_range) == 2) {
      suppressWarnings(as.numeric(params$time_range))
    } else {
      time_max <- max(data[[time_var_name]], na.rm = TRUE)
      c(0, time_max + 30)
    }
    time_step <- if (!is.null(params$time_step) && !is.na(params$time_step) && params$time_step > 0) params$time_step else round((time_range[2] - time_range[1]) / 10)
    plot_data <- data
    if (!is.null(strata_var) && strata_var != "None" && length(params$strata_labels) > 0) {
      strata_col <- plot_data[[strata_var]]
      strata_values <- as.character(strata_col)
      for (orig in names(params$strata_labels)) {
        if (params$strata_labels[[orig]] != "") {
          strata_values[strata_values == orig] <- params$strata_labels[[orig]]
        }
      }
      plot_data[[strata_var]] <- factor(strata_values, levels = unique(strata_values))
    }
    if (!is.null(strata_var) && strata_var != "None" && length(params$strata_labels) > 0) {
      time_var <- plot_data[[time_var_name]]
      status_var <- plot_data[[status_var_name]]
      if (params$km_censor_value == "1") {
        status_var <- ifelse(status_var == 1, 0, ifelse(status_var == 0, 1, status_var))
      }
      unique_status <- unique(status_var)
      valid_status <- unique_status[!is.na(unique_status)]
      if (!all(valid_status %in% c(0, 1))) {
        min_status <- min(valid_status, na.rm = TRUE)
        status_var <- ifelse(status_var == min_status, 0, 1)
      }
      surv_obj_local <- Surv(time_var, status_var)
      fit_local <- surv_fit(as.formula(paste("surv_obj_local ~", strata_var)), data = plot_data, conf.type = "log-log")
    } else {
      fit_local <- fit()
    }
    legend_title_text <- graphics_resolve_legend_title(params$legend_title, "", "")
    plot_family <- .resolve_survival_base_family(params$base_family %||% "sans", cjk_family = params$cjk_family %||% "Noto Sans SC")
    legend_breaks <- .extract_survival_legend_breaks(fit_local, strata_var, overall_label)
    legend_labs <- .extract_survival_legend_labs(fit_local, strata_var, params$strata_labels, overall_label)
    legend_colors_raw <- .build_survival_legend_colors(legend_breaks, palette_name = "Set1")
    palette_values <- unname(legend_colors_raw[legend_breaks])
    if (length(palette_values) == 0) {
      palette_values <- scales::hue_pal()(max(1, length(legend_breaks)))
    }
    risk_table_labeler <- .build_survival_strata_labeler(strata_var, params$strata_labels, overall_label)
    p <- suppressWarnings(ggsurvplot(
        fit_local,
        data = plot_data,
        risk.table = params$km_show_risktable,
        fontsize = .resolve_survival_risk_table_geom_size(params$risk_table_fontsize %||% 10, fallback = 10),
        font.tickslab = c(.resolve_survival_text_size_pt(params$y_text_size %||% 10, fallback = 10), "plain"),
        surv.median.line = params$surv_median_line %||% "none",
        conf.int = FALSE,
        pval = FALSE,
        censor = FALSE,
        xlim = time_range,
        break.time.by = time_step,
        ggtheme = theme_bw(),
        palette = palette_values,
        legend.title = legend_title_text,
        legend.labs = legend_labs,
        font.family = plot_family
      ))
      if (params$km_show_risktable && !is.null(p$table)) {
        p$table <- .apply_survival_risk_table_text_style(
          risk_table_plot = p$table,
          number_size_pt = params$risk_table_fontsize %||% 10,
          y_text_size = params$y_text_size %||% 10,
          base_family = plot_family,
          cjk_family = params$cjk_family %||% "Noto Sans SC",
          bold = isTRUE(params$risk_table_fontbold)
        )
      }
    main_legend_colors <- stats::setNames(unname(legend_colors_raw[legend_breaks]), legend_labs)
    if (params$show_median) {
      median_surv <- stats_results()$median_surv
      if (!is.null(median_surv) && nrow(median_surv) > 0) {
        median_surv$display_strata <- vapply(
          median_surv$strata,
          function(x) .format_survival_group_label(x, strata_var, params$strata_labels, overall_label),
          character(1)
        )
        median_surv$median_txt <- ifelse(is.finite(median_surv$median), formatC(median_surv$median, format = "f", digits = 1), "NR")
          median_surv$lower_txt <- ifelse(is.finite(median_surv$lower), formatC(median_surv$lower, format = "f", digits = 1), "NA")
          median_surv$upper_txt <- ifelse(is.finite(median_surv$upper), formatC(median_surv$upper, format = "f", digits = 1), "NA")
        median_surv$label <- vapply(
          seq_len(nrow(median_surv)),
          function(i) .build_survival_median_summary_label(
            display_strata = median_surv$display_strata[i],
            median_label = params$median_label_text,
            median_txt = median_surv$median_txt[i],
            lower_txt = median_surv$lower_txt[i],
            upper_txt = median_surv$upper_txt[i],
            overall_label = overall_label
          ),
          character(1)
        )
        preset <- params$text_position_preset
        n_groups <- nrow(median_surv)
        if (preset == "auto" || preset == "bottom-left") {
          x_pos <- min(time_range) + 0.02 * diff(time_range)
          y_positions <- .build_survival_annotation_y_positions(0.4, n_groups, 0.05)
        } else if (preset == "top-left") {
          x_pos <- min(time_range) + 0.02 * diff(time_range)
          y_positions <- .build_survival_annotation_y_positions(0.95, n_groups, 0.6)
        } else if (preset == "top-right") {
          x_pos <- max(time_range) * 0.98
          y_positions <- .build_survival_annotation_y_positions(0.95, n_groups, 0.6)
        } else if (preset == "bottom-right") {
          x_pos <- max(time_range) * 0.98
          y_positions <- .build_survival_annotation_y_positions(0.4, n_groups, 0.05)
        } else {
          x_pos <- min(time_range) + params$median_x * diff(time_range)
          y_positions <- params$median_y - seq(0, n_groups - 1) * .survival_annotation_line_gap()
        }
        median_surv$x <- x_pos
        median_surv$y <- y_positions
        p$plot <- p$plot +
          geom_text(
            data = median_surv,
            aes(x = x, y = y, label = label),
            hjust = .survival_median_text_hjust(),
            vjust = 0.5,
            size = params$stats_text_size / 3.2,
            color = "black",
            fontface = "bold",
            family = plot_family
          )
      }
    }
    if (params$show_stats) {
      logrank_p <- stats_results()$logrank_p
      stats_text <- ""
      if (!is.na(logrank_p)) stats_text <- .compose_survival_p_text("Log-rank P", logrank_p)
      if (!is.null(strata_var) && strata_var != "None") {
        hr_lines <- stats_results()$hr_lines
        if (length(hr_lines) > 0) {
          if (stats_text != "") stats_text <- paste0(stats_text, "\n")
          stats_text <- paste0(stats_text, paste(hr_lines, collapse = "\n"))
        }
      }
      preset <- params$text_position_preset
      if (preset == "auto" || preset == "bottom-left") {
        stats_x <- min(time_range) + 0.02 * diff(time_range); stats_y <- 0.05; hjust_val <- 0; vjust_val <- 0
      } else if (preset == "top-left") {
        stats_x <- min(time_range) + 0.02 * diff(time_range); stats_y <- 0.95; hjust_val <- 0; vjust_val <- 1
      } else if (preset == "top-right") {
        stats_x <- max(time_range) * 0.98; stats_y <- 0.95; hjust_val <- 1; vjust_val <- 1
      } else if (preset == "bottom-right") {
        stats_x <- max(time_range) * 0.98; stats_y <- 0.05; hjust_val <- 1; vjust_val <- 0
      } else {
        stats_x <- min(time_range) + params$stats_x * diff(time_range)
        stats_y <- params$stats_y
        hjust_val <- ifelse(params$stats_x < 0.5, 0, 1)
        vjust_val <- ifelse(params$stats_y < 0.5, 0, 1)
      }
      if (stats_text != "") {
        p$plot <- p$plot +
          annotate("text", x = stats_x, y = stats_y, label = stats_text, hjust = hjust_val, vjust = vjust_val, 
                   size = params$stats_text_size / 3.2, color = "black", fontface = "bold", family = plot_family)
      }
    }
    censor_legend_plot <- NULL
    if (isTRUE(params$km_show_censor)) {
      surv_data <- surv_summary(fit_local)
      censored_points <- surv_data[surv_data$n.censor > 0, ]
      if (nrow(censored_points) > 0) {
        if ("strata" %in% names(censored_points) && !is.null(strata_var) && strata_var != "None") {
          censored_points$strata_display <- vapply(
            as.character(censored_points$strata),
            function(x) .format_survival_group_label(x, strata_var, params$strata_labels, overall_label),
            character(1)
          )
          censor_pairs <- unique(data.frame(
            raw = as.character(censored_points$strata),
            display = as.character(censored_points$strata_display),
            stringsAsFactors = FALSE
          ))
          censor_pairs <- censor_pairs[match(legend_labs, censor_pairs$display, nomatch = 0), , drop = FALSE]
          if (nrow(censor_pairs) == 0) {
            censor_pairs <- unique(data.frame(
              raw = as.character(censored_points$strata),
              display = as.character(censored_points$strata_display),
              stringsAsFactors = FALSE
            ))
          }
          censor_breaks <- censor_pairs$display
          censor_colors <- stats::setNames(unname(main_legend_colors[censor_breaks]), censor_breaks)
          if (length(censor_colors) != length(censor_breaks) || any(is.na(censor_colors) | !nzchar(censor_colors))) {
            censor_colors <- stats::setNames(unname(legend_colors_raw[censor_pairs$raw]), censor_breaks)
          }
          censored_points$color_value <- .resolve_survival_censor_point_colors(
            raw_strata = censored_points$strata,
            display_strata = censored_points$strata_display,
            main_legend_colors = main_legend_colors,
            fallback_colors = stats::setNames(unname(legend_colors_raw[legend_breaks]), legend_breaks)
          )
          p$plot <- p$plot +
            geom_point(
              data = censored_points,
              aes(x = time, y = surv),
              shape = .resolve_survival_censor_shape_value(params$km_censor_shape),
              size = params$km_censor_size,
              color = censored_points$color_value,
              alpha = 1,
              inherit.aes = FALSE,
              show.legend = FALSE
            )
          censor_legend_plot <- .build_survival_censor_legend_plot(
            labels = censor_breaks,
            colors = censor_colors,
            shape_value = as.numeric(params$km_censor_shape),
            title = "Censor",
            base_font_size = params$legend_text_size,
            row_gap = params$legend_row_gap %||% 1.0,
            font_family = plot_family
          )
          p$censor_rows <- length(censor_breaks)
        } else {
          censor_label <- overall_label %||% "all"
          censored_points$censor_label <- censor_label
          p$plot <- p$plot +
            geom_point(
              data = censored_points,
              aes(x = time, y = surv),
              shape = .resolve_survival_censor_shape_value(params$km_censor_shape),
              size = params$km_censor_size,
              color = "black",
              alpha = 1,
              inherit.aes = FALSE,
              show.legend = FALSE
            )
          censor_legend_plot <- .build_survival_censor_legend_plot(
            labels = censor_label,
            colors = stats::setNames("black", censor_label),
            shape_value = as.numeric(params$km_censor_shape),
            title = "Censor",
            base_font_size = params$legend_text_size,
            row_gap = params$legend_row_gap %||% 1.0,
            font_family = plot_family
          )
          p$censor_rows <- 1
        }
      }
    }
    p$plot <- p$plot + guides(
      colour = guide_legend(order = 1),
      shape = "none",
      alpha = "none",
      size = "none",
      linewidth = "none"
    )
    p$plot <- .apply_survival_line_style(p$plot, params$km_line_size, params$km_line_type)
    if (!params$show_grid) {
      p$plot <- p$plot + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
    }
    
    y_step <- suppressWarnings(as.numeric(params$y_break_step %||% 0.25))
    if (is.na(y_step) || y_step <= 0) y_step <- 0.25
    if (isTRUE(params$y_as_percent)) {
      p$plot <- suppressWarnings(p$plot + scale_y_continuous(
        breaks = seq(0, 1, by = y_step), 
        labels = graphics_format_percent_labels(show_percent_sign = isTRUE(params$y_show_percent_sign), scale_factor = 100, decimals = params$y_decimals %||% 2)
      ))
    } else {
      p$plot <- suppressWarnings(p$plot + scale_y_continuous(
        breaks = seq(0, 1, by = y_step),
        labels = graphics_format_number_labels(decimals = params$y_decimals %||% 2)
      ))
    }
    
    p$plot <- p$plot +
      theme(
        text = element_text(family = plot_family),
        panel.border = element_blank(),
        axis.text = element_text(size = params$axis_text_size),
        legend.text = element_text(size = params$legend_text_size)
      )
    p$plot <- graphics_apply_axis_style(p$plot, params$axis_style %||% "default", arrow_size = 0.15)
    if (!is.null(params$plot_title) && nzchar(params$plot_title %||% "")) {
      p$plot <- p$plot + labs(title = gsub("\\\\n", "\n", params$plot_title))
    }
    if (!is.null(params$plot_xlab) && nzchar(params$plot_xlab %||% "")) {
      p$plot <- p$plot + labs(x = gsub("\\\\n", "\n", params$plot_xlab))
    } else {
      p$plot <- p$plot + labs(x = time_var_name)
    }
    if (!is.null(params$plot_ylab) && nzchar(params$plot_ylab %||% "")) {
      p$plot <- p$plot + labs(y = gsub("\\\\n", "\n", params$plot_ylab))
    } else {
      p$plot <- p$plot + labs(y = "Survival Probability")
    }
    if (params$km_show_risktable && !is.null(p$table)) {
      risk_table_scale <- .resolve_survival_risk_table_scale(p$table, risk_table_labeler)
      p$table <- p$table +
        theme_minimal() +
        theme(
          text = element_text(family = plot_family, face = "plain"),
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          plot.margin = margin(params$risk_table_plot_gap, 0, 0, 0, "pt")
        )
      group_gap <- params$risk_table_group_gap %||% 1.2
      p$table <- p$table + scale_y_discrete(
        breaks = risk_table_scale$breaks,
        labels = risk_table_scale$labels,
        expand = expansion(mult = c(group_gap, group_gap))
      )
      p$table <- .apply_survival_risk_table_text_style(
        risk_table_plot = p$table,
        number_size_pt = params$risk_table_fontsize %||% 10,
        y_text_size = params$y_text_size %||% 10,
        base_family = plot_family,
        cjk_family = params$cjk_family %||% "Noto Sans SC",
        bold = isTRUE(params$risk_table_fontbold)
      )
    }
    p$main_legend_labels <- unname(legend_labs)
    p$main_legend_colors <- main_legend_colors
    p$main_legend_title <- legend_title_text
    p$censor_legend_plot <- censor_legend_plot
    p
  })
  
  # 创建组合的静态生存曲线图
  create_surv_plot <- function() {
    params <- committed_params()
    req(params)
    p <- base_surv_plot()
    plot_family <- .resolve_survival_base_family(params$base_family %||% "sans", cjk_family = params$cjk_family %||% "Noto Sans SC")
    p$plot <- p$plot + theme(legend.position = "none")
    main_legend_plot <- .build_survival_line_legend_plot(
      labels = p$main_legend_labels,
      colors = p$main_legend_colors,
      title = p$main_legend_title,
      line_size = params$km_line_size,
      line_type = params$km_line_type,
      base_font_size = params$legend_text_size,
      row_gap = params$legend_row_gap %||% 1.0,
      font_family = plot_family
    )
    legend_bundle <- .compose_survival_static_legend(
      main_legend_plot = main_legend_plot,
      censor_legend_plot = p$censor_legend_plot,
      legend_position = params$legend_position,
      inside_anchor = params$legend_inside_anchor,
      primary_rows = length(p$main_legend_labels),
      secondary_rows = if (is.null(p$censor_legend_plot)) 0 else (p$censor_rows %||% 1)
    )
    
    if (params$km_show_risktable && !is.null(p$table)) {
      plot_list <- list(p$plot, p$table)
      
      risk_ratio <- params$risk_table_height_ratio %||% 0.15
      plot_ratio <- 1 - risk_ratio
      
      if (!is.null(params$plot_caption) && nzchar(params$plot_caption %||% "")) {
        formatted_caption <- gsub("\\\\n", "\n", params$plot_caption)
        caption_plot <- ggplot() +
          theme_void() +
          labs(caption = formatted_caption) +
          theme(plot.caption = element_text(hjust = 0, vjust = 0, size = params$caption_size, family = plot_family))
        
        plot_list <- c(plot_list, list(caption_plot))
        rel_heights <- c(plot_ratio, risk_ratio, 0.08)
      } else {
        rel_heights <- c(plot_ratio, risk_ratio)
      }
      
      combined_plot <- plot_grid(
        plotlist = plot_list,
        ncol = 1,
        align = "v",
        axis = "lr",
        rel_heights = rel_heights
      )
      if (!is.null(legend_bundle$legend_plot) && !identical(legend_bundle$layout$position, "none")) {
        combined_plot <- graphics_place_aux_legend(
          combined_plot,
          legend_bundle$legend_plot,
          position = legend_bundle$layout$position,
          outside_ratio = 0.32,
          inside_anchor = legend_bundle$layout$anchor %||% c(0.72, 0.03, 0.26, 0.26)
        )
      }
      combined_plot
    } else {
      if (!is.null(params$plot_caption) && nzchar(params$plot_caption %||% "")) {
        formatted_caption <- gsub("\\\\n", "\n", params$plot_caption)
        p$plot <- p$plot + labs(caption = formatted_caption) +
          theme(plot.caption = element_text(hjust = 0, vjust = 1, size = params$caption_size, family = plot_family))
      }
      if (!is.null(legend_bundle$legend_plot) && !identical(legend_bundle$layout$position, "none")) {
        p$plot <- graphics_place_aux_legend(
          p$plot,
          legend_bundle$legend_plot,
          position = legend_bundle$layout$position,
          outside_ratio = 0.32,
          inside_anchor = legend_bundle$layout$anchor %||% c(0.72, 0.03, 0.26, 0.26)
        )
      }
      p$plot
    }
  }
  
  output$survPlotUI <- renderUI({
    cfg <- size_config()
    graphics_centered_output_container(
      plotOutput(ns("survPlot"), height = paste0(cfg$static_height, "px"), width = "100%"),
      frame_width_px = cfg$static_width,
      frame_height_px = cfg$static_height
    )
  })
  
  output$interactiveSurvPlotUI <- renderUI({
    cfg <- size_config()
    graphics_centered_output_container(
      plotly::plotlyOutput(ns("interactiveSurvPlot"), height = paste0(cfg$interactive_height, "px"), width = "100%"),
      frame_width_px = cfg$interactive_width,
      frame_height_px = cfg$interactive_height,
      canvas_config = cfg,
      use_canvas_border = TRUE
    )
  })
  
  output$survPlot <- renderPlot({
    req(input$render_km_plot) # 确保有点击过生成按钮
    shiny::validate(shiny::need(!is.null(fit()), "请先完成变量设置并点击“生成图形”。"))
    cfg <- size_config()
    graphics_apply_canvas_frame(
      create_surv_plot(),
      frame_width_px = cfg$static_width,
      frame_height_px = cfg$static_height,
      canvas_config = cfg
    )
  }, height = function() size_config()$static_height, width = function() size_config()$static_width)
  
  # 创建专门的交互式生存曲线图
  create_interactive_surv_plot <- function() {
    params <- committed_params()
    req(params)
    plot_family <- .resolve_survival_base_family(params$base_family %||% "sans")
    p <- base_surv_plot()$plot
    p <- graphics_apply_legend_theme(
      p,
      show_legend = !identical(params$legend_position, "none"),
      position = params$legend_position,
      inside_anchor = params$legend_inside_anchor
    )
    
    # 交互式图不需要网格和复杂的自定义主题边框，但这里我们保留大部分原有设置
    # 处理标题（如果之前未自定义，添加默认交互式标题）
    if (is.null(params$plot_title) || !nzchar(params$plot_title %||% "")) {
      if (params$km_facet != "None" && !is.null(params$km_facet_values)) {
        p <- p + labs(title = paste("交互式生存曲线 -", params$km_facet, "=", params$km_facet_values))
      } else {
        p <- p + labs(title = "交互式生存曲线")
      }
    }
    
    # 处理脚注（直接加到主图）
    if (!is.null(params$plot_caption) && nzchar(params$plot_caption %||% "")) {
      formatted_caption <- gsub("\\\\n", "\n", params$plot_caption)
      p <- p + labs(caption = formatted_caption) +
        theme(plot.caption = element_text(hjust = 0, vjust = 1, size = params$caption_size %||% 10, family = plot_family))
    }
    
    return(p)
  }
  
    # 交互式生存曲线图
  output$interactiveSurvPlot <- renderPlotly({
    req(input$render_km_plot)
    shiny::validate(shiny::need(!is.null(fit()), "请先生成生存曲线后查看交互式图。"))
    
    # 创建专门的交互式图形
    interactive_plot <- create_interactive_surv_plot()
    
    # 转换为plotly，避免layout()的width/height弃用警告
    # 移除height参数，因为Shiny的renderPlotly会自动处理容器大小
    # 同时可以尝试手动调整布局以移除已有的width/height属性
    plotly_obj <- ggplotly(interactive_plot, tooltip = c("x", "y", "colour"))
    
    # 手动清理layout中的width和height (如果有)
    plotly_obj$x$layout$width <- size_config()$interactive_width
    plotly_obj$x$layout$height <- size_config()$interactive_height
    plotly_obj <- plotly::layout(
      plotly_obj,
      margin = list(
        l = size_config()$page_margin_left,
        r = size_config()$page_margin_right,
        t = size_config()$page_margin_top,
        b = size_config()$page_margin_bottom
      ),
      paper_bgcolor = size_config()$canvas_background,
      plot_bgcolor = size_config()$canvas_background
    )
    
    return(plotly_obj)
  })

  build_km_summary_df <- function(fit_obj, time_range = NULL, strata_var = NULL, strata_labels = list(), overall_label = "all") {
    surv_summary <- summary(fit_obj, censored = TRUE)
    if (is.null(surv_summary$time) || length(surv_summary$time) == 0) return(NULL)
    surv_df <- data.frame(
      时间 = surv_summary$time,
      组别 = if (!is.null(surv_summary$strata)) as.character(surv_summary$strata) else overall_label,
      风险人数 = surv_summary$n.risk,
      事件数 = surv_summary$n.event,
      删失数 = surv_summary$n.censor,
      生存概率 = round(surv_summary$surv, 4),
      置信区间下限 = round(surv_summary$lower, 4),
      置信区间上限 = round(surv_summary$upper, 4),
      check.names = FALSE
    )
    surv_df$组别 <- vapply(
      surv_df$组别,
      function(x) .format_survival_group_label(x, strata_var, strata_labels, overall_label),
      character(1)
    )
    if (!is.null(time_range) && length(time_range) == 2) {
      surv_df <- surv_df[surv_df$时间 >= min(time_range) & surv_df$时间 <= max(time_range), , drop = FALSE]
    }
    surv_df
  }

  # 生存分析数据表
  output$km_data_table <- renderDT({
    req(input$render_km_plot)
    shiny::validate(shiny::need(!is.null(fit()), "请先生成生存曲线后查看数据表。"))
    
    # 获取生存分析结果数据
    tryCatch({
      params <- committed_params()
      surv_df <- build_km_summary_df(
        fit(),
        time_range = params$time_range,
        strata_var = params$km_strata,
        strata_labels = params$strata_labels,
        overall_label = params$overall_group_label
      )
      if (!is.null(surv_df)) {
        
        DT::datatable(surv_df, options = list(
          pageLength = 10,
          scrollX = TRUE,
          columnDefs = list(
            list(className = 'dt-center', targets = 0:7)
          )
        )) %>%
          formatRound(columns = c("生存概率", "置信区间下限", "置信区间上限"), digits = 4)
      } else {
        data.frame(错误 = "无法生成生存分析数据表", 信息 = "请检查输入数据")
      }
    }, error = function(e) {
      message(sprintf("[SurvivalTableError] %s", conditionMessage(e)))
      data.frame(
        错误 = "结果表当前无法生成",
        信息 = "请检查当前分层、分面与变量设置后重试。"
      )
    })
  })
  
  output$survival_report <- renderUI({
    req(input$render_km_plot)
    params <- committed_params()
    req(params)
    data_local <- committed_filtered_data()
    shiny::validate(shiny::need(!is.null(fit()) && !is.null(data_local) && nrow(data_local) > 0, "请先生成生存曲线后查看统计报告。"))
    shiny::validate(shiny::need(!is.null(params$km_time) && !is.null(params$km_status), "请先选择时间与状态变量。"))
    
    fit_local <- fit()
    
    method_desc <- paste0(
      "当前采用 Kaplan-Meier 方法估计生存函数；删失定义为 ",
      ifelse(params$km_censor_value == "0", "0=删失, 1=事件", "1=删失, 0=事件"),
      "。"
    )
    
    if (!is.null(params$km_strata) && params$km_strata != "None") {
      method_desc <- paste0(
        method_desc,
        " 分层变量为 ",
        params$km_strata,
        "，比较各组生存曲线差异。"
      )
      if (isTRUE(params$show_stats)) {
        reference_level <- if (!is.null(params$hr_reference) && params$hr_reference != "auto") {
          params$hr_reference
        } else {
          strata_vals <- unique(as.character(data_local[[params$km_strata]]))
          strata_vals <- strata_vals[!is.na(strata_vals) & nzchar(strata_vals)]
          if (length(strata_vals) > 0) strata_vals[[1]] else NULL
        }
        if (!is.null(reference_level) && nzchar(reference_level)) {
          reference_label <- if (reference_level %in% names(params$strata_labels) && nzchar(params$strata_labels[[reference_level]] %||% "")) {
            params$strata_labels[[reference_level]]
          } else {
            reference_level
          }
          method_desc <- paste0(method_desc, " 统计摘要中的 HR 以“", reference_label, "”作为参考组。")
        }
      }
    } else {
      method_desc <- paste0(method_desc, " 未设置分层变量，输出总体生存曲线。")
    }
    
    if (!is.null(params$km_facet) && params$km_facet != "None" && !is.null(params$km_facet_values) && params$km_facet_values != "") {
      method_desc <- paste0(
        method_desc,
        " 当前分面筛选：",
        params$km_facet,
        " = ",
        params$km_facet_values,
        "。"
      )
    }
    
    logrank_p <- stats_results()$logrank_p
    
    med <- stats_results()$median_surv
    n_groups <- if (is.null(fit_local$strata)) 1 else length(fit_local$strata)
    median_lines <- character(0)
    if (isTRUE(params$show_median) && !is.null(med) && nrow(med) > 0) {
      for (i in seq_len(nrow(med))) {
        display_label <- .format_survival_group_label(med$strata[i], params$km_strata, params$strata_labels, params$overall_group_label)
        median_lines <- c(
          median_lines,
          .build_survival_median_summary_label(
            display_strata = display_label,
            median_label = params$median_label_text,
            median_txt = ifelse(is.finite(med$median[i]), formatC(med$median[i], format = "f", digits = 1), "NR"),
            lower_txt = ifelse(is.finite(med$lower[i]), formatC(med$lower[i], format = "f", digits = 1), "NA"),
            upper_txt = ifelse(is.finite(med$upper[i]), formatC(med$upper[i], format = "f", digits = 1), "NA"),
            overall_label = params$overall_group_label
          )
        )
      }
    }
    
    hr_lines <- if (isTRUE(params$show_stats)) stats_results()$hr_lines else character(0)
    
    interpretation <- character(0)
    interpretation <- c(
      interpretation,
      paste0(
        "纳入样本量：", nrow(data_local),
        "；时间变量：", params$km_time,
        "；状态变量：", params$km_status, "。"
      )
    )
    
    if (isTRUE(params$show_stats)) {
      interpretation <- c(interpretation, .build_survival_logrank_interpretation(logrank_p, n_groups = n_groups))
    }
    
    if (length(hr_lines) > 0) {
      interpretation <- c(interpretation, "Cox 回归结果显示不同分层水平相对风险的方向和强度可由 HR 与其95%CI 综合判断：95%CI 不跨 1 通常提示统计学差异。")
    }
    
    summary_items <- c(median_lines, hr_lines)
    if (length(summary_items) == 0) {
      summary_items <- "当前已关闭中位生存时间标注与统计摘要显示。"
    }
    
    tagList(
      tags$div(
        style = "padding: 16px; background: #f8f9fa; border: 1px solid #e5e7eb; border-radius: 6px;",
        tags$h4(style = "margin-top: 0;", "方法解释"),
        tags$p(method_desc),
        tags$hr(),
        tags$h4("结果摘要"),
        tags$ul(lapply(summary_items, tags$li)),
        tags$hr(),
        tags$h4("智能统计解释"),
        tags$ul(lapply(interpretation, tags$li))
      )
    )
  })
  
  # 下载静态图
  output$download_plot <- downloadHandler(
    filename = function() {
      build_plot_export_filename("survival_plot", input$export_format)
    },
    content = function(file) {
      cfg <- size_config()
      save_plot_export(
        file = file,
        plot_obj = graphics_apply_canvas_frame(
          create_surv_plot(),
          frame_width_px = cfg$static_width,
          frame_height_px = cfg$static_height,
          canvas_config = cfg
        ),
        format = input$export_format,
        width = cfg$export_width,
        height = cfg$export_height,
        dpi = input$export_dpi %||% 600,
        bg = "white"
      )
    }
  )
  
  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    graphics_restore_task_input_state(session, state)
    extra_state <- graphics_task_payload_extra_state(state)
    if (!is.null(extra_state$time_var)) view_state$km_time <- extra_state$time_var
    if (!is.null(extra_state$status_var)) view_state$km_status <- extra_state$status_var
    if (!is.null(extra_state$time_range) && length(extra_state$time_range) == 2) {
      view_state$time_range <- extra_state$time_range
      graphics_state$time_range <- extra_state$time_range
    }
    if (!is.null(extra_state$km_censor_value)) view_state$km_censor_value <- extra_state$km_censor_value
    if (!is.null(extra_state$strata_var)) view_state$km_strata <- extra_state$strata_var
    if (!is.null(extra_state$facet_var)) view_state$km_facet <- extra_state$facet_var
    if (!is.null(extra_state$facet_value)) view_state$km_facet_values <- extra_state$facet_value
    if (is.list(extra_state$strata_labels)) graphics_state$strata_labels <- extra_state$strata_labels
    if (!is.null(extra_state$overall_group_label)) view_state$overall_group_label <- extra_state$overall_group_label
    updateSelectizeInput(session, "km_time", selected = extra_state$time_var %||% input$km_time, server = TRUE)
    updateSelectizeInput(session, "km_status", selected = extra_state$status_var %||% input$km_status, server = TRUE)
    if (!is.null(extra_state$km_censor_value)) updateRadioButtons(session, "km_censor_value", selected = extra_state$km_censor_value)
    updateSelectizeInput(session, "strata_var", selected = extra_state$strata_var %||% input$strata_var, server = TRUE)
    updateSelectizeInput(session, "facet_var", selected = extra_state$facet_var %||% input$facet_var, server = TRUE)
    if (!is.null(extra_state$overall_group_label)) updateTextInput(session, "overall_group_label", value = extra_state$overall_group_label)
    if (is.list(extra_state$strata_labels) && length(extra_state$strata_labels) > 0) {
      session$onFlushed(function() {
        for (label_name in names(extra_state$strata_labels)) {
          input_id <- .survival_strata_label_input_id(label_name)
          updateTextInput(session, input_id, value = extra_state$strata_labels[[label_name]] %||% "")
        }
      }, once = TRUE)
    }
    if (!is.null(extra_state$facet_value) && nzchar(extra_state$facet_value %||% "")) {
      session$onFlushed(function() {
        updateSelectInput(session, "facet_value", selected = extra_state$facet_value)
      }, once = TRUE)
    }
    if (!is.null(extra_state$time_range) && length(extra_state$time_range) == 2) {
      session$onFlushed(function() {
        updateSliderInput(session, "time_range", value = extra_state$time_range)
      }, once = TRUE)
    }
    invisible(TRUE)
  }

  list(
    state = reactive({
      graphics_build_task_state(
        input,
        extra_state = list(
          time_var = graphics_state$km_time %||% input$km_time,
          status_var = graphics_state$km_status %||% input$km_status,
          time_range = graphics_state$time_range %||% input$time_range,
          km_censor_value = graphics_state$km_censor_value %||% input$km_censor_value,
          strata_var = graphics_state$km_strata %||% input$strata_var,
          facet_var = graphics_state$km_facet %||% input$facet_var,
          facet_value = graphics_state$km_facet_values %||% input$facet_value,
          strata_labels = graphics_state$strata_labels %||% list(),
          overall_group_label = graphics_state$overall_group_label %||% input$overall_group_label
        )
      )
    }),
    apply_state = apply_state
  )
}
