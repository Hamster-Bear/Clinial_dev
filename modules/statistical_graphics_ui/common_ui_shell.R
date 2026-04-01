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

graphics_export_size_controls_ui <- function(ns, download_id = "dl_plot", include_size_mode = TRUE) {
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
          column(3, numericInput(ns("export_width_in"), "导出宽度(英寸)", value = 13, min = 6, max = 30, step = 0.5, width = "100%")),
          column(3, numericInput(ns("export_height_in"), "导出高度(英寸)", value = 9, min = 4, max = 24, step = 0.5, width = "100%"))
        )
      ),
      downloadButton(ns(download_id), "下载图形", class = "btn-primary")
    ))
  }

  tagList(
    fluidRow(
      column(6, selectInput(ns("export_format"), "导出格式", choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")),
      column(6, numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
    ),
    downloadButton(ns(download_id), "下载图形", class = "btn-primary")
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
