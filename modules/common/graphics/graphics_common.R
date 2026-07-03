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

graphics_px_to_in <- function(px, ppi = 96, digits = 2) {
  px_val <- suppressWarnings(as.numeric(px))
  ppi_val <- suppressWarnings(as.numeric(ppi))
  if (is.na(px_val) || !is.finite(px_val) || px_val <= 0) return(0)
  if (is.na(ppi_val) || !is.finite(ppi_val) || ppi_val <= 0) ppi_val <- 96
  round(px_val / ppi_val, digits)
}

graphics_in_to_px <- function(inches, ppi = 96) {
  inch_val <- suppressWarnings(as.numeric(inches))
  ppi_val <- suppressWarnings(as.numeric(ppi))
  if (is.na(inch_val) || !is.finite(inch_val) || inch_val <= 0) return(0)
  if (is.na(ppi_val) || !is.finite(ppi_val) || ppi_val <= 0) ppi_val <- 96
  as.integer(round(inch_val * ppi_val))
}

graphics_pt_to_geom_text_size <- function(pt, fallback = 10) {
  pt_val <- suppressWarnings(as.numeric(pt))
  fallback_val <- suppressWarnings(as.numeric(fallback))
  if (is.na(fallback_val) || !is.finite(fallback_val) || fallback_val <= 0) fallback_val <- 10
  if (is.na(pt_val) || !is.finite(pt_val) || pt_val <= 0) pt_val <- fallback_val
  pt_val / ggplot2::.pt
}

graphics_first_value_or_default <- function(x, default = NULL) {
  if (is.null(x) || length(x) < 1) {
    return(default)
  }
  value <- x[[1]]
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    return(default)
  }
  value
}

graphics_is_explicit_text_input <- function(value) {
  !is.null(value) && length(value) >= 1 && !is.na(as.character(value[[1]]))
}

graphics_text_or_default <- function(value = NULL, default = "", allow_blank_string = FALSE) {
  if (!graphics_is_explicit_text_input(value)) {
    return(default)
  }
  text <- as.character(value[[1]])
  if (!allow_blank_string && identical(text, "")) {
    return(default)
  }
  text
}

graphics_normalize_anchor <- function(anchor = NULL, default_anchor = c(0.95, 0.85, 0.13, 0.14)) {
  default_vals <- suppressWarnings(as.numeric(default_anchor))
  if (length(default_vals) < 4 || any(is.na(default_vals))) {
    default_vals <- c(0.95, 0.85, 0.13, 0.14)
  }
  anchor_vals <- suppressWarnings(as.numeric(anchor))
  if (length(anchor_vals) < 4 || any(is.na(anchor_vals))) {
    return(default_vals)
  }
  anchor_vals[1:4]
}

graphics_scale_export_height <- function(static_width_px, static_height_px, export_width_in, digits = 2) {
  width_px <- suppressWarnings(as.numeric(static_width_px))
  height_px <- suppressWarnings(as.numeric(static_height_px))
  export_width <- suppressWarnings(as.numeric(export_width_in))
  if (is.na(width_px) || !is.finite(width_px) || width_px <= 0) return(export_width)
  if (is.na(height_px) || !is.finite(height_px) || height_px <= 0) return(export_width)
  if (is.na(export_width) || !is.finite(export_width) || export_width <= 0) return(export_width)
  round(export_width * (height_px / width_px), digits)
}

graphics_normalize_page_margin <- function(
  page_margin_top_px = NULL,
  page_margin_right_px = NULL,
  page_margin_bottom_px = NULL,
  page_margin_left_px = NULL,
  default_margin_px = 24
) {
  to_margin <- function(value, fallback = default_margin_px) {
    val <- suppressWarnings(as.numeric(value))
    if (is.na(val) || !is.finite(val)) val <- fallback
    max(0, min(240, val))
  }

  list(
    top = to_margin(page_margin_top_px),
    right = to_margin(page_margin_right_px),
    bottom = to_margin(page_margin_bottom_px),
    left = to_margin(page_margin_left_px)
  )
}

resolve_plot_size_config <- function(
  mode = "wide_standard",
  static_width_px = NULL,
  static_height_px = NULL,
  interactive_width_px = NULL,
  interactive_height_px = NULL,
  export_width_in = NULL,
  export_height_in = NULL,
  sync_export_size = TRUE,
  size_sync_ppi = 96,
  page_margin_top_px = NULL,
  page_margin_right_px = NULL,
  page_margin_bottom_px = NULL,
  page_margin_left_px = NULL,
  canvas_border = TRUE,
  canvas_border_color = "#D9D9D9",
  canvas_border_size = 0.8,
  canvas_background = "white",
  defaults = list(
    static_width = 1200,
    static_height = 760,
    interactive_width = 1200,
    interactive_height = 620,
    export_width = graphics_px_to_in(1200, 96),
    export_height = graphics_px_to_in(760, 96),
    sync_ppi = 96,
    page_margin_top = 24,
    page_margin_right = 24,
    page_margin_bottom = 24,
    page_margin_left = 24,
    canvas_border = TRUE,
    canvas_border_color = "#D9D9D9",
    canvas_border_size = 0.8,
    canvas_background = "white"
  )
) {
  to_num <- function(x, fallback) {
    val <- suppressWarnings(as.numeric(x))
    if (length(val) == 0 || is.na(val) || !is.finite(val)) fallback else val
  }

  sync_ppi <- to_num(size_sync_ppi, defaults$sync_ppi %||% 96)
  margin_cfg <- graphics_normalize_page_margin(
    page_margin_top_px = page_margin_top_px %||% defaults$page_margin_top,
    page_margin_right_px = page_margin_right_px %||% defaults$page_margin_right,
    page_margin_bottom_px = page_margin_bottom_px %||% defaults$page_margin_bottom,
    page_margin_left_px = page_margin_left_px %||% defaults$page_margin_left
  )
  sync_export_size <- isTRUE(sync_export_size %||% defaults$sync_export_size %||% TRUE)
  border_flag <- isTRUE(canvas_border %||% defaults$canvas_border %||% TRUE)
  border_size <- to_num(canvas_border_size, defaults$canvas_border_size %||% 0.8)
  border_color <- as.character(canvas_border_color %||% defaults$canvas_border_color %||% "#D9D9D9")
  background_fill <- as.character(canvas_background %||% defaults$canvas_background %||% "white")

  if (!identical(mode, "custom")) {
    static_width <- to_num(defaults$static_width, 1200)
    static_height <- to_num(defaults$static_height, 760)
    interactive_width <- to_num(defaults$interactive_width, 1200)
    interactive_height <- to_num(defaults$interactive_height, 620)
    export_width <- if (isTRUE(sync_export_size)) {
      graphics_px_to_in(static_width, sync_ppi)
    } else {
      to_num(defaults$export_width, graphics_px_to_in(static_width, sync_ppi))
    }
    export_height <- if (isTRUE(sync_export_size)) {
      graphics_scale_export_height(static_width, static_height, export_width)
    } else {
      to_num(defaults$export_height, graphics_scale_export_height(static_width, static_height, export_width))
    }
    return(list(
      static_width = static_width,
      static_height = static_height,
      interactive_width = interactive_width,
      interactive_height = interactive_height,
      export_width = export_width,
      export_height = export_height,
      sync_export_size = sync_export_size,
      size_sync_ppi = sync_ppi,
      page_margin_top = margin_cfg$top,
      page_margin_right = margin_cfg$right,
      page_margin_bottom = margin_cfg$bottom,
      page_margin_left = margin_cfg$left,
      canvas_border = border_flag,
      canvas_border_color = border_color,
      canvas_border_size = border_size,
      canvas_background = background_fill
    ))
  }

  static_width <- to_num(static_width_px, defaults$static_width)
  static_height <- to_num(static_height_px, defaults$static_height)
  interactive_width <- to_num(interactive_width_px, defaults$interactive_width)
  interactive_height <- to_num(interactive_height_px, defaults$interactive_height)
  export_width_default <- graphics_px_to_in(static_width, sync_ppi)
  export_width <- if (isTRUE(sync_export_size)) {
    export_width_default
  } else {
    to_num(export_width_in, defaults$export_width %||% export_width_default)
  }
  export_height_default <- graphics_scale_export_height(static_width, static_height, export_width)
  export_height <- if (isTRUE(sync_export_size)) {
    export_height_default
  } else {
    to_num(export_height_in, defaults$export_height %||% export_height_default)
  }

  list(
    static_width = static_width,
    static_height = static_height,
    interactive_width = interactive_width,
    interactive_height = interactive_height,
    export_width = export_width,
    export_height = export_height,
    sync_export_size = sync_export_size,
    size_sync_ppi = sync_ppi,
    page_margin_top = margin_cfg$top,
    page_margin_right = margin_cfg$right,
    page_margin_bottom = margin_cfg$bottom,
    page_margin_left = margin_cfg$left,
    canvas_border = border_flag,
    canvas_border_color = border_color,
    canvas_border_size = border_size,
    canvas_background = background_fill
  )
}

graphics_apply_canvas_frame <- function(plot_obj, frame_width_px, frame_height_px, canvas_config = list()) {
  if (is.null(plot_obj)) return(NULL)
  width_px <- max(1, suppressWarnings(as.numeric(frame_width_px %||% 1200)))
  height_px <- max(1, suppressWarnings(as.numeric(frame_height_px %||% 760)))
  margin_cfg <- graphics_normalize_page_margin(
    page_margin_top_px = canvas_config$page_margin_top,
    page_margin_right_px = canvas_config$page_margin_right,
    page_margin_bottom_px = canvas_config$page_margin_bottom,
    page_margin_left_px = canvas_config$page_margin_left
  )

  left_ratio <- min(0.45, margin_cfg$left / width_px)
  right_ratio <- min(0.45, margin_cfg$right / width_px)
  top_ratio <- min(0.45, margin_cfg$top / height_px)
  bottom_ratio <- min(0.45, margin_cfg$bottom / height_px)
  plot_width_ratio <- max(0.1, 1 - left_ratio - right_ratio)
  plot_height_ratio <- max(0.1, 1 - top_ratio - bottom_ratio)
  background_fill <- as.character(canvas_config$canvas_background %||% "white")
  border_color <- if (isTRUE(canvas_config$canvas_border %||% TRUE)) {
    as.character(canvas_config$canvas_border_color %||% "#D9D9D9")
  } else {
    NA_character_
  }
  border_size <- suppressWarnings(as.numeric(canvas_config$canvas_border_size %||% 0.8))
  if (is.na(border_size) || !is.finite(border_size) || border_size < 0) border_size <- 0.8

  cowplot::ggdraw() +
    cowplot::draw_plot(
      plot_obj,
      x = left_ratio,
      y = bottom_ratio,
      width = plot_width_ratio,
      height = plot_height_ratio
    ) +
    ggplot2::theme(
      plot.margin = ggplot2::margin(0, 0, 0, 0),
      plot.background = ggplot2::element_rect(
        fill = background_fill,
        colour = border_color,
        linewidth = border_size
      )
    )
}

graphics_collect_size_config <- function(input, defaults = list()) {
  resolve_plot_size_config(
    mode = input$size_mode %||% "wide_standard",
    static_width_px = input$static_width_px,
    static_height_px = input$static_height_px,
    interactive_width_px = input$interactive_width_px,
    interactive_height_px = input$interactive_height_px,
    export_width_in = input$export_width_in,
    export_height_in = input$export_height_in,
    sync_export_size = input$sync_export_size %||% TRUE,
    size_sync_ppi = input$size_sync_ppi %||% 96,
    page_margin_top_px = input$page_margin_top_px,
    page_margin_right_px = input$page_margin_right_px,
    page_margin_bottom_px = input$page_margin_bottom_px,
    page_margin_left_px = input$page_margin_left_px,
    canvas_border = input$canvas_border %||% TRUE,
    defaults = defaults
  )
}

graphics_collect_reference_line_spec <- function(
  input,
  id_prefix,
  orientation = "h",
  fallback_value = NULL,
  fallback_color = "#1A1A1A",
  fallback_linetype = "dashed",
  fallback_linewidth = 0.8
) {
  value <- suppressWarnings(as.numeric(input[[id_prefix]] %||% fallback_value))
  if (length(value) == 0 || is.na(value) || !is.finite(value)) return(NULL)
  list(
    orientation = if (identical(orientation, "v")) "v" else "h",
    value = value,
    color = as.character(input[[paste0(id_prefix, "_color")]] %||% fallback_color),
    linetype = as.character(input[[paste0(id_prefix, "_linetype")]] %||% fallback_linetype),
    linewidth = suppressWarnings(as.numeric(input[[paste0(id_prefix, "_linewidth")]] %||% fallback_linewidth))
  )
}

graphics_add_reference_lines <- function(plot_obj, specs = list()) {
  if (is.null(plot_obj) || length(specs) == 0) return(plot_obj)
  for (spec in specs) {
    if (is.null(spec)) next
    line_value <- suppressWarnings(as.numeric(spec$value %||% NA_real_))
    line_width <- suppressWarnings(as.numeric(spec$linewidth %||% 0.8))
    if (length(line_value) == 0 || is.na(line_value) || !is.finite(line_value)) next
    if (length(line_width) == 0 || is.na(line_width) || !is.finite(line_width) || line_width < 0) line_width <- 0.8
    line_color <- as.character(spec$color %||% "#1A1A1A")
    line_type <- as.character(spec$linetype %||% "dashed")
    if (identical(spec$orientation %||% "h", "v")) {
      plot_obj <- plot_obj + ggplot2::geom_vline(
        xintercept = line_value,
        linetype = line_type,
        color = line_color,
        linewidth = line_width
      )
    } else {
      plot_obj <- plot_obj + ggplot2::geom_hline(
        yintercept = line_value,
        linetype = line_type,
        color = line_color,
        linewidth = line_width
      )
    }
  }
  plot_obj
}

graphics_notify_success <- function(module_name) {
  showNotification(paste0(module_name, "生成完成"), type = "message")
}

graphics_user_safe_error_message <- function(module_name, action = "生成图形") {
  paste0(module_name, action, "失败，请检查当前参数或数据后重试。")
}

graphics_notify_error <- function(module_name, err, user_message = NULL, action = "生成图形") {
  msg <- if (inherits(err, "error")) conditionMessage(err) else as.character(err)
  message(sprintf("[GraphicsError][%s] %s: %s", module_name, action, msg))
  showNotification(user_message %||% graphics_user_safe_error_message(module_name, action), type = "error")
}

graphics_task_input_exclude_patterns <- function() {
  c(
    "^(render_|refresh_|save_|load_|delete_|confirm_|add_|remove_)",
    "^(dl_|download_)",
    "_rows_selected$",
    "_rows_(all|current)$",
    "_search$",
    "_search_columns$",
    "_state$",
    "_cell_(clicked|edited)$",
    "_columns_selected$",
    "_row_last_clicked$",
    "_(click|hover|selected|relayout|restyle|brush)$",
    "^output_tabs$",
    "^config_tabs$"
  )
}

graphics_collect_task_input_state <- function(
  input,
  exclude_ids = character(0),
  exclude_patterns = graphics_task_input_exclude_patterns()
) {
  state <- shiny::reactiveValuesToList(input)
  if (length(state) == 0) {
    return(list())
  }
  state_names <- names(state)
  keep <- !(state_names %in% exclude_ids)
  if (length(exclude_patterns) > 0) {
    for (pattern in exclude_patterns) {
      keep <- keep & !grepl(pattern, state_names)
    }
  }
  state[keep]
}

graphics_build_task_state <- function(input, extra_state = list(), exclude_ids = character(0), exclude_patterns = NULL) {
  list(
    task_schema_version = 1,
    input_state = graphics_collect_task_input_state(
      input = input,
      exclude_ids = exclude_ids,
      exclude_patterns = exclude_patterns %||% graphics_task_input_exclude_patterns()
    ),
    extra_state = extra_state %||% list()
  )
}

graphics_task_payload_input_state <- function(state) {
  if (is.list(state) && is.list(state$input_state)) {
    return(state$input_state)
  }
  list()
}

graphics_task_payload_extra_state <- function(state) {
  if (is.list(state) && is.list(state$extra_state)) {
    return(state$extra_state)
  }
  state %||% list()
}

graphics_should_skip_task_input <- function(input_id, value = NULL, exclude_ids = character(0), exclude_patterns = graphics_task_input_exclude_patterns()) {
  if (!nzchar(input_id %||% "")) {
    return(TRUE)
  }
  if (input_id %in% exclude_ids) {
    return(TRUE)
  }
  if (length(exclude_patterns) > 0 && any(vapply(exclude_patterns, function(pattern) {
    grepl(pattern, input_id)
  }, logical(1)))) {
    return(TRUE)
  }
  if (is.data.frame(value)) {
    return(TRUE)
  }
  if (is.list(value) && !is.atomic(value)) {
    return(TRUE)
  }
  FALSE
}

graphics_restore_single_input_value <- function(session, input_id, value, exclude_ids = character(0), exclude_patterns = graphics_task_input_exclude_patterns()) {
  if (!nzchar(input_id %||% "")) {
    return(invisible(FALSE))
  }
  if (graphics_should_skip_task_input(input_id, value, exclude_ids = exclude_ids, exclude_patterns = exclude_patterns)) {
    return(invisible(FALSE))
  }
  tryCatch({
    session$sendInputMessage(input_id, list(value = value))
    TRUE
  }, error = function(e) {
    message(sprintf("[GraphicsTaskRestoreWarn][%s] %s", input_id, conditionMessage(e)))
    FALSE
  })
}

graphics_restore_task_input_state <- function(session, state, exclude_ids = character(0), exclude_patterns = graphics_task_input_exclude_patterns(), defer = TRUE) {
  input_state <- graphics_task_payload_input_state(state)
  if (length(input_state) == 0) {
    return(invisible(FALSE))
  }
  restore_fn <- function() {
    input_names <- names(input_state)
    for (input_id in input_names) {
      graphics_restore_single_input_value(
        session,
        input_id,
        input_state[[input_id]],
        exclude_ids = exclude_ids,
        exclude_patterns = exclude_patterns
      )
    }
  }
  if (isTRUE(defer)) {
    session$onFlushed(restore_fn, once = TRUE)
  } else {
    restore_fn()
  }
  invisible(TRUE)
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
  user_caption <- graphics_text_or_default(user_caption, default = "", allow_blank_string = TRUE)
  auto_lines <- unique(auto_lines[nzchar(trimws(auto_lines))])
  pieces <- character(0)
  if (!identical(user_caption, "")) pieces <- c(pieces, user_caption)
  if (length(auto_lines) > 0) pieces <- c(pieces, auto_lines)
  if (length(pieces) == 0) return("")
  paste(pieces, collapse = "\n")
}

graphics_append_bottom_caption <- function(plot_obj, caption_text, base_font_size = 12, font_family = "sans", cjk_family = "Noto Sans SC", layout_family = NULL) {
  caption_text <- graphics_text_or_default(caption_text, default = "", allow_blank_string = TRUE)
  if (identical(caption_text, "")) return(plot_obj)
  caption_family <- graphics_resolve_layout_family(
    layout_family %||% font_family
  )
  caption_plot <- ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 1, label = caption_text, hjust = 0, vjust = 1, size = max(3, base_font_size * 0.24), family = caption_family) +
    ggplot2::coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
    ggplot2::theme_void(base_family = caption_family) +
    ggplot2::theme(plot.margin = ggplot2::margin(2, 8, 8, 8))
  cowplot::plot_grid(plot_obj, caption_plot, ncol = 1, rel_heights = c(1, 0.08), align = "v", axis = "lr")
}

graphics_resolve_latin_family <- function(family = "sans") {
  graphics_resolve_device_safe_family(family)
}

graphics_resolve_layout_family <- function(family = "sans") {
  resolved <- trimws(as.character(graphics_first_value_or_default(family, "sans")))
  if (!nzchar(resolved)) return("sans")
  layout_alias <- c(
    "Arial" = "sans",
    "Helvetica" = "sans",
    "Noto Sans SC" = "sans",
    "Microsoft YaHei" = "sans",
    "SimHei" = "sans",
    "Times" = "serif",
    "Times New Roman" = "serif",
    "Courier" = "mono"
  )
  if (resolved %in% names(layout_alias)) {
    return(unname(layout_alias[[resolved]]))
  }
  if (resolved %in% c("sans", "serif", "mono")) {
    return(resolved)
  }
  "sans"
}

graphics_resolve_font_spec <- function(base_family = "sans", cjk_family = "Noto Sans SC", layout_family = NULL) {
  latin <- graphics_resolve_latin_family(base_family)
  cjk <- graphics_resolve_cjk_family(cjk_family = cjk_family, fallback_family = base_family)
  layout <- graphics_resolve_layout_family(layout_family %||% base_family)
  unified <- if (identical(cjk, "sans")) latin else cjk
  list(
    latin = latin,
    cjk = cjk,
    layout = layout,
    unified = unified
  )
}

graphics_resolve_text_family <- function(text, base_family = "sans", cjk_family = "Noto Sans SC", layout_family = NULL, context = c("plot", "layout")) {
  context <- match.arg(context)
  spec <- graphics_resolve_font_spec(
    base_family = base_family,
    cjk_family = cjk_family,
    layout_family = layout_family
  )
  if (identical(context, "layout")) {
    return(spec$layout)
  }
  values <- as.character(text %||% character(0))
  if (length(values) == 0) return(spec$unified)
  ifelse(graphics_text_has_cjk(values), spec$cjk, spec$latin)
}

graphics_resolve_legend_title <- function(custom_title = NULL, fallback_title = NULL, default_title = "") {
  custom_title <- graphics_text_or_default(custom_title, default = "", allow_blank_string = TRUE)
  fallback_title <- graphics_text_or_default(fallback_title, default = "", allow_blank_string = TRUE)
  default_title <- graphics_text_or_default(default_title, default = "", allow_blank_string = TRUE)
  if (!identical(custom_title, "")) return(custom_title)
  if (!identical(fallback_title, "")) return(fallback_title)
  default_title
}

graphics_legend_position_choices <- function(kind = "outer") {
  switch(
    kind,
    "corners_aux_none" = c("右上" = "top-right", "顶部" = "top", "左上" = "top-left", "左侧" = "left", "右侧" = "right", "左下" = "bottom-left", "底部" = "bottom", "右下" = "bottom-right", "图内自定义" = "inside_custom", "隐藏" = "none"),
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

graphics_aux_legend_anchor_controls_ui <- function(ns, position_id, x_ratio_id = "legend_x_ratio", y_ratio_id = "legend_y_ratio", width_ratio_id = "legend_width_ratio", height_ratio_id = "legend_height_ratio", default_anchor = c(0.95, 0.85, 0.13, 0.14), condition_positions = c("inside_bottom_right", "inside_custom"), x_label = "图例X比例", y_label = "图例Y比例", width_label = "图例宽度比例", height_label = "图例高度比例", include_size = TRUE, header = NULL) {
  default_anchor <- as.numeric(default_anchor %||% c(0.95, 0.85, 0.13, 0.14))
  if (length(default_anchor) < 4 || any(is.na(default_anchor))) {
    default_anchor <- c(0.95, 0.85, 0.13, 0.14)
  }
  position_conditions <- paste(sprintf("input['%s'] === '%s'", ns(position_id), condition_positions), collapse = " || ")
  ui_parts <- Filter(Negate(is.null), list(
    if (!is.null(header) && nzchar(header)) shiny::tags$div(style = "margin-bottom: 6px; font-weight: 600;", header),
    shiny::fluidRow(
      shiny::column(6, shiny::sliderInput(ns(x_ratio_id), x_label, min = 0, max = 1, value = default_anchor[[1]], step = 0.01, width = "100%")),
      shiny::column(6, shiny::sliderInput(ns(y_ratio_id), y_label, min = 0, max = 1, value = default_anchor[[2]], step = 0.01, width = "100%"))
    )
  ))
  if (isTRUE(include_size)) {
    ui_parts <- c(
      ui_parts,
      list(
        shiny::fluidRow(
          shiny::column(6, shiny::sliderInput(ns(width_ratio_id), width_label, min = 0.1, max = 0.6, value = default_anchor[[3]], step = 0.01, width = "100%")),
          shiny::column(6, shiny::sliderInput(ns(height_ratio_id), height_label, min = 0.1, max = 0.6, value = default_anchor[[4]], step = 0.01, width = "100%"))
        )
      )
    )
  }
  do.call(shiny::conditionalPanel, c(list(condition = position_conditions), ui_parts))
}

graphics_aux_legend_compact_defaults <- list(
  row_gap = 1,
  plot_margin_pt = c(1, 3, 1, 3),
  title_margin_bottom = 1,
  inter_legend_spacer = 0.03,
  secondary_rel_height = 0.68
)

#' 临时暂停 showtext 并执行表达式
#'
#' showtext_auto() 启用后拦截所有字体解析，导致 rtables/formatters 内部的
#' Courier 等宽字体查找失败并回退到非等宽字体，触发 "non-monospace font" 错误。
#' 在渲染 rtables 文本输出或调用 print() 前临时关闭 showtext 即可避免此冲突。
#'
#' @param expr 要执行的表达式
#' @return expr 的返回值
graphics_with_showtext_paused <- function(expr) {
  showtext_active <- tryCatch({
    showtext::showtext_end()
    TRUE
  }, error = function(e) FALSE)
  on.exit(if (isTRUE(showtext_active)) showtext::showtext_auto(), add = TRUE)
  force(expr)
}

graphics_registered_font_families <- function() {
  if (!requireNamespace("sysfonts", quietly = TRUE)) return(character(0))
  tryCatch(sysfonts::font_families(), error = function(e) character(0))
}

graphics_has_registered_font_family <- function(family) {
  family <- trimws(as.character(graphics_first_value_or_default(family, "")))
  if (!nzchar(family)) return(FALSE)
  family %in% graphics_registered_font_families()
}

graphics_resolve_device_safe_family <- function(family = "sans") {
  resolved <- trimws(as.character(graphics_first_value_or_default(family, "sans")))
  if (!nzchar(resolved)) return("sans")

  # grid/cowplot may query PostScript metrics before showtext takes over.
  # Arial is commonly registered via showtext, but not present in the
  # PostScript font database used during grob measurement.
  family_alias <- c(
    "Arial" = "sans"
  )
  if (resolved %in% names(family_alias)) {
    resolved <- unname(family_alias[[resolved]])
  }
  if (!(resolved %in% c("sans", "serif", "mono")) && !graphics_has_registered_font_family(resolved)) {
    return("sans")
  }
  resolved
}

graphics_resolve_cjk_family <- function(cjk_family = "Noto Sans SC", fallback_family = "sans") {
  preferred <- trimws(as.character(graphics_first_value_or_default(cjk_family, "Noto Sans SC")))
  if (nzchar(preferred) && graphics_has_registered_font_family(preferred)) {
    return(preferred)
  }
  if (graphics_has_registered_font_family("Noto Sans SC")) {
    return("Noto Sans SC")
  }
  graphics_resolve_device_safe_family(fallback_family)
}

graphics_text_has_cjk <- function(text) {
  values <- as.character(text %||% character(0))
  if (length(values) == 0) return(logical(0))
  grepl("[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]", values, perl = TRUE)
}

graphics_build_legend_rows <- function(labels, row_gap = graphics_aux_legend_compact_defaults$row_gap) {
  labels <- as.character(labels %||% character(0))
  labels <- labels[nzchar(labels)]
  if (length(labels) == 0) {
    return(data.frame(label = character(0), y = numeric(0), stringsAsFactors = FALSE))
  }
  gap <- suppressWarnings(as.numeric(row_gap %||% graphics_aux_legend_compact_defaults$row_gap))
  if (is.na(gap) || !is.finite(gap) || gap <= 0) gap <- graphics_aux_legend_compact_defaults$row_gap
  data.frame(
    label = labels,
    y = rev(seq(1, by = gap, length.out = length(labels))),
    stringsAsFactors = FALSE
  )
}

graphics_build_point_legend_plot <- function(labels, colors, shape_value = 3, title = "", base_font_size = 10, row_gap = graphics_aux_legend_compact_defaults$row_gap, text_x = 0.17, point_x = 0.10, xlim = c(0, 1), compact_spec = graphics_aux_legend_compact_defaults, font_family = "sans") {
  labels <- as.character(labels %||% character(0))
  labels <- labels[nzchar(labels)]
  if (length(labels) == 0) return(NULL)
  color_vals <- unname(colors[labels])
  if (length(color_vals) != length(labels) || any(is.na(color_vals) | !nzchar(color_vals))) return(NULL)
  legend_df <- graphics_build_legend_rows(labels, row_gap = row_gap)
  legend_df$color <- color_vals
  font_family <- graphics_resolve_layout_family(font_family)
  
  y_max <- max(legend_df$y) + (row_gap / 2)
  y_min <- min(legend_df$y) - (row_gap / 2)
  
  plot_obj <- ggplot2::ggplot(legend_df, ggplot2::aes(y = y)) +
    ggplot2::geom_point(ggplot2::aes(x = point_x), shape = shape_value, size = max(2, base_font_size * 0.22), stroke = 0.7, color = legend_df$color) +
    ggplot2::geom_text(ggplot2::aes(x = text_x, label = label), hjust = 0, size = max(3, base_font_size * 0.24), family = font_family) +
    ggplot2::scale_y_continuous(limits = c(y_min, y_max), expand = c(0, 0)) +
    ggplot2::coord_cartesian(xlim = xlim, clip = "off") +
    ggplot2::theme_void(base_family = font_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = max(10, base_font_size), family = font_family, face = "bold", hjust = 0, margin = ggplot2::margin(0, 0, compact_spec$title_margin_bottom, 0)),
      plot.margin = do.call(ggplot2::margin, as.list(compact_spec$plot_margin_pt))
    )
  if (nzchar(trimws(title %||% ""))) {
    plot_obj <- plot_obj + ggplot2::ggtitle(title)
  }
  plot_obj
}

graphics_build_line_legend_plot <- function(labels, colors, title = "", line_size = 0.6, line_type = "solid", base_font_size = 10, row_gap = graphics_aux_legend_compact_defaults$row_gap, line_x = c(0.03, 0.10), text_x = 0.17, xlim = c(0, 1), compact_spec = graphics_aux_legend_compact_defaults, font_family = "sans") {
  labels <- as.character(labels %||% character(0))
  labels <- labels[nzchar(labels)]
  if (length(labels) == 0) return(NULL)
  color_vals <- unname(colors[labels])
  if (length(color_vals) != length(labels) || any(is.na(color_vals) | !nzchar(color_vals))) return(NULL)
  legend_df <- graphics_build_legend_rows(labels, row_gap = row_gap)
  legend_df$color <- color_vals
  font_family <- graphics_resolve_layout_family(font_family)
  
  y_max <- max(legend_df$y) + (row_gap / 2)
  y_min <- min(legend_df$y) - (row_gap / 2)
  
  plot_obj <- ggplot2::ggplot(legend_df, ggplot2::aes(y = y)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = line_x[[1]], xend = line_x[[2]], yend = y),
      linewidth = line_size,
      linetype = line_type,
      color = legend_df$color
    ) +
    ggplot2::geom_text(ggplot2::aes(x = text_x, label = label), hjust = 0, size = max(3, base_font_size * 0.24), family = font_family) +
    ggplot2::scale_y_continuous(limits = c(y_min, y_max), expand = c(0, 0)) +
    ggplot2::coord_cartesian(xlim = xlim, clip = "off") +
    ggplot2::theme_void(base_family = font_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = max(10, base_font_size), family = font_family, face = "bold", hjust = 0, margin = ggplot2::margin(0, 0, compact_spec$title_margin_bottom, 0)),
      plot.margin = do.call(ggplot2::margin, as.list(compact_spec$plot_margin_pt))
    )
  if (nzchar(trimws(title %||% ""))) {
    plot_obj <- plot_obj + ggplot2::ggtitle(title)
  }
  plot_obj
}

graphics_compose_stacked_legends <- function(primary_plot = NULL, secondary_plot = NULL, compact_spec = graphics_aux_legend_compact_defaults, primary_rows = 1, secondary_rows = 1) {
  legend_plot <- primary_plot
  if (!is.null(secondary_plot)) {
    if (is.null(legend_plot)) {
      legend_plot <- secondary_plot
    } else {
      spacer <- ggplot2::ggplot() + ggplot2::theme_void() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))
      legend_plot <- cowplot::plot_grid(
        legend_plot,
        spacer,
        secondary_plot,
        ncol = 1,
        align = "v",
        axis = "lr",
        rel_heights = c(primary_rows, compact_spec$inter_legend_spacer, secondary_rows)
      )
    }
  }
  legend_plot
}

graphics_place_aux_legend <- function(plot_obj, legend_plot = NULL, position = "right", outside_ratio = 0.35, inside_anchor = c(0.95, 0.85, 0.13, 0.14)) {
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

graphics_apply_legend_theme <- function(plot_obj, show_legend = TRUE, position = "right", inside_anchor = c(0.95, 0.85, 0.13, 0.14)) {
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

graphics_add_classic_axis_segments <- function(
  plot_obj,
  x_start,
  x_end,
  y_start,
  y_end,
  arrow = FALSE,
  linewidth = 0.45,
  color = "black"
) {
  if (is.null(plot_obj)) return(NULL)
  if (isTRUE(arrow)) {
    return(
      plot_obj +
        ggplot2::annotate(
          "segment",
          x = x_start,
          xend = x_end,
          y = y_start,
          yend = y_start,
          arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
          linewidth = linewidth,
          color = color
        ) +
        ggplot2::annotate(
          "segment",
          x = x_start,
          xend = x_start,
          y = y_start,
          yend = y_end,
          arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
          linewidth = linewidth,
          color = color
        )
    )
  }
  plot_obj +
    ggplot2::annotate(
      "segment",
      x = x_start,
      xend = x_end,
      y = y_start,
      yend = y_start,
      linewidth = linewidth,
      color = color,
      lineend = "square"
    ) +
    ggplot2::annotate(
      "segment",
      x = x_start,
      xend = x_start,
      y = y_start,
      yend = y_end,
      linewidth = linewidth,
      color = color,
      lineend = "square"
    )
}

graphics_apply_axis_style <- function(plot_obj, axis_style = "default", arrow_size = 0.15) {
  if (identical(axis_style, "classic_arrow")) {
    plot_obj <- plot_obj + ggplot2::theme(
      axis.line = ggplot2::element_line(colour = "black", lineend = "square", arrow = ggplot2::arrow(length = ggplot2::unit(arrow_size, "inches"), type = "closed"))
    )
  } else if (identical(axis_style, "classic")) {
    plot_obj <- plot_obj + ggplot2::theme(
      axis.line = ggplot2::element_line(colour = "black", lineend = "square")
    )
  }
  # "default" 使用主题默认样式
  plot_obj
}

graphics_format_percent_labels <- function(show_percent_sign = TRUE, scale_factor = 100, decimals = 1) {
  acc <- if (!is.null(decimals) && !is.na(decimals) && decimals >= 0) 10^(-decimals) else 0.1
  if (isTRUE(show_percent_sign)) {
    scales::label_number(accuracy = acc, suffix = "%", scale = scale_factor)
  } else {
    scales::label_number(accuracy = acc, scale = scale_factor)
  }
}

graphics_format_number_labels <- function(decimals = 1) {
  acc <- if (!is.null(decimals) && !is.na(decimals) && decimals >= 0) 10^(-decimals) else 0.1
  scales::label_number(accuracy = acc)
}

#' 通用时间范围滑块渲染器
#' @param ns Shiny 命名空间函数
#' @param time_var_name 用户选择的时间变量名
#' @param data 反应式数据源 (或 data.frame)
#' @param slider_id 内部滑块 ID (默认为 "time_range")
#' @param buffer 时间轴最大值缓冲区 (默认为 30)
#' @param selected_range 当前已选择的范围，可为响应式或长度为2的数值向量
graphics_resolve_time_range_slider_value <- function(selected_range = NULL, time_range_max, min_value = 0) {
  slider_max <- suppressWarnings(as.numeric(time_range_max))
  slider_min <- suppressWarnings(as.numeric(min_value))
  if (is.na(slider_min) || !is.finite(slider_min)) slider_min <- 0
  if (is.na(slider_max) || !is.finite(slider_max) || slider_max < slider_min) slider_max <- slider_min

  selected <- selected_range
  if (length(selected) == 2) {
    selected <- suppressWarnings(as.numeric(selected))
  }
  if (length(selected) != 2 || any(is.na(selected)) || any(!is.finite(selected))) {
    return(c(slider_min, slider_max))
  }

  selected <- sort(selected)
  selected[1] <- max(slider_min, min(selected[1], slider_max))
  selected[2] <- max(selected[1], min(selected[2], slider_max))
  selected
}

graphics_render_time_range_slider <- function(ns, time_var_name, data, slider_id = "time_range", buffer = 30, selected_range = NULL) {
  shiny::renderUI({
    resolved_time_var_name <- if (shiny::is.reactive(time_var_name)) time_var_name() else time_var_name
    df <- if (shiny::is.reactive(data)) data() else data
    
    if (is.null(resolved_time_var_name) || !nzchar(as.character(resolved_time_var_name %||% ""))) {
      shiny::helpText("请选择时间变量")
    } else if (is.null(df) || nrow(df) == 0) {
      shiny::helpText("没有可用的数据")
    } else if (resolved_time_var_name %in% names(df)) {
      time_var <- df[[resolved_time_var_name]]
      if (!is.null(time_var) && is.numeric(time_var)) {
        time_var <- time_var[!is.na(time_var)]
        if (length(time_var) > 0) {
          time_max <- max(time_var, na.rm = TRUE)
          time_range_max <- time_max + buffer
          selected <- if (shiny::is.reactive(selected_range)) selected_range() else selected_range
          selected <- graphics_resolve_time_range_slider_value(selected, time_range_max = time_range_max, min_value = 0)
          shiny::tagList(
            shiny::sliderInput(ns(slider_id), paste("时间范围 (最大值:", round(time_max, 2), ")"),
                        min = 0, max = time_range_max, value = selected),
            shiny::tags$script(shiny::HTML(sprintf("
              $(document).ready(function() {
                $('#%s').on('mousewheel DOMMouseScroll', function(e) { e.preventDefault(); e.stopPropagation(); });
                $('#%s').closest('.shiny-input-container').find('input').on('mousewheel DOMMouseScroll', function(e) { e.preventDefault(); e.stopPropagation(); });
              });
            ", ns(slider_id), ns(slider_id))))
          )
        } else { shiny::helpText("时间变量没有有效数据") }
      } else { shiny::helpText("请选择数值型时间变量") }
    } else { shiny::helpText("请选择时间变量") }
  })
}

#' 通用X轴步长应用器
#' @param plot_obj ggplot2对象
#' @param x_data X轴对应的数据向量，用于计算最大最小值
#' @param break_step 用户指定的步长，如果为0、NA或NULL则不生效
graphics_apply_x_break_step <- function(plot_obj, x_data, break_step) {
  step_val <- suppressWarnings(as.numeric(break_step %||% 0))
  if (!is.na(step_val) && step_val > 0 && length(x_data) > 0) {
    x_min <- min(x_data, na.rm = TRUE)
    x_max <- max(x_data, na.rm = TRUE)
    if (is.finite(x_min) && is.finite(x_max)) {
      x_from <- floor(x_min / step_val) * step_val
      x_to <- ceiling(x_max / step_val) * step_val
      plot_obj <- plot_obj + ggplot2::scale_x_continuous(breaks = seq(x_from, x_to, by = step_val))
    }
  }
  plot_obj
}

#' 导出格式前置依赖检测
#'
#' 检测指定导出格式所需的外部依赖是否可用。
#' - html/rtf: 需要 rmarkdown + pandoc
#' - pdf: 使用 R 原生 cairo_pdf 设备，零外部依赖，无需额外检测
#'
#' @param format 导出格式 ("html", "rtf", "pdf")
#' @return NULL 表示所有依赖可用；字符串表示错误信息
graphics_check_export_prerequisites <- function(format) {
  fmt <- tolower(if (is.null(format) || !nzchar(format)) "html" else format)

  # PDF 使用 R 原生路径 (save_table_pdf_native)，零外部依赖
  if (identical(fmt, "pdf")) {
    return(NULL)
  }

  if (fmt %in% c("html", "rtf")) {
    if (!requireNamespace("rmarkdown", quietly = TRUE)) {
      return("导出 HTML/RTF 需要安装 rmarkdown 包")
    }
    pandoc_available <- tryCatch({
      rmarkdown::pandoc_available()
    }, error = function(e) FALSE)
    if (!isTRUE(pandoc_available)) {
      return("导出 HTML/RTF 需要 pandoc，当前环境未检测到。请安装 RStudio 或 pandoc。")
    }
  }

  NULL
}

#' 表格 PNG 导出前置依赖检测
#'
#' @return NULL 表示 webshot2 可用；字符串表示错误信息
graphics_check_png_prerequisites <- function() {
  if (!requireNamespace("webshot2", quietly = TRUE)) {
    return("表格 PNG 导出需要 webshot2 包。请运行 install.packages('webshot2') 安装。")
  }
  NULL
}
