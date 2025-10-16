# 森林图子模块
# 负责生成森林图

# 加载必要的包
library(ggplot2)
library(plotly)
library(DT)

forest_plot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        width = 12,
        title = "森林图参数配置",
        status = "primary",
        solidHeader = TRUE,
        fluidRow(
          column(8,
                 selectizeInput(ns("forest_vars"), "选择变量", 
                              choices = NULL, multiple = TRUE)
          ),
          column(4,
                 numericInput(ns("forest_ref"), "参考组", value = 1, min = 1, max = 100)
          )
        ),
        helpText("森林图显示变量的均值及其95%置信区间")
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
                 numericInput(ns("point_size"), "点大小", value = 2, min = 1, max = 10, step = 0.5)
          )
        )
      )
    ),
    
    # 森林图输出
    fluidRow(
      box(
        width = 12,
        title = "森林图输出",
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

forest_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储图形参数状态
  graphics_state <- reactiveValues(
    forest_vars = NULL,
    forest_ref = 1
  )
  
  # 更新变量选择
  observe({
    req(data())
    
    # 获取所有变量列表
    all_vars <- names(data())
    
    # 更新变量选择
    updateSelectizeInput(session, "forest_vars", choices = all_vars, selected = graphics_state$forest_vars)
  })
  
  # 观察并保存图形参数
  observe({
    graphics_state$forest_vars <- input$forest_vars
    graphics_state$forest_ref <- input$forest_ref
  })
  
  # 创建森林图
  create_forest_plot <- function() {
    req(data(), input$forest_vars)
    
    # 简单的森林图实现 - 显示变量的均值置信区间
    forest_data <- data()[, input$forest_vars, drop = FALSE]
    
    # 计算每个变量的统计量
    forest_stats <- data.frame(
      Variable = names(forest_data),
      Mean = sapply(forest_data, function(x) {
        if (is.numeric(x)) {
          mean(x, na.rm = TRUE)
        } else {
          NA_real_
        }
      }),
      CI_Lower = sapply(forest_data, function(x) {
        if (is.numeric(x)) {
          n <- sum(!is.na(x))
          if (n > 1) {
            mean(x, na.rm = TRUE) - 1.96 * sd(x, na.rm = TRUE) / sqrt(n)
          } else {
            NA_real_
          }
        } else {
          NA_real_
        }
      }),
      CI_Upper = sapply(forest_data, function(x) {
        if (is.numeric(x)) {
          n <- sum(!is.na(x))
          if (n > 1) {
            mean(x, na.rm = TRUE) + 1.96 * sd(x, na.rm = TRUE) / sqrt(n)
          } else {
            NA_real_
          }
        } else {
          NA_real_
        }
      })
    )
    
    # 过滤掉无效的行
    forest_stats <- forest_stats[complete.cases(forest_stats), ]
    
    if (nrow(forest_stats) == 0) {
      stop("没有有效的数值变量用于生成森林图")
    }
    
    p <- ggplot(forest_stats, aes(x = Mean, y = reorder(Variable, Mean))) +
      geom_point(size = input$point_size) +
      geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper), height = 0.2, 
                     size = input$line_size, linetype = input$line_type) +
      geom_vline(xintercept = input$forest_ref, linetype = "dashed", color = "red") +
      theme_minimal() +
      labs(title = ifelse(nchar(input$plot_title) > 0, input$plot_title, "森林图"),
           x = ifelse(nchar(input$plot_xlab) > 0, input$plot_xlab, "均值 (95% CI)"),
           y = ifelse(nchar(input$plot_ylab) > 0, input$plot_ylab, "变量"))
    
    return(p)
  }
  
  # 生成森林图
  final_plot <- reactiveVal(NULL)
  
  observeEvent(input$render_plot, {
    req(data(), input$forest_vars)
    
    tryCatch({
      p <- create_forest_plot()
      final_plot(p)
      showNotification("森林图生成完成", type = "message")
    }, error = function(e) {
      showNotification(paste("森林图生成错误:", e$message), type = "error")
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
    req(data(), input$forest_vars)
    
    if (!is.null(input$forest_vars)) {
      # 只显示选中的变量
      display_data <- data()[, input$forest_vars, drop = FALSE]
      datatable(display_data, options = list(pageLength = 10, scrollX = TRUE))
    } else {
      datatable(data(), options = list(pageLength = 10, scrollX = TRUE))
    }
  })
  
  # 图形导出
  output$dl_plot <- downloadHandler(
    filename = function() {
      paste("forest_plot_", Sys.Date(), ".", input$export_format, sep = "")
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
      selected_vars = input$forest_vars,
      reference_value = input$forest_ref
    )
  }))
}