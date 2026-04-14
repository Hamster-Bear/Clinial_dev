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
#' @param default_family 默认字体族 (默认为 "sans")
graphics_font_family_ui <- function(ns, id = "base_family", label = "全局字体", default_family = "sans") {
  selectInput(
    ns(id),
    label,
    choices = c(
      "无衬线体 (Sans)" = "sans",
      "衬线体 (Serif)" = "serif",
      "等宽体 (Mono)" = "mono",
      "Helvetica" = "Helvetica",
      "Times New Roman" = "Times",
      "Courier" = "Courier",
      "Arial" = "Arial"
    ),
    selected = default_family,
    width = "100%"
  )
}

#' 通用时间轴配置 UI
#' @param ns Shiny 命名空间函数
#' @param slider_id 滑块 UI 容器 ID (默认为 "time_range_slider")
#' @param step_id 步长输入框 ID (默认为 "time_step")
#' @param step_label 步长输入框标签
graphics_time_axis_controls_ui <- function(ns, slider_id = "time_range_slider", step_id = "time_step", step_label = "时间轴步长") {
  tagList(
    uiOutput(ns(slider_id)),
    numericInput(ns(step_id), step_label, value = NULL, min = 0, step = 1, width = "100%")
  )
}
