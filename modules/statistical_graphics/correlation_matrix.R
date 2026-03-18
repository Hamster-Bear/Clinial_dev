# 相关性矩阵子模块
# 负责生成相关性矩阵图

# 加载必要的包
library(ggplot2)
library(plotly)
library(DT)

correlation_matrix_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        width = 12,
        title = "相关性矩阵参数配置",
        status = "primary",
        solidHeader = TRUE,
        fluidRow(
          column(8,
                 selectizeInput(ns("correlation_vars"), "选择数值变量", 
                              choices = NULL, multiple = TRUE)
          ),
          column(4,
                 selectizeInput(ns("correlation_method"), "相关方法",
                              choices = c("pearson", "spearman", "kendall"),
                              selected = "pearson")
          )
        ),
        helpText("相关性矩阵显示变量间的相关系数")
      )
    ),
    
    # 高级美学设置
    fluidRow(
      box(
        width = 12,
        title = "高级美学设置",
        status = "primary",
        collapsible = TRUE,
        collapsed = TRUE,
        fluidRow(
          column(6,
                 textInput(ns("plot_title"), "主标题", value = "", width = "100%")
          ),
          column(6,
                 selectInput(ns("color_palette"), "颜色方案",
                           choices = c("蓝白红" = "blue_white_red", "彩虹" = "rainbow", 
                                      "热力图" = "heat", "冷色调" = "cool"))
          )
        ),
        fluidRow(
          column(6,
                 textInput(ns("plot_xlab"), "X轴标签", value = "", width = "100%")
          ),
          column(6,
                 textInput(ns("plot_ylab"), "Y轴标签", value = "", width = "100%")
          )
        ),
        fluidRow(
          column(4,
                 numericInput(ns("text_size"), "文本大小", value = 10, min = 6, max = 20, step = 1)
          ),
          column(4,
                 numericInput(ns("tile_size"), "格子大小", value = 1, min = 0.5, max = 3, step = 0.1)
          ),
          column(4,
                 checkboxInput(ns("show_values"), "显示数值", value = TRUE)
          )
        )
      )
    ),
    
    # 相关性矩阵输出
    fluidRow(
      box(
        width = 12,
        title = "相关性矩阵输出",
        status = "success",
        solidHeader = TRUE,
        sidebarLayout(
          sidebarPanel(
            width = 3,
            actionButton(ns("render_plot"), "生成图形", icon = icon("chart-line"),
                       class = "btn btn-primary"),
            br(), br(),
            # 导出格式选择
            selectInput(ns("export_format"), "导出格式",
                       choices = c("PDF" = "pdf", "PNG" = "png", "SVG" = "svg"),
                       selected = "pdf"),
            br(),
            downloadButton(ns("dl_plot"), "导出图形")
          ),
          mainPanel(
            width = 9,
            tabsetPanel(
              id = ns("output_tabs"),
              tabPanel("静态图", plotOutput(ns("static_plot"), height = "600px")),
              tabPanel("交互式图", plotly::plotlyOutput(ns("interactive_plot"), height = "600px")),
              tabPanel("数据表", DTOutput(ns("data_table")))
            )
          )
        )
      )
    )
  )
}

correlation_matrix_server <- function(input, output, session, data) {
  ns <- session$ns
  
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
  create_correlation_plot <- function() {
    req(data(), input$correlation_vars, input$correlation_method)
    
    cor_data <- data()[, input$correlation_vars, drop = FALSE]
    cor_matrix <- cor(cor_data, method = input$correlation_method, use = "complete.obs")
    
    # 转换为长格式
    cor_long <- as.data.frame(as.table(cor_matrix))
    names(cor_long) <- c("Var1", "Var2", "Correlation")
    
    # 设置颜色梯度
    if (input$color_palette == "blue_white_red") {
      color_gradient <- scale_fill_gradient2(low = "blue", high = "red", mid = "white",
                                           midpoint = 0, limit = c(-1,1))
    } else if (input$color_palette == "rainbow") {
      color_gradient <- scale_fill_gradientn(colors = rainbow(7), limits = c(-1,1))
    } else if (input$color_palette == "heat") {
      color_gradient <- scale_fill_gradient(low = "white", high = "red", limits = c(-1,1))
    } else { # cool
      color_gradient <- scale_fill_gradient(low = "white", high = "blue", limits = c(-1,1))
    }
    
    p <- ggplot(cor_long, aes(Var1, Var2, fill = Correlation, 
                             text = paste("相关系数:", round(Correlation, 3)))) +
      geom_tile(size = input$tile_size) +
      color_gradient +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = input$text_size),
            axis.text.y = element_text(size = input$text_size)) +
      labs(title = ifelse(nchar(input$plot_title) > 0, input$plot_title, "相关性矩阵"),
           x = ifelse(nchar(input$plot_xlab) > 0, input$plot_xlab, "变量"),
           y = ifelse(nchar(input$plot_ylab) > 0, input$plot_ylab, "变量"))
    
    # 添加数值标签
    if (input$show_values) {
      p <- p + geom_text(aes(label = round(Correlation, 2)), color = "black", size = input$text_size/3)
    }
    
    return(p)
  }
  
  # 生成相关性矩阵图
  final_plot <- reactiveVal(NULL)
  
  observeEvent(input$render_plot, {
    req(data(), input$correlation_vars, input$correlation_method)
    
    tryCatch({
      p <- create_correlation_plot()
      final_plot(p)
      showNotification("相关性矩阵生成完成", type = "message")
    }, error = function(e) {
      showNotification(paste("相关性矩阵生成错误:", e$message), type = "error")
      final_plot(NULL)
    })
  })
  
  # 显示静态图
  output$static_plot <- renderPlot({
    req(final_plot())
    final_plot()
  }, height = 600)
  
  # 显示交互式图
  output$interactive_plot <- plotly::renderPlotly({
    req(final_plot())
    ggplotly(final_plot(), height = 600)
  })
  
  # 显示数据表
  output$data_table <- renderDT({
    req(data(), input$correlation_vars, input$correlation_method)
    
    if (!is.null(input$correlation_vars)) {
      # 计算相关性矩阵
      cor_data <- data()[, input$correlation_vars, drop = FALSE]
      cor_matrix <- cor(cor_data, method = input$correlation_method, use = "complete.obs")
      
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
      build_plot_export_filename("correlation_matrix", input$export_format)
    },
    content = function(file) {
      save_plot_export(
        file = file,
        plot_obj = final_plot(),
        format = input$export_format,
        width = 10,
        height = 8,
        dpi = 300
      )
    }
  )
  
  # 返回模块状态
  return(reactive({
    list(
      selected_vars = input$correlation_vars,
      method = input$correlation_method
    )
  }))
}
