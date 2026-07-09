# 相关性矩阵子模块
# 负责生成相关性矩阵图

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

if (file.exists("modules/common/graphics/graphics_result_copy.R")) {
  source("modules/common/graphics/graphics_result_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics", "graphics_result_copy.R"))
}

correlation_matrix_ui <- function(id) {
  ns <- NS(id)
  copy <- GRAPHICS_RESULT_COPY$correlation
  
  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "选择数值变量和相关方法",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("选择参与相关性矩阵计算的数值变量，并设置相关系数方法。"),
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
                    list(
                      list(id = "correlation_vars", label = "选择数值变量", type = "selectize", multiple = TRUE, column = 8),
                      list(id = "correlation_method", label = "相关方法", type = "selectize", choices = c("pearson", "spearman", "kendall"), selected = "pearson", column = 4)
                    )
                  ),
                  help_text = "相关性矩阵显示变量间的相关系数"
                )
              ),
              tabPanel(
                "分组/分面/轨道/附加变量",
                br(),
                graphics_card_panel_ui(
                  "分组/分面/轨道/附加变量",
                  tagList(
                    helpText("当前相关性矩阵模块没有独立的分组、分面或轨道变量控件。")
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
          subtitle = "设置标题、配色和标签",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置标题文本、矩阵配色、标签字号和数值显示方式。"),
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
                    helpText("当前相关性矩阵模块没有额外的显示开关或坐标轴高级设置。")
                  )
                )
              ),
              tabPanel(
                "图层样式",
                br(),
                fluidRow(
                  column(6, selectInput(ns("color_palette"), "颜色方案",
                    choices = c("蓝白红" = "blue_white_red", "彩虹" = "rainbow", "热力图" = "heat", "冷色调" = "cool"),
                    width = "100%"
                  ))
                ),
                fluidRow(
                  column(4, numericInput(ns("text_size"), "文本大小", value = 10, min = 6, max = 20, step = 1, width = "100%")),
                  column(4, numericInput(ns("tile_size"), "格子大小", value = 1, min = 0.5, max = 3, step = 0.1, width = "100%")),
                  column(4, checkboxInput(ns("show_values"), "显示数值", value = TRUE, width = "100%"))
                )
              ),
              tabPanel(
                "参考线与阈值",
                br(),
                graphics_card_panel_ui(
                  "参考线与阈值",
                  tagList(
                    helpText("当前相关性矩阵模块没有独立的参考线或阈值控件。")
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
          app_card_note("相关性矩阵导出默认使用固定 10 x 8 英寸画布，可选择导出格式和 DPI。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
              tabPanel(
                "尺寸与导出", br(),
                graphics_export_size_controls_ui(ns, download_id = "dl_plot",
                  include_size_mode = TRUE, include_download_button = FALSE)
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
                plotOutput(ns("static_plot"), height = "600px")
              )
            ),
            tabPanel(
              "交互图",
              app_result_panel(
                title = "交互图结果",
                note = copy$interactive_plot$note,
                tone = "info",
                plotly::plotlyOutput(ns("interactive_plot"), height = "600px")
              )
            ),
            tabPanel(
              "数据",
              app_result_panel(
                title = "相关性矩阵结果数据",
                note = copy$data_tab$note,
                tone = "warning",
                DTOutput(ns("data_table"))
              )
            ),
            graphics_result_repro_tab_ui(ns)
          )
        )
      )
    )
  )
}

correlation_matrix_server <- function(input, output, session, data) {
  ns <- session$ns

  size_config <- reactive({
    graphics_collect_size_config(input)
  })

  collect_correlation_params <- function() {
    list(
      correlation_vars = input$correlation_vars,
      correlation_method = input$correlation_method,
      plot_title = input$plot_title,
      plot_xlab = input$plot_xlab,
      plot_ylab = input$plot_ylab,
      color_palette = input$color_palette,
      text_size = input$text_size,
      tile_size = input$tile_size,
      show_values = input$show_values,
      export_format = input$export_format,
      export_dpi = if (is.null(input$export_dpi)) 300 else input$export_dpi
    )
  }

  # 存储图形参数状态
  graphics_state <- reactiveValues(
    correlation_vars = NULL,
    correlation_method = "pearson"
  )
  
  # 更新变量选择
  observe({
    req(data())
    
    # 获取数值变量列表
    numeric_vars <- names(data())[sapply(data(), is.numeric)]
    
    # 更新变量选择
    updateSelectizeInput(session, "correlation_vars", choices = numeric_vars, selected = graphics_state$correlation_vars)
  })
  
  # 观察并保存图形参数
  observe({
    graphics_state$correlation_vars <- input$correlation_vars
    graphics_state$correlation_method <- input$correlation_method
  })
  
  # 创建相关性矩阵图
  create_correlation_plot <- function(params) {
    req(data(), params$correlation_vars, params$correlation_method)
    plot_family <- graphics_resolve_font_spec("sans")$unified
    
    cor_data <- data()[, params$correlation_vars, drop = FALSE]
    cor_matrix <- cor(cor_data, method = params$correlation_method, use = "complete.obs")
    
    # 转换为长格式
    cor_long <- as.data.frame(as.table(cor_matrix))
    names(cor_long) <- c("Var1", "Var2", "Correlation")
    
    # 设置颜色梯度
    if (params$color_palette == "blue_white_red") {
      color_gradient <- scale_fill_gradient2(low = "blue", high = "red", mid = "white",
                                           midpoint = 0, limit = c(-1,1))
    } else if (params$color_palette == "rainbow") {
      color_gradient <- scale_fill_gradientn(colors = rainbow(7), limits = c(-1,1))
    } else if (params$color_palette == "heat") {
      color_gradient <- scale_fill_gradient(low = "white", high = "red", limits = c(-1,1))
    } else { # cool
      color_gradient <- scale_fill_gradient(low = "white", high = "blue", limits = c(-1,1))
    }
    
    p <- ggplot(cor_long, aes(Var1, Var2, fill = Correlation, 
                             text = paste("相关系数:", round(Correlation, 3)))) +
      geom_tile(linewidth = params$tile_size) +
      color_gradient +
      theme_minimal(base_family = plot_family) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = params$text_size),
            axis.text.y = element_text(size = params$text_size)) +
      labs(title = ifelse(nchar(params$plot_title %||% "") > 0, params$plot_title, "相关性矩阵"),
           x = ifelse(nchar(params$plot_xlab %||% "") > 0, params$plot_xlab, "变量"),
           y = ifelse(nchar(params$plot_ylab %||% "") > 0, params$plot_ylab, "变量"))
    
    # 添加数值标签
    if (isTRUE(params$show_values)) {
      p <- p + geom_text(aes(label = round(Correlation, 2)), color = "black", size = params$text_size/3, family = plot_family)
    }
    
    return(p)
  }
  
  # 生成相关性矩阵图
  final_plot <- reactiveVal(NULL)
  committed_params <- reactiveVal(NULL)
  
  observeEvent(input$render_plot, {
    req(data(), input$correlation_vars, input$correlation_method)
    params <- collect_correlation_params()
    
    tryCatch({
      p <- create_correlation_plot(params)
      final_plot(p)
      committed_params(params)
      graphics_notify_success("相关性矩阵")
    }, error = function(e) {
      graphics_notify_error("相关性矩阵", e)
      final_plot(NULL)
    })
  })
  
  # 显示静态图
  output$static_plot <- renderPlot({
    shiny::validate(shiny::need(!is.null(final_plot()), "请先选择变量并点击\"生成图形\"。"))
    final_plot()
  }, height = 600)
  
  # 显示交互式图
  output$interactive_plot <- plotly::renderPlotly({
    shiny::validate(shiny::need(!is.null(final_plot()), "请先生成相关性矩阵，再查看交互式图。"))
    ggplotly(final_plot(), height = 600)
  })
  
  # 显示数据表
  output$data_table <- renderDT({
    shiny::validate(shiny::need(!is.null(data()) && nrow(data()) > 0, "当前无可展示的数据。"))
    params <- committed_params()
    shiny::validate(shiny::need(!is.null(params) && !is.null(params$correlation_vars) && length(params$correlation_vars) > 0, "请先选择数值变量并点击\"生成图形\"。"))
    shiny::validate(shiny::need(!is.null(params$correlation_method) && nzchar(params$correlation_method), "请先选择相关方法。"))
    
    if (!is.null(params$correlation_vars)) {
      # 计算相关性矩阵
      cor_data <- data()[, params$correlation_vars, drop = FALSE]
      cor_matrix <- cor(cor_data, method = params$correlation_method, use = "complete.obs")
      
      # 转换为数据框用于显示
      cor_df <- as.data.frame(cor_matrix)
      cor_df$Variable <- rownames(cor_df)
      cor_df <- cor_df[, c("Variable", names(cor_matrix))]
      
      datatable(cor_df, options = list(pageLength = 10, scrollX = TRUE)) %>%
        formatRound(columns = names(cor_matrix), digits = 3)
    } else {
      datatable(data(), options = list(pageLength = 10, scrollX = TRUE))
    }
  })
  
  # 图形导出
  output$dl_plot <- downloadHandler(
    filename = function() {
      params <- committed_params() %||% collect_correlation_params()
      build_plot_export_filename("correlation_matrix", params$export_format)
    },
    content = function(file) {
      tryCatch({
        params <- committed_params() %||% collect_correlation_params()
        cfg <- size_config()
        save_plot_export(
          file = file,
          plot_obj = graphics_apply_canvas_frame(final_plot(),
            frame_width_px = cfg$static_width, frame_height_px = cfg$static_height,
            canvas_config = cfg),
          format = params$export_format,
          width = cfg$export_width, height = cfg$export_height,
          dpi = params$export_dpi %||% 300
        )
      }, error = function(e) {
        params <- committed_params() %||% collect_correlation_params()
        msg <- sprintf("[GraphicsExportError][correlation_matrix] fmt=%s: %s",
                       params$export_format %||% "png", conditionMessage(e))
        message(msg)
        showNotification(paste("correlation_matrix导出失败：", conditionMessage(e)), type = "error")
        stop(msg)
      })
    }
  )
  
  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    graphics_restore_task_input_state(session, state)
    extra_state <- graphics_task_payload_extra_state(state)
    if (!is.null(extra_state$selected_vars)) {
      updateSelectizeInput(session, "correlation_vars", selected = extra_state$selected_vars)
    }
    if (!is.null(extra_state$method)) {
      updateSelectInput(session, "correlation_method", selected = extra_state$method)
    }
    if (!is.null(extra_state$plot_title)) {
      updateTextInput(session, "plot_title", value = extra_state$plot_title)
    }
    if (!is.null(extra_state$color_palette)) {
      updateSelectInput(session, "color_palette", selected = extra_state$color_palette)
    }
    invisible(TRUE)
  }

  state_reactive <- reactive({
    params <- committed_params() %||% collect_correlation_params()
    graphics_build_committed_task_state(
      input,
      committed_input_state = params,
      extra_state = list(
        selected_vars = params$correlation_vars,
        method = params$correlation_method,
        plot_title = params$plot_title,
        plot_xlab = params$plot_xlab,
        plot_ylab = params$plot_ylab,
        color_palette = params$color_palette,
        text_size = params$text_size,
        tile_size = params$tile_size,
        show_values = params$show_values,
        export_format = params$export_format,
        export_dpi = params$export_dpi %||% 300
      )
    )
  })

  graphics_bind_repro_code_output(
    output = output,
    output_id = "repro_code_out",
    fig_type = "correlation",
    state_getter = function() state_reactive()
  )

  list(
    state = state_reactive,
    apply_state = apply_state
  )
}
