# 箱线图子模块
# 负责生成箱线图

# 加载必要的包
library(ggplot2)
library(plotly)
library(DT)

if (!exists("app_card_box", mode = "function") ||
    !exists("app_card_note", mode = "function") ||
    !exists("app_result_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}

boxplot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "设置箱线图的 X/Y 映射",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("选择用于绘制箱线图的分组变量和数值变量。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "核心映射",
                  br(),
                  fluidRow(
                    column(6, selectizeInput(ns("boxplot_x"), "X轴变量 (分组)", choices = NULL, width = "100%")),
                    column(6, selectizeInput(ns("boxplot_y"), "Y轴变量 (数值)", choices = NULL, width = "100%"))
                  )
                ),
                tabPanel(
                  "分组/分面/轨道/附加变量",
                  br(),
                  graphics_card_panel_ui(
                    "分组/分面/轨道/附加变量",
                    tagList(
                      helpText("当前箱线图模块仅使用 X/Y 核心映射，不包含额外分面、轨道或附加变量控件。")
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
          title = "图形与样式",
          subtitle = "设置标题、样式和配色",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置标题文本、线条点样式和配色主题。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "标题与说明",
                  br(),
                  fluidRow(
                    column(6, textInput(ns("plot_title"), "主标题", value = "", width = "100%")),
                    column(6, textInput(ns("plot_xlab"), "X轴标签", value = "", width = "100%"))
                  ),
                  fluidRow(
                    column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "", width = "100%"))
                  )
                ),
                tabPanel(
                  "显示与坐标",
                  br(),
                  graphics_card_panel_ui(
                    "显示与坐标",
                    tagList(
                      helpText("当前箱线图模块没有额外的显示开关或坐标轴高级设置。")
                    )
                  )
                ),
                tabPanel(
                  "图层样式",
                  br(),
                  fluidRow(
                    column(4, numericInput(ns("line_size"), "线条大小", value = 0.6, min = 0.1, max = 5, step = 0.1, width = "100%")),
                    column(4, selectInput(ns("line_type"), "线条类型",
                      choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted",
                        "点虚线" = "dotdash", "长虚线" = "longdash"),
                      width = "100%"
                    )),
                    column(4, numericInput(ns("point_size"), "点大小", value = 1, min = 0.5, max = 5, step = 0.1, width = "100%"))
                  ),
                  fluidRow(
                    column(6, selectInput(ns("plot_palette"), "颜色主题",
                      choices = c("Lancet" = "lancet", "JAMA" = "jama", "NEJM" = "nejm", "Viridis" = "viridis"),
                      width = "100%"
                    ))
                  )
                ),
                tabPanel(
                  "参考线与阈值",
                  br(),
                  graphics_card_panel_ui(
                    "参考线与阈值",
                    tagList(
                      helpText("当前箱线图模块没有独立的参考线或阈值控件。")
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
          subtitle = "设置画布尺寸与导出参数",
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          app_card_note("箱线图导出默认使用固定 10 x 8 英寸画布，可选择导出格式和 DPI。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "尺寸与画布",
                  br(),
                  graphics_card_panel_ui(
                    "尺寸与画布",
                    tagList(
                      helpText("当前箱线图导出默认使用固定画布 10 x 8 英寸。")
                    )
                  )
                ),
                tabPanel(
                  "导出参数",
                  br(),
                  graphics_export_panel_ui(
                    ns,
                    download_id = "dl_plot",
                    include_render_button = FALSE,
                    include_download_button = FALSE,
                    include_size_mode = FALSE
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
          subtitle = "查看结果并导出输出",
          tone = "success",
          status = "success",
          solidHeader = FALSE,
          app_card_note("结果区提供生成图形、下载、交互图和数据表。"),
          graphics_output_action_bar_ui(ns, render_button_id = "render_plot", download_id = "dl_plot"),
          tabsetPanel(
            id = ns("output_tabs"),
            tabPanel(
              "静态图",
              app_result_panel(
                title = "静态图结果",
                note = "展示当前箱线图配置生成的静态图结果。",
                tone = "success",
                plotOutput(ns("static_plot"), height = "600px")
              )
            ),
            tabPanel(
              "交互图",
              app_result_panel(
                title = "交互图结果",
                note = "展示当前参数生成的交互式箱线图结果。",
                tone = "info",
                plotly::plotlyOutput(ns("interactive_plot"), height = "600px")
              )
            ),
            tabPanel(
              "数据",
              app_result_panel(
                title = "箱线图结果数据",
                note = "查看当前箱线图对应的结果数据表。",
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

boxplot_server <- function(input, output, session, data) {
  ns <- session$ns

  # 存储图形参数状态
  graphics_state <- reactiveValues(
    boxplot_x = NULL,
    boxplot_y = NULL
  )

  # committed state — Generate 时快照，分析只读此对象
  committed_params <- reactiveVal(NULL)

  # 更新变量选择
  observe({
    req(data())

    # 获取分类变量和数值变量列表
    categorical_vars <- get_categorical_vars(data(), include_logical = FALSE)
    numeric_vars <- get_numeric_vars(data())

    # 更新X轴变量选择（分类变量）
    updateSelectizeInput(session, "boxplot_x", choices = categorical_vars, selected = graphics_state$boxplot_x)

    # 更新Y轴变量选择（数值变量）
    updateSelectizeInput(session, "boxplot_y", choices = numeric_vars, selected = graphics_state$boxplot_y)
  })

  # 观察并保存图形参数
  observe({
    graphics_state$boxplot_x <- input$boxplot_x
    graphics_state$boxplot_y <- input$boxplot_y
  })

  # 创建箱线图（从 committed params 读取参数，不直接从 input$ 读取）
  create_boxplot <- function(params) {
    req(data(), params$boxplot_x, params$boxplot_y)
    plot_family <- graphics_resolve_font_spec("sans")$unified

    p <- ggplot(data(), aes(x = .data[[params$boxplot_x]], y = .data[[params$boxplot_y]])) +
      geom_boxplot(fill = "lightblue", alpha = 0.7) +
      theme_minimal(base_family = plot_family) +
      labs(title = ifelse(nchar(params$plot_title %||% "") > 0, params$plot_title, "箱线图"),
           x = ifelse(nchar(params$plot_xlab %||% "") > 0, params$plot_xlab, params$boxplot_x),
           y = ifelse(nchar(params$plot_ylab %||% "") > 0, params$plot_ylab, params$boxplot_y))

    # 应用颜色主题
    if (!is.null(params$plot_palette) && nzchar(params$plot_palette)) {
      p <- p + scale_fill_brewer(palette = params$plot_palette)
    }

    return(p)
  }

  # 生成箱线图
  final_plot <- reactiveVal(NULL)

  observeEvent(input$render_plot, {
    req(data(), input$boxplot_x, input$boxplot_y)

    params <- list(
      boxplot_x   = input$boxplot_x,
      boxplot_y   = input$boxplot_y,
      plot_title  = input$plot_title,
      plot_xlab   = input$plot_xlab,
      plot_ylab   = input$plot_ylab,
      plot_palette = input$plot_palette,
      line_size   = input$line_size,
      line_type   = input$line_type,
      point_size  = input$point_size,
      export_format = input$export_format,
      export_dpi   = if (is.null(input$export_dpi)) 300 else input$export_dpi
    )

    tryCatch({
      p <- create_boxplot(params)
      final_plot(p)
      committed_params(params)
      graphics_notify_success("箱线图")
    }, error = function(e) {
      graphics_notify_error("箱线图", e)
      final_plot(NULL)
    })
  })

  # 显示静态图
  output$static_plot <- renderPlot({
    shiny::validate(shiny::need(!is.null(final_plot()), “请先选择变量并点击\”生成图形\”。”))
    final_plot()
  }, height = 600)

  # 显示交互式图
  output$interactive_plot <- plotly::renderPlotly({
    shiny::validate(shiny::need(!is.null(final_plot()), "请先生成箱线图，再查看交互式图。"))
    ggplotly(final_plot(), height = 600)
  })

  # 显示数据表
  output$data_table <- renderDT({
    shiny::validate(shiny::need(!is.null(data()) && nrow(data()) > 0, "当前无可展示的数据。"))
    datatable(data(), options = list(pageLength = 10, scrollX = TRUE))
  })

  # 图形导出（从 committed_params 读取导出参数）
  output$dl_plot <- downloadHandler(
    filename = function() {
      cp <- committed_params()
      fmt <- if (!is.null(cp$export_format)) cp$export_format else input$export_format
      build_plot_export_filename("boxplot", fmt)
    },
    content = function(file) {
      cp <- committed_params()
      save_plot_export(
        file = file,
        plot_obj = final_plot(),
        format = if (!is.null(cp$export_format)) cp$export_format else (input$export_format %||% "png"),
        width = 10,
        height = 8,
        dpi = if (!is.null(cp$export_dpi)) cp$export_dpi else (if (is.null(input$export_dpi)) 300 else input$export_dpi)
      )
    }
  )

  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    graphics_restore_task_input_state(session, state)
    extra_state <- graphics_task_payload_extra_state(state)
    if (!is.null(extra_state$x_var)) {
      graphics_state$boxplot_x <- extra_state$x_var
      updateSelectizeInput(session, "boxplot_x", selected = extra_state$x_var)
    }
    if (!is.null(extra_state$y_var)) {
      graphics_state$boxplot_y <- extra_state$y_var
      updateSelectizeInput(session, "boxplot_y", selected = extra_state$y_var)
    }
    invisible(TRUE)
  }

  list(
    state = reactive({
      graphics_build_task_state(
        input,
        extra_state = list(
          x_var = input$boxplot_x,
          y_var = input$boxplot_y
        )
      )
    }),
    apply_state = apply_state
  )
}
