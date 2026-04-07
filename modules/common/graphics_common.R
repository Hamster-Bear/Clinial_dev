get_numeric_vars <- function(df) {
  if (is.null(df)) return(character(0))
  names(df)[vapply(df, is.numeric, logical(1))]
}

get_categorical_vars <- function(df, include_logical = TRUE) {
  if (is.null(df)) return(character(0))
  names(df)[vapply(df, function(x) {
    is.factor(x) || is.character(x) || (isTRUE(include_logical) && is.logical(x))
  }, logical(1))]
}

get_time_vars <- function(df) {
  if (is.null(df)) return(character(0))
  names(df)[vapply(df, function(x) {
    is.numeric(x) || inherits(x, "Date") || inherits(x, "POSIXt")
  }, logical(1))]
}

resolve_plot_size_config <- function(
  mode = "wide_standard",
  static_width_px = NULL,
  static_height_px = NULL,
  interactive_width_px = NULL,
  interactive_height_px = NULL,
  export_width_in = NULL,
  export_height_in = NULL,
  defaults = list(
    static_width = 1200,
    static_height = 760,
    interactive_width = 1200,
    interactive_height = 620,
    export_width = 13,
    export_height = 9
  )
) {
  to_num <- function(x, fallback) {
    val <- suppressWarnings(as.numeric(x))
    if (is.na(val) || !is.finite(val)) fallback else val
  }

  if (!identical(mode, "custom")) {
    return(defaults)
  }

  list(
    static_width = to_num(static_width_px, defaults$static_width),
    static_height = to_num(static_height_px, defaults$static_height),
    interactive_width = to_num(interactive_width_px, defaults$interactive_width),
    interactive_height = to_num(interactive_height_px, defaults$interactive_height),
    export_width = to_num(export_width_in, defaults$export_width),
    export_height = to_num(export_height_in, defaults$export_height)
  )
}

graphics_notify_success <- function(module_name) {
  showNotification(paste0(module_name, "生成完成"), type = "message")
}

graphics_notify_error <- function(module_name, err) {
  msg <- if (inherits(err, "error")) conditionMessage(err) else as.character(err)
  showNotification(paste0(module_name, "生成错误: ", msg), type = "error")
}

graphics_progress_text <- function(module_name, detail = NULL, value = NULL) {
  base <- paste0(module_name, "正在生成图形")
  if (!is.null(detail) && nzchar(detail)) {
    base <- paste0(base, "：", detail)
  }
  if (!is.null(value) && is.finite(value)) {
    pct <- round(max(0, min(1, value)) * 100)
    base <- paste0(base, " (", pct, "%)")
  }
  base
}

graphics_progress_start <- function(module_name) {
  id <- paste0("graphics_progress_", gsub("[^A-Za-z0-9_]+", "_", module_name))
  showNotification(
    graphics_progress_text(module_name, detail = "初始化", value = 0),
    type = "message",
    duration = NULL,
    id = id
  )
  id
}

graphics_progress_update <- function(progress_id, module_name, detail = NULL, value = NULL) {
  showNotification(
    graphics_progress_text(module_name, detail = detail, value = value),
    type = "message",
    duration = NULL,
    id = progress_id
  )
}

graphics_progress_end <- function(progress_id) {
  removeNotification(progress_id)
}

graphics_override_colors <- function(default_colors, manual_colors = NULL) {
  out <- default_colors
  if (length(out) == 0) return(out)
  if (is.null(manual_colors) || length(manual_colors) == 0) return(out)
  valid_keys <- intersect(names(out), names(manual_colors))
  if (length(valid_keys) == 0) return(out)
  for (k in valid_keys) {
    v <- manual_colors[[k]]
    if (is.null(v) || length(v) == 0) next
    vv <- as.character(v[[1]])
    if (!is.na(vv) && nzchar(trimws(vv))) {
      out[[k]] <- vv
    }
  }
  out
}

graphics_filter_tracks_by_mode <- function(track_names, mode_map = NULL, target_mode = "color") {
  if (length(track_names) == 0) return(character(0))
  if (is.null(mode_map) || length(mode_map) == 0) return(track_names)
  out <- track_names[vapply(track_names, function(tr) {
    mode <- mode_map[[tr]] %||% target_mode
    identical(mode, target_mode)
  }, logical(1))]
  unname(out)
}

graphics_resolve_mapping_var <- function(selected_var = NULL, fallback_var = NULL, available_names = character(0), enable_fallback = FALSE) {
  available_names <- as.character(available_names %||% character(0))
  if (!is.null(selected_var) && nzchar(selected_var) && selected_var %in% available_names) return(selected_var)
  if (isTRUE(enable_fallback) && !is.null(fallback_var) && nzchar(fallback_var) && fallback_var %in% available_names) return(fallback_var)
  NULL
}

graphics_remember_choice <- function(input_value, state_value = NULL, choices, default_value = NULL, allow_empty = FALSE) {
  valid_choices <- unique(as.character(choices))
  if (allow_empty) valid_choices <- c("", valid_choices)
  if (!is.null(input_value) && input_value %in% valid_choices) return(input_value)
  if (!is.null(state_value) && state_value %in% valid_choices) return(state_value)
  if (!is.null(default_value) && default_value %in% valid_choices) return(default_value)
  if (length(valid_choices) == 0) return(default_value %||% if (allow_empty) "" else NULL)
  valid_choices[[1]]
}

graphics_text_symbol_choices <- function() {
  c("★" = "★", "▲" = "▲", "●" = "●", "◆" = "◆", "■" = "■", "✕" = "✕", "✦" = "✦", "✚" = "✚", "⬟" = "⬟", "⬢" = "⬢", "◉" = "◉", "◈" = "◈")
}

graphics_shape_choice_values <- function() {
  c("X" = 4, "实心圆" = 16, "空心圆" = 1, "实心方块" = 15, "空心方块" = 0, "实心三角" = 17, "空心三角" = 2, "菱形" = 18, "加号" = 3, "星号" = 8)
}

graphics_group_symbol_controls_ui <- function(
  session,
  levels,
  symbol_input_prefix = NULL,
  color_input_prefix = NULL,
  symbol_choices = graphics_text_symbol_choices(),
  default_symbols = NULL,
  default_colors = NULL,
  title = "符号分组映射",
  color_label_suffix = "颜色",
  show_symbol = TRUE,
  show_color = TRUE
) {
  levels <- as.character(levels)
  levels <- levels[!is.na(levels) & nzchar(levels)]
  if (length(levels) == 0) return(NULL)
  if (!isTRUE(show_symbol) && !isTRUE(show_color)) return(NULL)
  default_symbols <- default_symbols %||% rep(unname(symbol_choices), length.out = length(levels))
  default_colors <- default_colors %||% rep("#1A1A1A", length(levels))
  symbol_col_width <- if (isTRUE(show_symbol) && isTRUE(show_color)) 6 else 12
  color_col_width <- if (isTRUE(show_symbol) && isTRUE(show_color)) 6 else 12
  shiny::tagList(
    shiny::h5(title),
    lapply(seq_along(levels), function(i) {
      lv <- levels[[i]]
      shiny::fluidRow(
        if (isTRUE(show_symbol)) {
          shiny::column(
            symbol_col_width,
            shiny::selectInput(
              session$ns(paste0(symbol_input_prefix, digest::digest(lv, algo = "crc32"))),
              label = lv,
              choices = symbol_choices,
              selected = default_symbols[[i]],
              width = "100%"
            )
          )
        },
        if (isTRUE(show_color)) {
          shiny::column(
            color_col_width,
            colourpicker::colourInput(
              session$ns(paste0(color_input_prefix, digest::digest(lv, algo = "crc32"))),
              label = paste0(lv, " ", color_label_suffix),
              value = default_colors[[i]],
              width = "100%"
            )
          )
        }
      )
    })
  )
}

graphics_mapping_caption_line <- function(subject_label, mode_label) {
  if (is.null(subject_label) || !nzchar(trimws(subject_label))) return(NULL)
  paste0(mode_label, "按变量“", trimws(subject_label), "”分别指定。")
}

graphics_compose_caption <- function(user_caption = NULL, auto_lines = character(0)) {
  user_caption <- trimws(as.character(user_caption %||% ""))
  auto_lines <- unique(auto_lines[nzchar(trimws(auto_lines))])
  pieces <- character(0)
  if (nzchar(user_caption)) pieces <- c(pieces, user_caption)
  if (length(auto_lines) > 0) pieces <- c(pieces, auto_lines)
  if (length(pieces) == 0) return("")
  paste(pieces, collapse = "\n")
}

graphics_append_bottom_caption <- function(plot_obj, caption_text, base_font_size = 12) {
  caption_text <- trimws(as.character(caption_text %||% ""))
  if (!nzchar(caption_text)) return(plot_obj)
  caption_plot <- ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 1, label = caption_text, hjust = 0, vjust = 1, size = max(3, base_font_size * 0.24), family = "sans") +
    ggplot2::coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
    ggplot2::theme_void() +
    ggplot2::theme(plot.margin = ggplot2::margin(2, 8, 8, 8))
  cowplot::plot_grid(plot_obj, caption_plot, ncol = 1, rel_heights = c(1, 0.08), align = "v", axis = "lr")
}

graphics_resolve_legend_title <- function(custom_title = NULL, fallback_title = NULL, default_title = "") {
  custom_title <- trimws(as.character(custom_title %||% ""))
  fallback_title <- trimws(as.character(fallback_title %||% ""))
  default_title <- trimws(as.character(default_title %||% ""))
  if (nzchar(custom_title)) return(custom_title)
  if (nzchar(fallback_title)) return(fallback_title)
  default_title
}

graphics_legend_position_choices <- function(kind = "outer") {
  switch(
    kind,
    "corners_none" = c("右上" = "top-right", "顶部" = "top", "左上" = "top-left", "左侧" = "left", "右侧" = "right", "左下" = "bottom-left", "底部" = "bottom", "右下" = "bottom-right", "隐藏" = "none"),
    "aux" = c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom", "图内右下" = "inside_bottom_right", "图内自定义" = "inside_custom"),
    "outer_none" = c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom", "隐藏" = "none"),
    c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom")
  )
}

graphics_legend_controls_ui <- function(ns, title_id = "legend_title", position_id = "legend_position", title_label = "图例标题", position_label = "图例位置", position_kind = "outer", default_title = "", default_position = "right") {
  shiny::fluidRow(
    shiny::column(
      6,
      shiny::selectInput(ns(position_id), position_label, choices = graphics_legend_position_choices(position_kind), selected = default_position, width = "100%")
    ),
    shiny::column(
      6,
      shiny::textInput(ns(title_id), title_label, value = default_title, placeholder = "留空使用默认标题", width = "100%")
    )
  )
}

graphics_resolve_inside_anchor <- function(x_ratio = 0.72, y_ratio = 0.03, width_ratio = 0.26, height_ratio = 0.28) {
  width_ratio <- max(0.1, min(0.9, suppressWarnings(as.numeric(width_ratio %||% 0.26))))
  height_ratio <- max(0.1, min(0.9, suppressWarnings(as.numeric(height_ratio %||% 0.28))))
  x_ratio <- max(0, min(1 - width_ratio, suppressWarnings(as.numeric(x_ratio %||% 0.72))))
  y_ratio <- max(0, min(1 - height_ratio, suppressWarnings(as.numeric(y_ratio %||% 0.03))))
  c(x_ratio, y_ratio, width_ratio, height_ratio)
}

graphics_place_aux_legend <- function(plot_obj, legend_plot = NULL, position = "right", outside_ratio = 0.35, inside_anchor = c(0.72, 0.03, 0.26, 0.28)) {
  if (is.null(legend_plot)) return(plot_obj)
  if (identical(position, "inside_bottom_right") || identical(position, "inside_custom")) {
    anchor <- graphics_resolve_inside_anchor(
      x_ratio = inside_anchor[[1]],
      y_ratio = inside_anchor[[2]],
      width_ratio = inside_anchor[[3]],
      height_ratio = inside_anchor[[4]]
    )
    return(
      cowplot::ggdraw() +
        cowplot::draw_plot(plot_obj, 0, 0, 1, 1) +
        cowplot::draw_plot(legend_plot, anchor[[1]], anchor[[2]], anchor[[3]], anchor[[4]])
    )
  }
  if (identical(position, "left")) {
    return(cowplot::plot_grid(legend_plot, plot_obj, ncol = 2, rel_widths = c(outside_ratio, 1), align = "h", axis = "tb"))
  }
  if (identical(position, "top")) {
    return(cowplot::plot_grid(legend_plot, plot_obj, ncol = 1, rel_heights = c(outside_ratio, 1), align = "v", axis = "lr"))
  }
  if (identical(position, "bottom")) {
    return(cowplot::plot_grid(plot_obj, legend_plot, ncol = 1, rel_heights = c(1, outside_ratio), align = "v", axis = "lr"))
  }
  cowplot::plot_grid(plot_obj, legend_plot, ncol = 2, rel_widths = c(1, outside_ratio), align = "h", axis = "tb")
}

graphics_apply_legend_theme <- function(plot_obj, show_legend = TRUE, position = "right", inside_anchor = c(0.72, 0.03, 0.26, 0.28)) {
  if (!isTRUE(show_legend) || identical(position, "none")) {
    return(plot_obj + ggplot2::theme(legend.position = "none"))
  }
  if (position %in% c("top", "bottom", "left", "right")) {
    return(plot_obj + ggplot2::theme(legend.position = position))
  }
  if (position %in% c("top-left", "top-right", "bottom-left", "bottom-right")) {
    pos_map <- list("top-left" = c(0, 1), "top-right" = c(1, 1), "bottom-left" = c(0, 0), "bottom-right" = c(1, 0))
    pos <- pos_map[[position]]
    return(plot_obj + ggplot2::theme(legend.position = "inside", legend.position.inside = pos, legend.justification = pos))
  }
  if (position %in% c("inside_bottom_right", "inside_custom")) {
    anchor <- graphics_resolve_inside_anchor(
      x_ratio = inside_anchor[[1]],
      y_ratio = inside_anchor[[2]],
      width_ratio = inside_anchor[[3]],
      height_ratio = inside_anchor[[4]]
    )
    legend_pos <- if (identical(position, "inside_bottom_right")) c(0.98, 0.02) else c(anchor[[1]], anchor[[2]])
    legend_just <- if (identical(position, "inside_bottom_right")) c(1, 0) else c(0, 0)
    return(plot_obj + ggplot2::theme(legend.position = "inside", legend.position.inside = legend_pos, legend.justification = legend_just))
  }
  plot_obj
}
