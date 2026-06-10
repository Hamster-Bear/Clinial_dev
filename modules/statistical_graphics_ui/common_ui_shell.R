graphics_config_tabs_box <- function(id, title, tabs, status = "primary", collapsed = TRUE) {
  ns <- NS(id)
  box(
    width = 12,
    title = title,
    status = status,
    solidHeader = TRUE,
    collapsible = TRUE,
    collapsed = collapsed,
    do.call(tabsetPanel, c(list(id = ns("config_tabs")), tabs))
  )
}

graphics_export_size_controls_ui <- function(ns, download_id = "dl_plot", include_size_mode = TRUE, include_download_button = TRUE) {
  if (isTRUE(include_size_mode)) {
    return(tagList(
      fluidRow(
        column(4, selectInput(ns("size_mode"), "尺寸模式", choices = c("宽图标准" = "wide_standard", "自定义尺寸" = "custom"), selected = "wide_standard", width = "100%")),
        column(4, selectInput(ns("export_format"), "导出格式", choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")),
        column(4, numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
      ),
      conditionalPanel(
        condition = sprintf("input['%s'] === 'custom'", ns("size_mode")),
        fluidRow(
          column(3, numericInput(ns("static_width_px"), "静态图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
          column(3, numericInput(ns("static_height_px"), "静态图基础高度(px)", value = 760, min = 400, max = 1800, step = 20, width = "100%")),
          column(3, numericInput(ns("interactive_width_px"), "交互图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
          column(3, numericInput(ns("interactive_height_px"), "交互图高度(px)", value = 620, min = 350, max = 1600, step = 20, width = "100%"))
        ),
        fluidRow(
          column(4, checkboxInput(ns("sync_export_size"), "导出尺寸跟随前端画布", value = TRUE, width = "100%")),
          column(4, numericInput(ns("size_sync_ppi"), "PX/英寸换算", value = 96, min = 72, max = 300, step = 1, width = "100%")),
          column(4, checkboxInput(ns("canvas_border"), "显示画布边框", value = TRUE, width = "100%"))
        ),
        conditionalPanel(
          condition = sprintf("input['%s'] === false", ns("sync_export_size")),
          fluidRow(
            column(3, numericInput(ns("export_width_in"), "导出宽度(英寸)", value = 12.5, min = 6, max = 30, step = 0.5, width = "100%")),
            column(3, numericInput(ns("export_height_in"), "导出高度(英寸)", value = 7.9, min = 4, max = 24, step = 0.5, width = "100%"))
          )
        ),
        fluidRow(
          column(3, numericInput(ns("page_margin_top_px"), "上边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
          column(3, numericInput(ns("page_margin_right_px"), "右边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
          column(3, numericInput(ns("page_margin_bottom_px"), "下边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
          column(3, numericInput(ns("page_margin_left_px"), "左边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%"))
        ),
        helpText("默认按 PX/英寸换算同步导出尺寸，并保持前端静态图与导出比例一致。")
      ),
      if (isTRUE(include_download_button)) downloadButton(ns(download_id), "下载图形", class = "btn-primary")
    ))
  }

  tagList(
    fluidRow(
      column(6, selectInput(ns("export_format"), "导出格式", choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")),
      column(6, numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
    ),
    if (isTRUE(include_download_button)) downloadButton(ns(download_id), "下载图形", class = "btn-primary")
  )
}

graphics_centered_output_container <- function(
  content,
  frame_width_px,
  frame_height_px = NULL,
  canvas_config = list(),
  use_canvas_border = FALSE
) {
  width_px <- suppressWarnings(as.numeric(frame_width_px %||% 1200))
  height_px <- suppressWarnings(as.numeric(frame_height_px %||% 0))
  if (is.na(width_px) || !is.finite(width_px) || width_px <= 0) width_px <- 1200
  if (is.na(height_px) || !is.finite(height_px) || height_px < 0) height_px <- 0

  border_css <- ""
  if (isTRUE(use_canvas_border) && isTRUE(canvas_config$canvas_border %||% TRUE)) {
    border_css <- sprintf(
      "border: %.1fpx solid %s; background: %s; box-sizing: border-box;",
      suppressWarnings(as.numeric(canvas_config$canvas_border_size %||% 0.8)),
      as.character(canvas_config$canvas_border_color %||% "#D9D9D9"),
      as.character(canvas_config$canvas_background %||% "white")
    )
  }

  tags$div(
    style = "display:flex; justify-content:center; width:100%; overflow-x:auto;",
    tags$div(
      style = paste0(
        "width:", width_px, "px; max-width:100%; margin:0 auto;",
        if (height_px > 0) paste0(" min-height:", height_px, "px;") else "",
        border_css
      ),
      content
    )
  )
}

graphics_primary_action_button_ui <- function(ns, input_id, label = "生成图形", icon_name = "chart-line") {
  actionButton(
    ns(input_id),
    label,
    icon = icon(icon_name),
    class = "btn-primary btn-block",
    style = "font-weight: bold; margin-bottom: 12px;"
  )
}

graphics_output_action_bar_ui <- function(
  ns,
  render_button_id = "render_plot",
  render_button_label = "生成图形",
  render_button_icon = "chart-line",
  download_id = "dl_plot",
  download_label = "下载图形",
  include_render_button = TRUE,
  include_download_button = TRUE
) {
  fluidRow(
    if (isTRUE(include_render_button)) {
      column(
        if (isTRUE(include_download_button)) 6 else 12,
        div(
          style = "text-align:left; margin-bottom:10px;",
          actionButton(
            ns(render_button_id),
            render_button_label,
            icon = icon(render_button_icon),
            class = "btn-primary"
          )
        )
      )
    },
    if (isTRUE(include_download_button)) {
      column(
        if (isTRUE(include_render_button)) 6 else 12,
        div(
          style = if (isTRUE(include_render_button)) "text-align:right; margin-bottom:10px;" else "text-align:left; margin-bottom:10px;",
          downloadButton(ns(download_id), download_label, class = "btn-primary")
        )
      )
    }
  )
}

#' 通用参考线配置 UI
#' @param ns Shiny 命名空间函数
#' @param id_prefix 控件 ID 前缀 (如 "ref", "recist_lower")
#' @param label 参考线显示名称
#' @param default_value 默认位置数值
#' @param default_color 默认线条颜色
#' @param default_linetype 默认线型
#' @param default_linewidth 默认线宽
graphics_reference_line_ui <- function(ns, id_prefix, label = "参考线", default_value = 0, 
                                      default_color = "#D7191C", default_linetype = "dashed", default_linewidth = 0.8) {
  tagList(
    fluidRow(
      column(4, numericInput(ns(id_prefix), label, value = default_value, step = 1, width = "100%")),
      column(4, colourpicker::colourInput(ns(paste0(id_prefix, "_color")), paste0(label, "颜色"), value = default_color, width = "100%")),
      column(4, selectInput(ns(paste0(id_prefix, "_linetype")), paste0(label, "线型"), 
                            choices = c("虚线" = "dashed", "实线" = "solid", "点线" = "dotted", "点划线" = "dotdash", "长虚线" = "longdash", "两短线" = "twodash"), 
                            selected = default_linetype, width = "100%"))
    ),
    fluidRow(
      column(12, numericInput(ns(paste0(id_prefix, "_linewidth")), paste0(label, "线宽"), value = default_linewidth, min = 0.1, max = 3.0, step = 0.1, width = "100%"))
    )
  )
}

#' 通用字体配置 UI
#' @param ns Shiny 命名空间函数
#' @param id 控件 ID (默认为 "base_family")
#' @param label 控件显示名称 (默认为 "全局字体")
#' @param default_family 默认字体族 (默认为 "Noto Sans SC")
graphics_font_family_choices <- function() {
  c(
    "中文推荐 (Noto Sans SC)" = "Noto Sans SC",
    "无衬线体 (Sans)" = "sans",
    "衬线体 (Serif)" = "serif",
    "等宽体 (Mono)" = "mono",
    "Helvetica" = "Helvetica",
    "Times New Roman" = "Times",
    "Courier" = "Courier",
    "Arial" = "Arial"
  )
}

graphics_font_family_ui <- function(ns, id = "base_family", label = "全局字体", default_family = "Noto Sans SC") {
  selectInput(
    ns(id),
    label,
    choices = graphics_font_family_choices(),
    selected = default_family,
    width = "100%"
  )
}

graphics_cjk_font_family_choices <- function() {
  c(
    "中文推荐 (Noto Sans SC)" = "Noto Sans SC",
    "微软雅黑 (Microsoft YaHei)" = "Microsoft YaHei",
    "黑体 (SimHei)" = "SimHei",
    "无衬线兜底 (Sans)" = "sans",
    "衬线兜底 (Serif)" = "serif",
    "等宽兜底 (Mono)" = "mono"
  )
}

graphics_font_family_pair_ui <- function(ns, latin_id = "base_family", cjk_id = "cjk_family", latin_label = "西文字体", cjk_label = "中文字体", latin_default = "sans", cjk_default = "Noto Sans SC") {
  shiny::fluidRow(
    shiny::column(
      6,
      shiny::selectInput(
        ns(latin_id),
        latin_label,
        choices = graphics_font_family_choices(),
        selected = latin_default,
        width = "100%"
      )
    ),
    shiny::column(
      6,
      shiny::selectInput(
        ns(cjk_id),
        cjk_label,
        choices = graphics_cjk_font_family_choices(),
        selected = cjk_default,
        width = "100%"
      )
    )
  )
}

graphics_card_panel_ui <- function(title, body, status_class = "default") {
  tags$div(
    class = "app-card__panel",
    tags$strong(title),
    tags$div(style = "margin-top: 6px;", body)
  )
}

graphics_mapping_field_ui <- function(ns, field_spec) {
  input_type <- field_spec$type %||% "selectize"
  input_id <- field_spec$id
  label <- field_spec$label %||% input_id
  choices <- field_spec$choices %||% NULL
  width <- field_spec$width %||% "100%"
  multiple <- isTRUE(field_spec$multiple)
  selected <- field_spec$selected %||% NULL
  options <- field_spec$options %||% list()
  placeholder <- field_spec$placeholder %||% NULL
  if (!is.null(placeholder) && is.null(options$placeholder)) {
    options$placeholder <- placeholder
  }
  switch(
    input_type,
    "select" = selectInput(ns(input_id), label, choices = choices, selected = selected, width = width),
    "selectize" = selectizeInput(ns(input_id), label, choices = choices, selected = selected, multiple = multiple, options = options, width = width),
    "text" = textInput(ns(input_id), label, value = selected %||% field_spec$value %||% "", width = width),
    "textarea" = textAreaInput(ns(input_id), label, value = selected %||% field_spec$value %||% "", rows = field_spec$rows %||% 2, width = width),
    "color" = colourpicker::colourInput(ns(input_id), label, value = selected %||% field_spec$value %||% "#000000", width = width),
    "slider" = sliderInput(
      ns(input_id),
      label,
      min = field_spec$min %||% 0,
      max = field_spec$max %||% 1,
      value = suppressWarnings(as.numeric(selected %||% field_spec$value %||% field_spec$min %||% 0)),
      step = field_spec$step %||% 0.1,
      width = width
    ),
    "numeric" = numericInput(
      ns(input_id),
      label,
      value = suppressWarnings(as.numeric(selected %||% field_spec$value %||% NA_real_)),
      min = field_spec$min %||% NA,
      max = field_spec$max %||% NA,
      step = field_spec$step %||% NA,
      width = width
    ),
    "checkbox" = checkboxInput(ns(input_id), label, value = isTRUE(field_spec$value)),
    "radio" = radioButtons(ns(input_id), label, choices = choices, selected = selected, inline = isTRUE(field_spec$inline), width = width),
    stop(sprintf("不支持的映射字段类型: %s", input_type))
  )
}

graphics_column_mapping_panel_ui <- function(ns, title = "数据映射", fields, help_text = NULL, extra_ui = NULL, status_class = "default") {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_table_panel_ui <- function(
  ns,
  title = "表格显示设置",
  selection_id = "selected_table_cols",
  selection_label = "表格列选择",
  choices = NULL,
  selected = NULL,
  placeholder = "点击选择表格列...",
  config_title = "列显示配置",
  config_ui = NULL,
  help_text = NULL,
  extra_ui = NULL,
  status_class = "default"
) {
  body <- tagList(
    if (!is.null(help_text)) helpText(help_text),
    selectizeInput(
      ns(selection_id),
      selection_label,
      choices = choices,
      selected = selected,
      multiple = TRUE,
      options = list(
        placeholder = placeholder,
        onInitialize = I("function() { this.setValue(''); }")
      ),
      width = "100%"
    ),
    if (!is.null(config_ui)) {
      tagList(
        hr(),
        graphics_card_panel_ui(config_title, config_ui)
      )
    },
    extra_ui
  )
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_display_legend_panel_ui <- function(
  ns,
  title = "显示与图例",
  fields,
  prepend_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(prepend_ui, rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_palette_choice_values <- function(kind = c("qualitative", "tracks")) {
  kind <- match.arg(kind)
  switch(
    kind,
    qualitative = c("默认Hue" = "hue", "Set1" = "Set1", "Set2" = "Set2", "Set3" = "Set3", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
    tracks = c("默认Hue" = "hue", "Set3" = "Set3", "Paired" = "Paired", "Dark2" = "Dark2", "Viridis" = "viridis")
  )
}

graphics_palette_layout_panel_ui <- function(
  ns,
  title = "配色与布局",
  fields,
  prepend_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(prepend_ui, rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_axis_proportion_panel_ui <- function(
  ns,
  title = "坐标与比例",
  fields,
  prepend_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(prepend_ui, rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_reference_threshold_panel_ui <- function(
  ns,
  title = "参考线与阈值",
  toggle_id = "show_reference_lines",
  toggle_label = "显示参考线",
  toggle_value = TRUE,
  conditional_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  body <- tagList(
    checkboxInput(ns(toggle_id), toggle_label, toggle_value),
    conditionalPanel(
      condition = paste0("input['", ns(toggle_id), "'] == true"),
      conditional_ui
    ),
    extra_ui,
    if (!is.null(help_text)) helpText(help_text)
  )
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_point_shape_choices <- function() {
  c("+" = 3, "I" = 124, "□" = 0, "○" = 1, "△" = 2, "◇" = 5, "☆" = 8)
}

graphics_symbol_style_panel_ui <- function(
  ns,
  title = "符号与样式",
  fields,
  prepend_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(prepend_ui, rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_group_style_mode_choices <- function() {
  c("随机且不重复" = "random_unique", "单一指定" = "single", "分别指定" = "manual_each")
}

graphics_group_style_mapping_panel_ui <- function(title, body, status_class = "default") {
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_group_style_rule_ui <- function(
  session,
  mode_input_id,
  mode_label,
  selected_mode = "random_unique",
  single_input_id = NULL,
  single_input_label = NULL,
  single_input_type = "color",
  single_value = NULL,
  single_choices = NULL,
  manual_each_ui = NULL
) {
  ns <- session$ns
  tagList(
    selectInput(
      ns(mode_input_id),
      mode_label,
      choices = graphics_group_style_mode_choices(),
      selected = selected_mode,
      width = "100%"
    ),
    if (!is.null(single_input_id) && !is.null(single_input_label)) {
      conditionalPanel(
        condition = sprintf("input['%s'] === 'single'", ns(mode_input_id)),
        graphics_mapping_field_ui(
          ns,
          list(
            id = single_input_id,
            label = single_input_label,
            type = single_input_type,
            value = single_value,
            selected = single_value,
            choices = single_choices
          )
        )
      )
    },
    if (!is.null(manual_each_ui)) {
      conditionalPanel(
        condition = sprintf("input['%s'] === 'manual_each'", ns(mode_input_id)),
        manual_each_ui
      )
    }
  )
}

graphics_text_label_panel_ui <- function(
  ns,
  title = "文本与标签",
  fields,
  prepend_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(prepend_ui, rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_palette_layout_panel_ui <- function(
  ns,
  title = "配色与布局",
  fields,
  prepend_ui = NULL,
  extra_ui = NULL,
  help_text = NULL,
  status_class = "default"
) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_mapping_field_ui(ns, field_spec)
        )
      })
    )
  })
  body <- tagList(prepend_ui, rows, extra_ui, if (!is.null(help_text)) helpText(help_text))
  graphics_card_panel_ui(title, body, status_class = status_class)
}

#' 通用时间轴配置 UI
#' @param ns Shiny 命名空间函数
#' @param slider_id 滑块 UI 容器 ID (默认为 "time_range_slider")
#' @param step_id 步长输入框 ID (默认为 "time_step")
#' @param step_label 步长输入框标签
graphics_time_axis_controls_ui <- function(ns, slider_id = "time_range_slider", step_id = "time_step", step_label = "时间轴步长", include_step_input = TRUE) {
  controls <- list(
    uiOutput(ns(slider_id))
  )
  if (isTRUE(include_step_input)) {
    controls[[length(controls) + 1]] <- numericInput(ns(step_id), step_label, value = NULL, min = 0, step = 1, width = "100%")
  }
  do.call(tagList, controls)
}

graphics_axis_range_controls_ui <- function(
  ns,
  min_id = "x_min",
  max_id = "x_max",
  axis_label = "X轴",
  min_value = 0,
  max_value = 100,
  min_step = 1,
  max_step = 1
) {
  fluidRow(
    column(6, numericInput(ns(min_id), paste0(axis_label, "下限"), value = min_value, step = min_step, width = "100%")),
    column(6, numericInput(ns(max_id), paste0(axis_label, "上限"), value = max_value, step = max_step, width = "100%"))
  )
}

graphics_axis_tick_format_controls_ui <- function(
  ns,
  break_id = NULL,
  break_label = "X轴刻度步长",
  break_value = 0,
  break_min = 0,
  break_step = 0.1,
  decimals_id = NULL,
  decimals_label = "X轴小数位数",
  decimals_value = 1,
  percent_id = NULL,
  percent_label = "显示百分号(%)",
  percent_value = FALSE
) {
  controls <- list()
  if (!is.null(break_id)) {
    controls[[length(controls) + 1]] <- column(6, numericInput(ns(break_id), break_label, value = break_value, min = break_min, step = break_step, width = "100%"))
  }
  if (!is.null(decimals_id)) {
    controls[[length(controls) + 1]] <- column(if (is.null(break_id)) 6 else 6, numericInput(ns(decimals_id), decimals_label, value = decimals_value, min = 0, max = 5, step = 1, width = "100%"))
  } else if (!is.null(percent_id)) {
    controls[[length(controls) + 1]] <- column(if (is.null(break_id)) 6 else 6, checkboxInput(ns(percent_id), percent_label, value = percent_value))
  }
  if (!is.null(percent_id) && !is.null(decimals_id)) {
    controls[[length(controls) + 1]] <- column(if (is.null(break_id)) 6 else 12, checkboxInput(ns(percent_id), percent_label, value = percent_value))
  }
  do.call(fluidRow, controls)
}

graphics_time_axis_settings_ui <- function(
  ns,
  unit_id,
  unit_label = "时间单位换算",
  unit_choices,
  selected_unit = NULL,
  step_id = "x_break_step",
  step_label = "X轴刻度步长",
  step_value = 0,
  step_min = 0,
  step_step = 0.1
) {
  fluidRow(
    column(6, selectInput(ns(unit_id), unit_label, choices = unit_choices, selected = selected_unit, width = "100%")),
    column(6, numericInput(ns(step_id), step_label, value = step_value, min = step_min, step = step_step, width = "100%"))
  )
}

graphics_time_axis_panel_ui <- function(
  ns,
  title = "时间轴设置",
  unit_id,
  unit_choices,
  selected_unit = NULL,
  unit_label = "时间单位换算",
  step_id = "x_break_step",
  step_label = "X轴刻度步长",
  step_value = 0,
  step_min = 0,
  step_step = 0.1,
  include_range_slider = FALSE,
  slider_id = "time_range_slider",
  slider_step_id = "time_step",
  slider_step_label = "时间轴步长",
  include_slider_step_input = FALSE,
  extra_ui = NULL,
  status_class = "default"
) {
  body <- tagList(
    graphics_time_axis_settings_ui(
      ns = ns,
      unit_id = unit_id,
      unit_label = unit_label,
      unit_choices = unit_choices,
      selected_unit = selected_unit,
      step_id = step_id,
      step_label = step_label,
      step_value = step_value,
      step_min = step_min,
      step_step = step_step
    ),
    if (isTRUE(include_range_slider)) {
      graphics_time_axis_controls_ui(
        ns = ns,
        slider_id = slider_id,
        step_id = slider_step_id,
        step_label = slider_step_label,
        include_step_input = include_slider_step_input
      )
    },
    extra_ui
  )
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_export_panel_ui <- function(
  ns,
  title = "输出与导出",
  render_button_id = "render_plot",
  render_button_label = "生成图形",
  render_button_icon = "chart-line",
  download_id = "dl_plot",
  include_render_button = TRUE,
  include_size_mode = TRUE,
  include_download_button = TRUE,
  extra_ui = NULL,
  status_class = "default"
) {
  body <- tagList(
    if (isTRUE(include_render_button)) graphics_primary_action_button_ui(ns, render_button_id, render_button_label, render_button_icon),
    graphics_export_size_controls_ui(
      ns = ns,
      download_id = download_id,
      include_size_mode = include_size_mode,
      include_download_button = include_download_button
    ),
    extra_ui
  )
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_dynamic_mapping_row_ui <- function(title, body, status_class = "default") {
  tags$div(
    class = "app-card__panel",
    tags$strong(title),
    tags$div(style = "margin-top: 6px;", body)
  )
}

graphics_dynamic_mapping_field_input_ui <- function(ns, field_spec) {
  input_type <- field_spec$type %||% "selectize"
  input_id <- field_spec$id
  label <- field_spec$label %||% input_id
  choices <- field_spec$choices %||% NULL
  selected <- field_spec$selected %||% NULL
  width <- field_spec$width %||% "100%"
  multiple <- isTRUE(field_spec$multiple)
  options <- field_spec$options %||% list()
  switch(
    input_type,
    "select" = selectInput(ns(input_id), label, choices = choices, selected = selected, width = width),
    "selectize" = selectizeInput(ns(input_id), label, choices = choices, selected = selected, multiple = multiple, options = options, width = width),
    "text" = textInput(ns(input_id), label, value = selected %||% "", width = width),
    "numeric" = numericInput(ns(input_id), label, value = suppressWarnings(as.numeric(selected %||% field_spec$value %||% NA_real_)), min = field_spec$min %||% NA, max = field_spec$max %||% NA, step = field_spec$step %||% NA, width = width),
    stop(sprintf("不支持的动态映射字段类型: %s", input_type))
  )
}

graphics_dynamic_mapping_fields_ui <- function(ns, fields) {
  rows <- lapply(fields, function(row_specs) {
    fluidRow(
      lapply(row_specs, function(field_spec) {
        column(
          field_spec$column %||% 12,
          graphics_dynamic_mapping_field_input_ui(ns, field_spec)
        )
      })
    )
  })
  tagList(rows)
}

graphics_build_overlay_point_layer_fields_spec <- function(
  row_index,
  time_choices,
  type_choices,
  label_choices,
  selected_time = "",
  selected_type = "",
  selected_label = "",
  selected_legend_title = ""
) {
  list(
    list(
      list(
        id = paste0("event_time_", row_index),
        label = tags$span("事件时间变量 [数值/日期]", title = "该事件组的发生时间"),
        type = "selectize",
        choices = c("无" = "", time_choices),
        selected = selected_time %||% "",
        column = 6
      ),
      list(
        id = paste0("event_type_", row_index),
        label = tags$span("事件类型变量 [字符/因子]", title = "该事件组的类别变量"),
        type = "selectize",
        choices = c("无" = "", type_choices),
        selected = selected_type %||% "",
        column = 6
      )
    ),
    list(
      list(
        id = paste0("event_label_", row_index),
        label = tags$span("事件标签变量 [字符，可选]", title = "事件点旁展示的文本"),
        type = "selectize",
        choices = c("无" = "", label_choices),
        selected = selected_label %||% "",
        column = 12
      )
    ),
    list(
      list(
        id = paste0("event_legend_title_", row_index),
        label = paste0("事件图例主标题(组", row_index, ")"),
        type = "text",
        selected = selected_legend_title %||% "",
        column = 12
      )
    )
  )
}

graphics_build_event_mapping_fields_spec <- function(
  row_index,
  time_choices,
  type_choices,
  label_choices,
  selected_time = "",
  selected_type = "",
  selected_label = "",
  selected_legend_title = ""
) {
  graphics_build_overlay_point_layer_fields_spec(
    row_index = row_index,
    time_choices = time_choices,
    type_choices = type_choices,
    label_choices = label_choices,
    selected_time = selected_time,
    selected_type = selected_type,
    selected_label = selected_label,
    selected_legend_title = selected_legend_title
  )
}

graphics_dynamic_mapping_rows_panel_ui <- function(
  ns,
  title = "动态映射",
  rows_ui,
  add_button_id = "add_mapping_row",
  remove_button_id = "remove_mapping_row",
  add_label = "添加映射",
  remove_label = "减少映射",
  help_text = NULL,
  status_class = "default"
) {
  body <- tagList(
    fluidRow(
      column(6, actionButton(ns(add_button_id), add_label, class = "btn-primary btn-sm")),
      column(6, actionButton(ns(remove_button_id), remove_label, class = "btn-default btn-sm"))
    ),
    br(),
    rows_ui,
    if (!is.null(help_text)) helpText(help_text)
  )
  graphics_card_panel_ui(title, body, status_class = status_class)
}

graphics_collect_axis_range_config <- function(input, min_id = "x_min", max_id = "x_max") {
  list(
    min = suppressWarnings(as.numeric(input[[min_id]])),
    max = suppressWarnings(as.numeric(input[[max_id]]))
  )
}

graphics_collect_axis_tick_config <- function(input, break_id = "x_break_step", decimals_id = NULL, percent_id = NULL) {
  list(
    break_step = suppressWarnings(as.numeric(input[[break_id]])),
    decimals = if (!is.null(decimals_id)) suppressWarnings(as.numeric(input[[decimals_id]])) else NULL,
    show_percent = if (!is.null(percent_id)) isTRUE(input[[percent_id]]) else NULL
  )
}

graphics_collect_time_axis_config <- function(input, unit_id = NULL, break_id = "x_break_step") {
  list(
    unit = if (!is.null(unit_id)) as.character(input[[unit_id]] %||% "") else NULL,
    break_step = suppressWarnings(as.numeric(input[[break_id]]))
  )
}
