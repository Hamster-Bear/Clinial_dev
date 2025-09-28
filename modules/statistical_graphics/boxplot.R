# 箱线图子模块
# 负责生成箱线图

# 加载必要的包
library(ggplot2)
library(plotly)
library(DT)

boxplot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        width = 12,
        title = "箱线图参数配置",
        status = "primary",
        solidHeader = TRUE,
        fluidRow(
          column(6,
                 selectizeInput(ns("boxplot_x"), "X轴变量 (分组)", choices = NULL)
          ),
          column(6,
                 selectizeInput(ns("boxplot_y"), "Y轴变量 (数值)", choices = NULL)
          )
        )
      )
    ),
    
    # 高级美学设置
    fluidRow(
      box(
        width = 12,
        title = "高级美学设置",
        status = "warning",
        collapsible = TRUE,
        collapsed = TRUE,
        fluidRow(
          column(6,
                 textInput(ns("plot_title"), "主标题", value = "", width = "100%")
          ),
          column(6,
                 selectInput(ns("plot_palette"), "颜色主题",
                           choices = c("Lancet"="lancet", "JAMA"="jama", "NEJM"="nejm", "Viridis"="viridis"))
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
                 numericInput(ns("line_size"), "线条大小", value = 0.6, min = 0.1, max = 5, step = 0.1)
          ),
          column(4,
                 selectInput(ns("line_type"), "线条类型",
                           choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted",
                                      "点虚线" = "dotdash", "长虚线" = "longdash"))
          ),
          column(4,
                 numericInput(ns("point_size"), "点大小", value = 1, min = 0.5, max = 5, step = 0.1)
          )
        )
      )
    ),
    
    # 箱线图输出
    fluidRow(
      box(
        width = 12,
        title = "箱线图输出",
        status = "info",
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

boxplot_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储图形参数状态
  graphics_state <- reactiveValues(
    boxplot_x = NULL,
    boxplot_y = NULL
  )
  
  # 更新变量选择
  observe({
    req(data())
    
    # 获取分类变量和数值变量列表
    categorical_vars <- names(data())[sapply(data(), function(x) is.factor(x) || is.character(x))]
    numeric_vars <- names(data())[sapply(data(), is.numeric)]
    
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
  
  # 创建箱线图
  create_boxplot <- function() {
    req(data(), input$boxplot_x, input$boxplot_y)
    
    p <- ggplot(data(), aes(x = .data[[input$boxplot_x]], y = .data[[input$boxplot_y]])) +
      geom_boxplot(fill = "lightblue", alpha = 0.7) +
      theme_minimal() +
      labs(title = ifelse(nchar(input$plot_title) > 0, input$plot_title, "箱线图"),
           x = ifelse(nchar(input$plot_xlab) > 0, input$plot_xlab, input$boxplot_x),
           y = ifelse(nchar(input$plot_ylab) > 0, input$plot_ylab, input$boxplot_y))
    
    # 应用颜色主题
    if (!is.null(input$plot_palette)) {
      p <- p + scale_fill_brewer(palette = input$plot_palette)
    }
    
    return(p)
  }
  
  # 生成箱线图
  final_plot <- reactiveVal(NULL)
  
  observeEvent(input$render_plot, {
    req(data(), input$boxplot_x, input$boxplot_y)
    
    tryCatch({
      p <- create_boxplot()
      final_plot(p)
      showNotification("箱线图生成完成", type = "message")
    }, error = function(e) {
      showNotification(paste("箱线图生成错误:", e$message), type = "error")
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
    req(data())
    datatable(data(), options = list(pageLength = 10, scrollX = TRUE))
  })
  
  # 图形导出
  output$dl_plot <- downloadHandler(
    filename = function() {
      paste("boxplot_", Sys.Date(), ".", input$export_format, sep = "")
    },
    content = function(file) {
      req(final_plot())
      plot_format <- input$export_format
      if (plot_format == "pdf") {
        ggsave(file, plot = final_plot(), width = 10, height = 8, device = "pdf")
      } else if (plot_format == "svg") {
        ggsave(file, plot = final_plot(), width = 10, height = 8, device = "svg")
      } else { # png
        ggsave(file, plot = final_plot(), width = 10, height = 8, dpi = 300)
      }
    }
  )
  
  # 返回模块状态
  return(reactive({
    list(
      x_var = input$boxplot_x,
      y_var = input$boxplot_y
    )
  }))
}