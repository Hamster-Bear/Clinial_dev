library(ggplot2)
library(plotly)
library(DT)
library(dplyr)
library(scales)

if (!exists("app_card_box", mode = "function") ||
    !exists("app_card_note", mode = "function") ||
    !exists("app_result_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}
if (file.exists("modules/common/graphics/graphics_result_copy.R")) {
  source("modules/common/graphics/graphics_result_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics", "graphics_result_copy.R"))
}
if (file.exists("modules/common/graphics/graphics_export_copy.R")) {
  source("modules/common/graphics/graphics_export_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics", "graphics_export_copy.R"))
}

spider_plot_ui <- function(id) {
  ns <- NS(id)
  copy <- GRAPHICS_RESULT_COPY$spider
  export_copy <- GRAPHICS_EXPORT_COPY$spider

  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "设置核心映射、分组与分面变量",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("选择受试者、时间、变化值、颜色分组和分面变量。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "核心映射",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "核心映射",
                    fields = list(
                      list(list(id = "subject_id", label = tags$span("受试者ID变量 [字符/因子]", title = "每条轨迹所属受试者ID"), type = "selectize")),
                      list(list(id = "time_var", label = tags$span("时间变量 [数值/日期]", title = "纵向时间轴变量，支持数值或日期"), type = "selectize")),
                      list(list(id = "value_var", label = tags$span("变化值变量 [数值]", title = "连续数值型终点，通常为较基线变化百分比"), type = "selectize"))
                    ),
                    help_text = "提示：将鼠标悬停在字段标签上可查看变量类型要求。"
                  )
                ),
                tabPanel(
                  "分组/分面/附加变量",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "分组/分面/附加变量",
                    fields = list(
                      list(list(id = "line_color_by", label = tags$span("线条颜色分组 [字符/因子，可选]", title = "按分组上色展示不同亚组轨迹"), type = "selectize")),
                      list(list(id = "facet_var", label = tags$span("分面变量 [字符/因子，可选]", title = "按分面变量拆分子图"), type = "selectize"))
                    ),
                    help_text = "蜘蛛图当前不提供轨道变量；附加分组与分面变量在此页签中设置。"
                  )
                )
              )
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "图形与样式",
          subtitle = "设置标题、坐标、样式与 RECIST 阈值",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置时间单位、Y 轴标签格式、点层样式、末次标签和 RECIST 参考线。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "标题与说明",
                  br(),
                  graphics_text_label_panel_ui(
                    ns,
                    title = "标题与说明",
                    fields = list(
                      list(list(id = "plot_title", label = "主标题", type = "text", selected = "蜘蛛图")),
                      list(list(id = "plot_subtitle", label = "副标题", type = "text", selected = "")),
                      list(list(id = "plot_caption", label = "脚注", type = "text", selected = ""))
                    )
                  )
                ),
                tabPanel(
                  "显示与坐标",
                  br(),
                  graphics_display_legend_panel_ui(
                    ns,
                    title = "显示与坐标",
                    fields = list(
                      list(list(id = "show_legend", label = "显示图例", type = "checkbox", value = TRUE)),
                      list(list(id = "axis_style", label = "坐标轴样式", type = "select", choices = c("默认" = "default", "经典坐标轴(不带箭头)" = "classic", "经典XY轴(箭头)" = "classic_arrow"), selected = "default")),
                      list(list(id = "show_grid_lines", label = "显示网格线", type = "checkbox", value = TRUE))
                    ),
                    prepend_ui = graphics_legend_controls_ui(ns, title_id = "legend_title", position_id = "legend_position", position_kind = "outer", default_position = "right"),
                    extra_ui = tagList(
                      fluidRow(
                        column(6, textInput(ns("plot_xlab"), "X轴标签", value = "时间", width = "100%")),
                        column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "较基线变化(%)", width = "100%"))
                      ),
                      graphics_time_axis_panel_ui(
                        ns,
                        title = "时间轴设置",
                        unit_id = "time_unit",
                        unit_label = "时间单位换算",
                        unit_choices = c("原始数值/天" = "day", "周" = "week", "月(30.44天)" = "month", "年(365.25天)" = "year"),
                        selected_unit = "day",
                        step_id = "x_break_step",
                        step_label = "X轴刻度步长",
                        step_value = 0,
                        step_min = 0,
                        step_step = 0.1
                      ),
                      graphics_axis_proportion_panel_ui(
                        ns,
                        title = "Y轴与字号",
                        fields = list(
                          list(
                            list(id = "y_breaks_n", label = "Y轴刻度数量", type = "numeric", value = 9, min = 4, max = 20, step = 1, column = 4),
                            list(id = "y_break_step", label = "Y轴刻度步长", type = "numeric", value = 0, min = 0, step = 0.1, column = 4),
                            list(id = "base_font_size", label = "全局字号", type = "numeric", value = 12, min = 8, max = 22, step = 1, column = 4)
                          )
                        )
                      ),
                      fluidRow(
                        column(6, checkboxInput(ns("use_percent_label"), "Y轴标签按百分比格式显示", TRUE)),
                        column(6, conditionalPanel(
                          condition = paste0("input['", ns("use_percent_label"), "'] == true"),
                          checkboxInput(ns("y_show_percent_sign"), "标签带百分号(%)", value = TRUE)
                        ))
                      ),
                      fluidRow(
                        column(6, numericInput(ns("y_decimals"), "Y轴保留小数位数", value = 1, min = 0, max = 5, step = 1, width = "100%")),
                        column(6, graphics_font_family_pair_ui(ns, latin_id = "base_family", cjk_id = "cjk_family"))
                      ),
                      helpText("这里只控制 Y 轴标签显示格式，不会对原始变化值重新换算。")
                    )
                  )
                ),
                tabPanel(
                  "图层样式",
                  br(),
                  graphics_palette_layout_panel_ui(
                    ns,
                    title = "图层样式",
                    prepend_ui = tagList(
                      fluidRow(
                        column(4, checkboxInput(ns("show_points"), "显示测量点", value = FALSE)),
                        column(4, checkboxInput(ns("show_end_labels"), "显示每条轨迹末次受试者标签", value = FALSE)),
                        column(4, checkboxInput(ns("add_baseline_zero"), "为每条轨迹补充基线原点(time=0, value=0)", value = FALSE))
                      )
                    ),
                    fields = list(
                      list(list(id = "line_linetype", label = "线条样式", type = "select", choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted", "点划线" = "dotdash", "长虚线" = "longdash"), selected = "solid")),
                      list(list(id = "line_palette", label = "线条调色板", type = "select", choices = graphics_palette_choice_values("qualitative"), selected = "Set1")),
                      list(
                        list(id = "line_size", label = "线宽", type = "slider", value = 0.9, min = 0.4, max = 3, step = 0.1, column = 6),
                        list(id = "line_alpha", label = "线条透明度", type = "slider", value = 0.8, min = 0.2, max = 1, step = 0.05, column = 6)
                      ),
                      list(list(id = "point_size", label = "点大小", type = "slider", value = 1.8, min = 0.5, max = 6, step = 0.1))
                    )
                  )
                ),
                tabPanel(
                  "参考线与阈值",
                  br(),
                  graphics_reference_threshold_panel_ui(
                    ns,
                    title = "参考线与阈值",
                    toggle_id = "show_recist",
                    toggle_label = "显示RECIST阈值线",
                    toggle_value = TRUE,
                    conditional_ui = tagList(
                      graphics_reference_line_ui(ns, "recist_lower", label = "下阈值", default_value = -30, default_color = "#2C7BB6", default_linewidth = 0.7),
                      graphics_reference_line_ui(ns, "recist_upper", label = "上阈值", default_value = 20, default_color = "#D7191C", default_linewidth = 0.7)
                    )
                  )
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
                      ),
                      helpText("默认按 PX/英寸换算同步导出尺寸，并保持前端静态图与导出比例一致。")
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
                      )
                    )
                  )
                )
              )
          )
        )
      )
    ),
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
          graphics_output_action_bar_ui(ns, render_button_id = "render_plot", download_id = "dl_plot"),
          tabsetPanel(
            id = ns("output_tabs"),
            tabPanel(
              "静态图",
              app_result_panel(
                title = "静态图结果",
                note = copy$static_plot$note,
                tone = "success",
                uiOutput(ns("static_plot_ui"))
              )
            ),
            tabPanel(
              "交互图",
              app_result_panel(
                title = "交互图结果",
                note = copy$interactive_plot$note,
                tone = "info",
                uiOutput(ns("interactive_plot_ui"))
              )
            ),
            tabPanel(
              "数据",
              app_result_panel(
                title = "蜘蛛图数据",
                note = copy$data_tab$note,
                tone = "warning",
                DTOutput(ns("data_table"))
              )
            )
          )
        )
      )
    )
  )
}

spider_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  `%||%` <- function(x, y) if (is.null(x)) y else x

  palette_values <- function(n, palette_name = "hue") {
    if (n <= 0) return(character(0))
    if (palette_name == "hue") return(scales::hue_pal()(n))
    if (palette_name == "viridis") return(grDevices::hcl.colors(n, "Viridis"))
    max_n <- min(max(n, 3), 12)
    base_vals <- RColorBrewer::brewer.pal(max_n, palette_name)
    if (n <= length(base_vals)) return(base_vals[seq_len(n)])
    grDevices::colorRampPalette(base_vals)(n)
  }

  is_time_var <- function(x) {
    is.numeric(x) || inherits(x, "Date") || inherits(x, "POSIXt")
  }

  graphics_state <- reactiveValues(
    subject_id = NULL,
    time_var = NULL,
    value_var = NULL,
    line_color_by = "",
    facet_var = "",
    columns_signature = NULL
  )

  observeEvent(data(), {
    req(data())
    all_vars <- names(data())
    numeric_vars <- names(data())[sapply(data(), is.numeric)]
    current_signature <- paste(all_vars, collapse = "|")
    if (!is.null(graphics_state$columns_signature) && identical(graphics_state$columns_signature, current_signature)) return()
    graphics_state$columns_signature <- current_signature

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = graphics_state$subject_id %||% "USUBJID", server = TRUE)
    updateSelectizeInput(session, "time_var", choices = all_vars, selected = graphics_state$time_var, server = TRUE)
    updateSelectizeInput(session, "value_var", choices = numeric_vars, selected = graphics_state$value_var %||% "PCHG", server = TRUE)
    updateSelectizeInput(session, "line_color_by", choices = c("无" = "", all_vars), selected = graphics_state$line_color_by, server = TRUE)
    updateSelectizeInput(session, "facet_var", choices = c("无" = "", all_vars), selected = graphics_state$facet_var, server = TRUE)
  }, ignoreInit = FALSE)

  observe({
    graphics_state$subject_id <- input$subject_id
    graphics_state$time_var <- input$time_var
    graphics_state$value_var <- input$value_var
    graphics_state$line_color_by <- input$line_color_by
    graphics_state$facet_var <- input$facet_var
  })

  final_plot <- reactiveVal(NULL)
  prepared_data <- reactiveVal(NULL)
  main_plot_obj <- reactiveVal(NULL)
  committed_params <- reactiveVal(NULL)
  size_config <- reactive({
    graphics_collect_size_config(input)
  })
  resolve_spider_size_config <- function(params = NULL) {
    if (!is.list(params)) {
      return(size_config())
    }
    resolve_plot_size_config(
      mode = params$size_mode %||% "wide_standard",
      static_width_px = params$static_width_px,
      static_height_px = params$static_height_px,
      interactive_width_px = params$interactive_width_px,
      interactive_height_px = params$interactive_height_px,
      export_width_in = params$export_width_in,
      export_height_in = params$export_height_in,
      sync_export_size = params$sync_export_size %||% TRUE,
      size_sync_ppi = params$size_sync_ppi %||% 96,
      page_margin_top_px = params$page_margin_top_px,
      page_margin_right_px = params$page_margin_right_px,
      page_margin_bottom_px = params$page_margin_bottom_px,
      page_margin_left_px = params$page_margin_left_px,
      canvas_border = params$canvas_border %||% TRUE,
      canvas_border_color = params$canvas_border_color %||% "#D9D9D9",
      canvas_border_size = params$canvas_border_size %||% 0.8,
      canvas_background = params$canvas_background %||% "white"
    )
  }
  committed_size_config <- reactive({
    resolve_spider_size_config(committed_params())
  })
  collect_reference_line_spec_from_params <- function(
    params,
    id_prefix,
    orientation = "h",
    fallback_value = NULL,
    fallback_color = "#1A1A1A",
    fallback_linetype = "dashed",
    fallback_linewidth = 0.8
  ) {
    value <- suppressWarnings(as.numeric(params[[id_prefix]] %||% fallback_value))
    if (length(value) == 0 || is.na(value) || !is.finite(value)) return(NULL)
    list(
      orientation = if (identical(orientation, "v")) "v" else "h",
      value = value,
      color = as.character(params[[paste0(id_prefix, "_color")]] %||% fallback_color),
      linetype = as.character(params[[paste0(id_prefix, "_linetype")]] %||% fallback_linetype),
      linewidth = suppressWarnings(as.numeric(params[[paste0(id_prefix, "_linewidth")]] %||% fallback_linewidth))
    )
  }
  build_spider_committed_params <- function(df_current = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    list(
      subject_id = input$subject_id,
      time_var = input$time_var,
      value_var = input$value_var,
      line_color_by = input$line_color_by %||% "",
      facet_var = input$facet_var %||% "",
      show_legend = isTRUE(input$show_legend),
      axis_style = input$axis_style %||% "default",
      show_grid_lines = isTRUE(input$show_grid_lines),
      show_points = isTRUE(input$show_points),
      show_end_labels = isTRUE(input$show_end_labels),
      add_baseline_zero = isTRUE(input$add_baseline_zero),
      legend_title = input$legend_title %||% "",
      legend_position = input$legend_position %||% "right",
      time_unit = input$time_unit %||% "day",
      x_break_step = input$x_break_step %||% 0,
      y_breaks_n = input$y_breaks_n %||% 9,
      y_break_step = input$y_break_step %||% 0,
      base_font_size = input$base_font_size %||% 12,
      use_percent_label = isTRUE(input$use_percent_label),
      y_show_percent_sign = isTRUE(input$y_show_percent_sign %||% TRUE),
      y_decimals = input$y_decimals %||% 1,
      base_family = input$base_family %||% "sans",
      cjk_family = input$cjk_family %||% "Noto Sans SC",
      line_linetype = input$line_linetype %||% "solid",
      line_palette = input$line_palette %||% "Set1",
      line_size = input$line_size %||% 0.9,
      line_alpha = input$line_alpha %||% 0.8,
      point_size = input$point_size %||% 1.8,
      plot_title = input$plot_title %||% "",
      plot_subtitle = input$plot_subtitle %||% "",
      plot_caption = input$plot_caption %||% "",
      plot_xlab = input$plot_xlab %||% "",
      plot_ylab = input$plot_ylab %||% "",
      show_recist = isTRUE(input$show_recist),
      recist_lower = input$recist_lower %||% -30,
      recist_lower_color = input$recist_lower_color %||% "#2C7BB6",
      recist_lower_linetype = input$recist_lower_linetype %||% "dashed",
      recist_lower_linewidth = input$recist_lower_linewidth %||% 0.7,
      recist_upper = input$recist_upper %||% 20,
      recist_upper_color = input$recist_upper_color %||% "#D7191C",
      recist_upper_linetype = input$recist_upper_linetype %||% "dashed",
      recist_upper_linewidth = input$recist_upper_linewidth %||% 0.7,
      size_mode = input$size_mode %||% "wide_standard",
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
      canvas_border_color = input$canvas_border_color %||% "#D9D9D9",
      canvas_border_size = input$canvas_border_size %||% 0.8,
      canvas_background = input$canvas_background %||% "white"
    )
  }

  output$static_plot_ui <- renderUI({
    cfg <- committed_size_config()
    graphics_centered_output_container(
      plotOutput(ns("static_plot"), height = paste0(cfg$static_height, "px"), width = "100%"),
      frame_width_px = cfg$static_width,
      frame_height_px = cfg$static_height
    )
  })

  output$interactive_plot_ui <- renderUI({
    cfg <- committed_size_config()
    graphics_centered_output_container(
      plotly::plotlyOutput(ns("interactive_plot"), height = paste0(cfg$interactive_height, "px"), width = "100%"),
      frame_width_px = cfg$interactive_width,
      frame_height_px = cfg$interactive_height,
      canvas_config = cfg,
      use_canvas_border = TRUE
    )
  })

  observeEvent(input$render_plot, {
    req(data(), input$subject_id, input$time_var, input$value_var)

    tryCatch({
      df <- data()
      params <- build_spider_committed_params(df)
      line_has_group <- nzchar(params$line_color_by %||% "") && params$line_color_by %in% names(df)
      selected_cols <- unique(c(params$subject_id, params$time_var, params$value_var, params$line_color_by, params$facet_var))
      selected_cols <- selected_cols[nzchar(selected_cols)]
      selected_cols <- selected_cols[selected_cols %in% names(df)]
      plot_df <- df[, selected_cols, drop = FALSE]

      names(plot_df)[names(plot_df) == params$subject_id] <- ".subject_id"
      names(plot_df)[names(plot_df) == params$time_var] <- ".time"
      names(plot_df)[names(plot_df) == params$value_var] <- ".value"

      if (nzchar(params$line_color_by %||% "") && params$line_color_by %in% names(df)) {
        names(plot_df)[names(plot_df) == params$line_color_by] <- ".line_group"
      } else {
        plot_df$.line_group <- "全部受试者"
      }
      if (nzchar(params$facet_var %||% "") && params$facet_var %in% names(df)) {
        names(plot_df)[names(plot_df) == params$facet_var] <- ".facet_var"
      } else {
        plot_df$.facet_var <- "全部"
      }

      plot_df <- plot_df %>%
        mutate(
          .subject_id = as.character(.subject_id),
          .value = as.numeric(.value),
          .time_chr = as.character(.time),
          .line_group = as.character(.line_group),
          .facet_var = as.character(.facet_var)
        ) %>%
        filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.value), !is.na(.time_chr), nzchar(.time_chr))

      time_mode <- "numeric"
      if (inherits(df[[params$time_var]], "Date") || inherits(df[[params$time_var]], "POSIXt")) {
        time_mode <- "date"
        plot_df <- plot_df %>%
          mutate(.time_date = as.Date(.time)) %>%
          group_by(.subject_id) %>%
          mutate(.base_date = min(.time_date, na.rm = TRUE)) %>%
          ungroup() %>%
          mutate(
            .time_days = as.numeric(difftime(.time_date, .base_date, units = "days")),
            .time_label = as.character(.time_date)
          )
      } else if (is.numeric(df[[params$time_var]])) {
        time_mode <- "numeric"
        plot_df$.time_days <- as.numeric(plot_df$.time)
        plot_df$.time_label <- formatC(plot_df$.time_days, format = "f", digits = 2)
      } else {
        time_mode <- "categorical"
        time_levels <- unique(plot_df$.time_chr)
        num_guess <- suppressWarnings(as.numeric(gsub("[^0-9\\.\\-]", "", time_levels)))
        if (sum(!is.na(num_guess)) >= 2) {
          ord <- order(ifelse(is.na(num_guess), Inf, num_guess), time_levels)
          time_levels <- time_levels[ord]
          num_guess <- num_guess[ord]
          idx_vals <- ifelse(is.na(num_guess), seq_along(time_levels), num_guess)
        } else {
          idx_vals <- seq_along(time_levels)
        }
        time_map <- setNames(idx_vals, time_levels)
        plot_df$.time_days <- unname(time_map[plot_df$.time_chr])
        plot_df$.time_label <- plot_df$.time_chr
      }

      plot_df <- plot_df %>%
        filter(!is.na(.time_days)) %>%
        group_by(.subject_id, .time_days, .time_label, .line_group, .facet_var) %>%
        summarise(.value = mean(.value, na.rm = TRUE), .groups = "drop")

      unit_divisor <- switch(params$time_unit %||% "day", day = 1, week = 7, month = 30.4375, year = 365.25, 1)
      unit_label <- switch(params$time_unit %||% "day", day = "天", week = "周", month = "月", year = "年", "天")
      plot_df <- plot_df %>%
        mutate(
          .time_plot = if (time_mode == "categorical") .time_days else .time_days / unit_divisor
        )

      if (isTRUE(params$add_baseline_zero)) {
        baseline_df <- plot_df %>%
          group_by(.subject_id) %>%
          summarise(
            .line_group = dplyr::first(.line_group),
            .facet_var = dplyr::first(.facet_var),
            .groups = "drop"
          ) %>%
          mutate(
            .time_days = 0,
            .time_plot = 0,
            .time_label = if (time_mode == "categorical") "Baseline" else "0",
            .value = 0
          )
        plot_df <- bind_rows(plot_df, baseline_df) %>%
          group_by(.subject_id, .time_days, .time_plot, .time_label, .line_group, .facet_var) %>%
          summarise(.value = mean(.value, na.rm = TRUE), .groups = "drop")
      }

      plot_df$.tooltip <- paste0(
        "受试者: ", plot_df$.subject_id,
        "<br>时间: ", ifelse(time_mode == "categorical", plot_df$.time_label, paste0(formatC(plot_df$.time_plot, format = "f", digits = 2), " ", unit_label)),
        "<br>变化值: ",
        if (isTRUE(params$use_percent_label)) {
          graphics_format_percent_labels(
            show_percent_sign = isTRUE(params$y_show_percent_sign %||% TRUE),
            scale_factor = 1,
            decimals = params$y_decimals %||% 1
          )(plot_df$.value)
        } else {
          graphics_format_number_labels(decimals = params$y_decimals %||% 1)(plot_df$.value)
        }
      )

      if (!is.null(params$y_break_step) && params$y_break_step > 0) {
        y_breaks_fun <- function(x) seq(floor(min(x, na.rm=TRUE) / params$y_break_step) * params$y_break_step, ceiling(max(x, na.rm=TRUE) / params$y_break_step) * params$y_break_step, by = params$y_break_step)
      } else {
        y_breaks_fun <- scales::breaks_pretty(n = params$y_breaks_n %||% 9)
      }
      y_labels_fun <- if (isTRUE(params$use_percent_label)) {
        graphics_format_percent_labels(show_percent_sign = isTRUE(params$y_show_percent_sign %||% TRUE), scale_factor = 1, decimals = params$y_decimals %||% 1)
      } else {
        graphics_format_number_labels(decimals = params$y_decimals %||% 1)
      }
      line_levels <- unique(plot_df$.line_group)
      line_colors <- setNames(palette_values(length(line_levels), params$line_palette %||% "Set1"), line_levels)
      line_single_color <- line_colors[[1]] %||% "#4E79A7"
      font_spec <- graphics_resolve_font_spec(
        base_family = params$base_family %||% "sans",
        cjk_family = params$cjk_family %||% "Noto Sans SC"
      )
      plot_family <- font_spec$unified

      if (isTRUE(line_has_group)) {
        p <- ggplot(plot_df, aes(x = .time_plot, y = .value, group = .subject_id, text = .tooltip, color = .line_group)) +
          geom_line(linewidth = params$line_size, alpha = params$line_alpha, linetype = params$line_linetype %||% "solid") +
          scale_color_manual(values = line_colors) +
          scale_y_continuous(breaks = y_breaks_fun, labels = y_labels_fun) +
          labs(
            title = ifelse(nzchar(params$plot_title %||% ""), params$plot_title, "蜘蛛图"),
            subtitle = params$plot_subtitle %||% "",
            caption = params$plot_caption %||% "",
            x = ifelse(nzchar(params$plot_xlab %||% ""), params$plot_xlab, ifelse(time_mode == "categorical", "时间序列", "时间")),
            y = ifelse(nzchar(params$plot_ylab %||% ""), params$plot_ylab, "较基线变化(%)"),
            color = graphics_resolve_legend_title(params$legend_title, params$line_color_by)
          ) +
          theme_minimal(base_size = params$base_font_size, base_family = plot_family) +
          theme(
            panel.grid.minor = element_blank()
          )
        p <- graphics_apply_legend_theme(
          p,
          show_legend = isTRUE(params$show_legend),
          position = params$legend_position %||% "right"
        )
      } else {
        p <- ggplot(plot_df, aes(x = .time_plot, y = .value, group = .subject_id, text = .tooltip)) +
          geom_line(linewidth = params$line_size, alpha = params$line_alpha, linetype = params$line_linetype %||% "solid", color = line_single_color) +
          scale_y_continuous(breaks = y_breaks_fun, labels = y_labels_fun) +
          labs(
            title = ifelse(nzchar(params$plot_title %||% ""), params$plot_title, "蜘蛛图"),
            subtitle = params$plot_subtitle %||% "",
            caption = params$plot_caption %||% "",
            x = ifelse(nzchar(params$plot_xlab %||% ""), params$plot_xlab, ifelse(time_mode == "categorical", "时间序列", "时间")),
            y = ifelse(nzchar(params$plot_ylab %||% ""), params$plot_ylab, "较基线变化(%)")
          ) +
          theme_minimal(base_size = params$base_font_size, base_family = plot_family) +
          theme(
            legend.position = "none",
            panel.grid.minor = element_blank()
          ) +
          guides(color = "none")
      }

      if (!isTRUE(params$show_grid_lines)) {
        p <- p + theme(panel.grid = element_blank(), panel.grid.minor = element_blank())
      }

      if (time_mode == "categorical") {
        x_lab_map <- plot_df %>%
          group_by(.time_plot) %>%
          summarise(.time_label = dplyr::first(.time_label), .groups = "drop") %>%
          arrange(.time_plot)
        p <- p + scale_x_continuous(breaks = x_lab_map$.time_plot, labels = x_lab_map$.time_label)
      } else {
        p <- graphics_apply_x_break_step(p, plot_df$.time_plot, params$x_break_step)
      }

      if ((params$axis_style %||% "default") %in% c("classic_arrow", "classic")) {
        p <- p +
          theme_classic(base_size = params$base_font_size, base_family = plot_family)
        p <- graphics_apply_axis_style(p, params$axis_style, arrow_size = 0.12)
        p <- graphics_apply_legend_theme(
          p,
          show_legend = isTRUE(params$show_legend) && isTRUE(line_has_group),
          position = params$legend_position %||% "right"
        )
      }

      if (isTRUE(params$show_points)) {
        if (isTRUE(line_has_group)) {
          p <- p + geom_point(size = params$point_size, alpha = min(1, params$line_alpha + 0.1))
        } else {
          p <- p + geom_point(size = params$point_size, alpha = min(1, params$line_alpha + 0.1), color = line_single_color)
        }
      }

      if (isTRUE(params$show_recist)) {
        p <- graphics_add_reference_lines(
          p,
          list(
            collect_reference_line_spec_from_params(params, "recist_lower", orientation = "h", fallback_value = -30, fallback_color = "#2C7BB6", fallback_linewidth = 0.7),
            collect_reference_line_spec_from_params(params, "recist_upper", orientation = "h", fallback_value = 20, fallback_color = "#D7191C", fallback_linewidth = 0.7)
          )
        )
      }

      if (nzchar(params$facet_var %||% "")) {
        p <- p + facet_wrap(vars(.facet_var))
      }

      if (isTRUE(params$show_end_labels)) {
        end_df <- plot_df %>%
          group_by(.subject_id) %>%
          slice_max(order_by = .time_plot, n = 1, with_ties = FALSE) %>%
          ungroup()
        p <- p +
          geom_text(
            data = end_df,
            aes(label = .subject_id),
            color = "#333333",
            size = max(2.8, params$base_font_size * 0.2),
            nudge_x = diff(range(plot_df$.time_plot, na.rm = TRUE)) * 0.01,
            check_overlap = TRUE,
            family = plot_family
          )
      }

      committed_params(params)
      final_plot(p)
      main_plot_obj(p)
      prepared_data(plot_df)
      graphics_notify_success("蜘蛛图")
    }, error = function(e) {
      committed_params(NULL)
      final_plot(NULL)
      main_plot_obj(NULL)
      prepared_data(NULL)
      graphics_notify_error("蜘蛛图", e)
    })
  })

  output$static_plot <- renderPlot({
    shiny::validate(shiny::need(!is.null(final_plot()), "请先完成参数设置并点击“生成图形”。"))
    cfg <- committed_size_config()
    graphics_apply_canvas_frame(
      final_plot(),
      frame_width_px = cfg$static_width,
      frame_height_px = cfg$static_height,
      canvas_config = cfg
    )
  }, width = function() {
    as.integer(committed_size_config()$static_width)
  }, height = function() {
    as.integer(committed_size_config()$static_height)
  })

  output$interactive_plot <- plotly::renderPlotly({
    shiny::validate(shiny::need(!is.null(main_plot_obj()), "请先生成蜘蛛图后查看交互式图。"))
    cfg <- committed_size_config()
    plotly::layout(
      ggplotly(main_plot_obj(), tooltip = "text", width = as.integer(cfg$interactive_width), height = as.integer(cfg$interactive_height)),
      margin = list(
        l = cfg$page_margin_left,
        r = cfg$page_margin_right,
        t = cfg$page_margin_top,
        b = cfg$page_margin_bottom
      ),
      paper_bgcolor = cfg$canvas_background,
      plot_bgcolor = cfg$canvas_background
    )
  })

  output$data_table <- renderDT({
    shiny::validate(shiny::need(!is.null(prepared_data()) && nrow(prepared_data()) > 0, "当前无可展示的蜘蛛图数据。"))
    datatable(prepared_data(), options = list(pageLength = 15, scrollX = TRUE))
  })

  output$dl_plot <- downloadHandler(
    filename = function() {
      build_plot_export_filename("spider_plot", input$export_format)
    },
    content = function(file) {
      req(final_plot())
      cfg <- committed_size_config()
      save_plot_export(
        file = file,
        plot_obj = graphics_apply_canvas_frame(
          final_plot(),
          frame_width_px = cfg$static_width,
          frame_height_px = cfg$static_height,
          canvas_config = cfg
        ),
        format = input$export_format,
        width = cfg$export_width,
        height = cfg$export_height,
        dpi = input$export_dpi %||% 600
      )
    }
  )

  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    graphics_restore_task_input_state(session, state)
    extra_state <- graphics_task_payload_extra_state(state)
    updateSelectizeInput(session, "subject_id", selected = extra_state$subject_id %||% input$subject_id, server = TRUE)
    updateSelectizeInput(session, "time_var", selected = extra_state$time_var %||% input$time_var, server = TRUE)
    updateSelectizeInput(session, "value_var", selected = extra_state$value_var %||% input$value_var, server = TRUE)
    updateSelectizeInput(session, "line_color_by", selected = extra_state$line_color_by %||% input$line_color_by, server = TRUE)
    updateSelectizeInput(session, "facet_var", selected = extra_state$facet_var %||% input$facet_var, server = TRUE)
    if (!is.null(extra_state$add_baseline_zero)) updateCheckboxInput(session, "add_baseline_zero", value = isTRUE(extra_state$add_baseline_zero))
    if (!is.null(extra_state$line_linetype)) updateSelectInput(session, "line_linetype", selected = extra_state$line_linetype)
    if (!is.null(extra_state$time_unit)) updateSelectInput(session, "time_unit", selected = extra_state$time_unit)
    if (!is.null(extra_state$x_break_step)) updateNumericInput(session, "x_break_step", value = extra_state$x_break_step)
    if (!is.null(extra_state$size_mode)) updateSelectInput(session, "size_mode", selected = extra_state$size_mode)
    if (!is.null(extra_state$export_width_in)) updateNumericInput(session, "export_width_in", value = extra_state$export_width_in)
    if (!is.null(extra_state$export_height_in)) updateNumericInput(session, "export_height_in", value = extra_state$export_height_in)
    invisible(TRUE)
  }

  list(
    state = reactive({
      time_axis_cfg <- graphics_collect_time_axis_config(input, unit_id = "time_unit", break_id = "x_break_step")
      graphics_build_task_state(
        input,
        extra_state = list(
          subject_id = input$subject_id,
          time_var = input$time_var,
          value_var = input$value_var,
          line_color_by = input$line_color_by,
          facet_var = input$facet_var,
          add_baseline_zero = input$add_baseline_zero,
          line_linetype = input$line_linetype,
          time_unit = time_axis_cfg$unit,
          x_break_step = time_axis_cfg$break_step,
          size_mode = input$size_mode,
          export_width_in = size_config()$export_width,
          export_height_in = size_config()$export_height
        )
      )
    }),
    apply_state = apply_state
  )
}
