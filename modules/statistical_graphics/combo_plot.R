# 组合图形子模块
# 负责生成多种图形类型的组合图形

# 加载必要的包
library(shiny)
library(ggplot2)
library(plotly)
library(DT)
library(shinyWidgets)
library(waiter)
library(shinyjs)
library(gridExtra)
library(cowplot)
library(RColorBrewer)
library(shinyalert)
library(scales)

combo_plot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # 顶部配置区域 - 左右分栏
    fluidRow(
      box(
        width = 12,
        title = "组合图形参数配置",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = FALSE,
        fluidRow(
          # 左侧：核心变量与类型选择
          column(4,
            wellPanel(
              style = "height: 600px; overflow-y: auto;",
              h4("核心设置", style = "color: #007bff; margin-top: 0;"),
              
              # 1. 变量选择
              tags$div(class = "panel panel-default",
                tags$div(class = "panel-heading", "变量映射"),
                tags$div(class = "panel-body",
                  selectizeInput(ns("main_x_var"), "主X轴变量:", choices = NULL, width = "100%"),
                  selectizeInput(ns("main_y_var"), "主Y轴变量:", choices = NULL, width = "100%"),
                  fluidRow(
                    column(6, selectizeInput(ns("group_var"), "分组变量:", choices = c("无分组" = "none"), width = "100%")),
                    column(6, selectizeInput(ns("facet_var"), "分面变量:", choices = c("无分面" = "none"), width = "100%"))
                  )
                )
              ),
              
              # 2. 图形类型选择
              tags$div(class = "panel panel-default",
                tags$div(class = "panel-heading", "图形类型"),
                tags$div(class = "panel-body",
                  checkboxGroupInput(ns("plot_types"), "选择图形类型 (多选):",
                                   choices = c(
                                     "散点图" = "scatter",
                                     "折线图" = "line",
                                     "柱状图" = "bar",
                                     "箱线图" = "boxplot",
                                     "密度图" = "density",
                                     "直方图" = "histogram",
                                     "面积图" = "area",
                                     "小提琴图" = "violin"
                                   ),
                                   selected = c("scatter", "line"),
                                   inline = TRUE)
                )
              ),
              
              # 3. 组合方式
              tags$div(class = "panel panel-default",
                tags$div(class = "panel-heading", "组合布局"),
                tags$div(class = "panel-body",
                  radioButtons(ns("combo_method"), NULL,
                             choices = c(
                               "叠加显示 (共享坐标轴)" = "overlay",
                               "并排显示 (独立子图)" = "side_by_side",
                               "上下显示 (独立子图)" = "top_bottom"
                             ),
                             selected = "overlay")
                )
              )
            )
          ),
          
          # 右侧：详细参数设置 (动态 Tab)
          column(8,
            wellPanel(
              style = "height: 600px; overflow-y: auto;",
              h4("详细参数设置", style = "color: #007bff; margin-top: 0;"),
              
              # 使用 uiOutput 动态生成 Tabs，仅显示选中的图形类型
              uiOutput(ns("dynamic_plot_settings"))
            )
          )
        )
      )
    ),
    
    # 底部展示区域 - 全宽
    fluidRow(
      box(
        width = 12,
        title = "组合图形输出",
        status = "success",
        solidHeader = TRUE,
        
        # 顶部工具栏
        fluidRow(
          column(12,
            div(style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 10px;",
               div(style = "margin-right: 10px; width: 150px;",
                   selectInput(ns("export_format"), NULL, choices = c("导出PNG" = "png", "导出PDF" = "pdf", "导出SVG" = "svg"), selected = "png", width = "100%")
               ),
               downloadButton(ns("download_plot"), "下载图形", class = "btn-primary")
            )
          )
        ),
        
        # 图形显示区域
        uiOutput(ns("plot_output_area"))
      )
    )
  )
}

combo_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储图形参数状态
  graphics_state <- reactiveValues(
    plot_types = c("scatter", "line")
  )
  
  # 更新变量选择
  observe({
    req(data())
    vars <- names(data())
    
    # 获取数值型和分类型变量
    num_vars <- names(data())[sapply(data(), is.numeric)]
    cat_vars <- names(data())[sapply(data(), function(x) is.factor(x) || is.character(x))]
    
    # 更新选择器
    updateSelectizeInput(session, "main_x_var", choices = c("无" = "none", vars), selected = if(length(vars)>0) vars[1] else "none")
    updateSelectizeInput(session, "main_y_var", choices = c("无" = "none", vars), selected = if(length(num_vars)>0) num_vars[1] else "none")
    updateSelectizeInput(session, "group_var", choices = c("无分组" = "none", cat_vars), selected = "none")
    updateSelectizeInput(session, "facet_var", choices = c("无分面" = "none", cat_vars), selected = "none")
  })
  
  # 动态生成详细参数设置 Tabs
  output$dynamic_plot_settings <- renderUI({
    req(input$plot_types)
    
    # 定义每种图形类型的设置UI
    tabs <- lapply(input$plot_types, function(type) {
      type_name <- switch(type,
                         "scatter" = "散点图", "line" = "折线图", "bar" = "柱状图",
                         "boxplot" = "箱线图", "density" = "密度图", "histogram" = "直方图",
                         "area" = "面积图", "violin" = "小提琴图")
      
      content <- switch(type,
        "scatter" = tagList(
          fluidRow(
            column(4, numericInput(ns("scatter_size"), "点大小:", value = 2, min = 0.5, max = 10, step = 0.5)),
            column(4, sliderInput(ns("scatter_alpha"), "透明度:", min = 0, max = 1, value = 0.6, step = 0.1)),
            column(4, checkboxInput(ns("scatter_jitter"), "抖动显示", value = FALSE))
          )
        ),
        "line" = tagList(
          fluidRow(
            column(4, numericInput(ns("line_width"), "线宽:", value = 1, min = 0.5, max = 5, step = 0.5)),
            column(4, selectInput(ns("line_type"), "线型:", choices = c("实线"="solid", "虚线"="dashed", "点线"="dotted"))),
            column(4, checkboxInput(ns("line_smooth"), "添加平滑曲线", value = FALSE))
          )
        ),
        "bar" = tagList(
          fluidRow(
            column(4, selectInput(ns("bar_position"), "堆叠模式:", choices = c("堆叠"="stack", "并排"="dodge", "填充"="fill"))),
            column(4, sliderInput(ns("bar_width"), "柱宽:", min = 0.1, max = 1, value = 0.7, step = 0.1)),
            column(4, sliderInput(ns("bar_alpha"), "透明度:", min = 0, max = 1, value = 0.8, step = 0.1))
          )
        ),
        "boxplot" = tagList(
          fluidRow(
            column(4, sliderInput(ns("boxplot_width"), "箱宽:", min = 0.1, max = 1, value = 0.5, step = 0.1)),
            column(4, checkboxInput(ns("boxplot_outliers"), "显示异常值", value = TRUE)),
            column(4, checkboxInput(ns("boxplot_notch"), "缺口显示", value = FALSE))
          )
        ),
        "density" = tagList(
          fluidRow(
            column(4, sliderInput(ns("density_alpha"), "填充透明度:", min = 0, max = 1, value = 0.4, step = 0.1)),
            column(4, selectInput(ns("density_position"), "堆叠模式:", choices = c("重叠"="identity", "堆叠"="stack"))),
            column(4, numericInput(ns("density_adjust"), "平滑度:", value = 1, min = 0.1, max = 5, step = 0.1))
          )
        ),
        "histogram" = tagList(
          fluidRow(
            column(4, numericInput(ns("hist_bins"), "分箱数:", value = 30, min = 5, max = 100, step = 1)),
            column(4, selectInput(ns("hist_position"), "堆叠模式:", choices = c("堆叠"="stack", "并排"="dodge", "重叠"="identity"))),
            column(4, sliderInput(ns("hist_alpha"), "透明度:", min = 0, max = 1, value = 0.6, step = 0.1))
          )
        ),
        "area" = tagList(
          fluidRow(
            column(4, selectInput(ns("area_position"), "堆叠模式:", choices = c("堆叠"="stack", "重叠"="identity"))),
            column(4, sliderInput(ns("area_alpha"), "透明度:", min = 0, max = 1, value = 0.4, step = 0.1))
          )
        ),
        "violin" = tagList(
          fluidRow(
            column(4, checkboxInput(ns("violin_trim"), "裁剪尾部", value = TRUE)),
            column(4, checkboxInput(ns("violin_draw_quantiles"), "显示四分位数", value = TRUE)),
            column(4, sliderInput(ns("violin_alpha"), "透明度:", min = 0, max = 1, value = 0.7, step = 0.1))
          )
        )
      )
      
      tabPanel(type_name, br(), content)
    })
    
    do.call(tabsetPanel, tabs)
  })
  
  # 创建单个图形对象 (ggplot2)
  create_ggplot_object <- function(plot_type, data) {
    req(data)
    p <- ggplot(data)
    
    # 获取通用映射
    x_var <- if(input$main_x_var != "none") input$main_x_var else NULL
    y_var <- if(input$main_y_var != "none") input$main_y_var else NULL
    group_var <- if(input$group_var != "none") input$group_var else NULL
    
    # 基础映射
    mapping <- aes()
    if (!is.null(x_var)) mapping <- modifyList(mapping, aes_string(x = x_var))
    if (!is.null(y_var)) mapping <- modifyList(mapping, aes_string(y = y_var))
    
    # 分组映射
    if (!is.null(group_var)) {
      mapping <- modifyList(mapping, aes_string(color = group_var, fill = group_var, group = group_var))
    }
    
    p <- p + mapping
    
    # 根据类型添加图层
    if (plot_type == "scatter") {
      pos <- if(isTRUE(input$scatter_jitter)) position_jitter(width=0.2, height=0.2) else "identity"
      p <- p + geom_point(size = input$scatter_size, alpha = input$scatter_alpha, position = pos)
      
    } else if (plot_type == "line") {
      # 确保折线图有正确的分组
      if (is.null(group_var) && is.null(x_var)) {
         # 如果没有x轴和分组，无法画线
      } else {
        if (is.null(group_var)) p <- p + aes(group = 1)
        p <- p + geom_line(size = input$line_width, linetype = input$line_type)
        if (isTRUE(input$line_smooth)) p <- p + geom_smooth(se = FALSE)
      }
      
    } else if (plot_type == "bar") {
      # 柱状图通常只需要X，或者X+Y(如果是stat="identity")
      # 这里假设是计数(stat="count")如果只有X，或者是值(stat="identity")如果有Y
      stat_method <- if(!is.null(y_var)) "identity" else "count"
      p <- p + geom_bar(stat = stat_method, position = input$bar_position, 
                       width = input$bar_width, alpha = input$bar_alpha)
      
    } else if (plot_type == "boxplot") {
      # 箱线图通常需要离散X和连续Y
      p <- p + geom_boxplot(width = input$boxplot_width, 
                           outlier.shape = if(isTRUE(input$boxplot_outliers)) 19 else NA,
                           notch = isTRUE(input$boxplot_notch))
      
    } else if (plot_type == "density") {
      # 密度图通常只需要X(连续)
      p <- p + geom_density(alpha = input$density_alpha, position = input$density_position, 
                           adjust = input$density_adjust)
      
    } else if (plot_type == "histogram") {
      # 直方图通常只需要X(连续)
      p <- p + geom_histogram(bins = input$hist_bins, position = input$hist_position, 
                             alpha = input$hist_alpha)
      
    } else if (plot_type == "area") {
      # 面积图通常需要X和Y
      stat_method <- if(!is.null(y_var)) "identity" else "count"
      p <- p + geom_area(stat = stat_method, position = input$area_position, 
                        alpha = input$area_alpha)
      
    } else if (plot_type == "violin") {
      # 小提琴图通常需要离散X和连续Y
      draw_q <- if(isTRUE(input$violin_draw_quantiles)) c(0.25, 0.5, 0.75) else NULL
      p <- p + geom_violin(trim = isTRUE(input$violin_trim), draw_quantiles = draw_q, 
                          alpha = input$violin_alpha)
    }
    
    # 添加分面
    if (input$facet_var != "none") {
      p <- p + facet_wrap(as.formula(paste("~", input$facet_var)))
    }
    
    # 通用主题
    p <- p + theme_minimal() + 
      labs(title = paste0(switch(plot_type, "scatter"="散点", "line"="折线", "bar"="柱状", "boxplot"="箱线", 
                                "density"="密度", "histogram"="直方", "area"="面积", "violin"="小提琴"), "图"))
    
    return(p)
  }
  
  # 创建组合图形对象 (返回 list 或 ggplot)
  create_combo_plot_obj <- reactive({
    req(input$plot_types, data(), input$combo_method)
    
    data <- data()
    method <- input$combo_method
    types <- input$plot_types
    
    if (method == "overlay") {
      # 叠加模式：在同一个 ggplot 对象上添加多个图层
      p <- ggplot(data)
      
      # 通用映射
      x_var <- if(input$main_x_var != "none") input$main_x_var else NULL
      y_var <- if(input$main_y_var != "none") input$main_y_var else NULL
      group_var <- if(input$group_var != "none") input$group_var else NULL
      
      mapping <- aes()
      if (!is.null(x_var)) mapping <- modifyList(mapping, aes_string(x = x_var))
      if (!is.null(y_var)) mapping <- modifyList(mapping, aes_string(y = y_var))
      if (!is.null(group_var)) mapping <- modifyList(mapping, aes_string(color = group_var, fill = group_var, group = group_var))
      
      p <- p + mapping
      
      # 逐个添加图层
      for (type in types) {
        if (type == "scatter") {
          pos <- if(isTRUE(input$scatter_jitter)) position_jitter(width=0.2, height=0.2) else "identity"
          p <- p + geom_point(size = input$scatter_size, alpha = input$scatter_alpha, position = pos)
        } else if (type == "line") {
          if (is.null(group_var)) p <- p + geom_line(aes(group=1), size = input$line_width, linetype = input$line_type)
          else p <- p + geom_line(size = input$line_width, linetype = input$line_type)
          if (isTRUE(input$line_smooth)) p <- p + geom_smooth(se = FALSE)
        } else if (type == "bar") {
          stat_method <- if(!is.null(y_var)) "identity" else "count"
          p <- p + geom_bar(stat = stat_method, position = input$bar_position, width = input$bar_width, alpha = input$bar_alpha)
        } else if (type == "boxplot") {
          p <- p + geom_boxplot(width = input$boxplot_width, outlier.shape = if(isTRUE(input$boxplot_outliers)) 19 else NA, notch = isTRUE(input$boxplot_notch))
        } else if (type == "density") {
          p <- p + geom_density(alpha = input$density_alpha, position = input$density_position, adjust = input$density_adjust)
        } else if (type == "histogram") {
          p <- p + geom_histogram(bins = input$hist_bins, position = input$hist_position, alpha = input$hist_alpha)
        } else if (type == "area") {
          stat_method <- if(!is.null(y_var)) "identity" else "count"
          p <- p + geom_area(stat = stat_method, position = input$area_position, alpha = input$area_alpha)
        } else if (type == "violin") {
          draw_q <- if(isTRUE(input$violin_draw_quantiles)) c(0.25, 0.5, 0.75) else NULL
          p <- p + geom_violin(trim = isTRUE(input$violin_trim), draw_quantiles = draw_q, alpha = input$violin_alpha)
        }
      }
      
      # 添加分面
      if (input$facet_var != "none") {
        p <- p + facet_wrap(as.formula(paste("~", input$facet_var)))
      }
      
      p <- p + theme_minimal() + labs(title = "组合图形 (叠加模式)")
      return(p)
      
    } else {
      # 并排或上下模式：创建多个独立的 ggplot 对象列表
      plot_list <- lapply(types, function(type) {
        create_ggplot_object(type, data)
      })
      return(plot_list)
    }
  })
  
  # 图形输出区域 UI
  output$plot_output_area <- renderUI({
    req(input$combo_method)
    if (input$combo_method == "overlay") {
      plotlyOutput(ns("overlay_plot"), height = "600px")
    } else {
      # 对于多个子图，使用 plotOutput (静态) 或 plotlyOutput (动态)
      # 为了布局控制，这里使用 plotly 的 subplot
      plotlyOutput(ns("grid_plot"), height = "800px")
    }
  })
  
  # 叠加图形渲染
  output$overlay_plot <- renderPlotly({
    req(input$combo_method == "overlay")
    p <- create_combo_plot_obj()
    ggplotly(p)
  })
  
  # 网格图形渲染 (并排/上下)
  output$grid_plot <- renderPlotly({
    req(input$combo_method != "overlay")
    plot_list <- create_combo_plot_obj()
    
    # 转换为 plotly 对象
    plotly_list <- lapply(plot_list, ggplotly)
    
    # 确定行数
    nrows <- if(input$combo_method == "side_by_side") 1 else length(plotly_list)
    
    subplot(plotly_list, nrows = nrows, shareX = FALSE, shareY = FALSE, titleX = TRUE, titleY = TRUE)
  })
  
  # 下载处理
  output$download_plot <- downloadHandler(
    filename = function() {
      paste("combo_plot_", Sys.Date(), ".", input$export_format, sep = "")
    },
    content = function(file) {
      obj <- create_combo_plot_obj()
      format <- input$export_format
      
      # 准备用于保存的静态图形对象
      if (inherits(obj, "ggplot")) {
        # 叠加模式：直接是 ggplot 对象
        final_plot <- obj
      } else if (is.list(obj)) {
        # 列表模式：使用 cowplot 或 gridExtra 组合
        nrows <- if(input$combo_method == "side_by_side") 1 else length(obj)
        final_plot <- plot_grid(plotlist = obj, nrow = nrows)
      }
      
      # 保存
      if (format == "pdf") {
        ggsave(file, plot = final_plot, width = 12, height = 8, device = "pdf")
      } else if (format == "svg") {
        ggsave(file, plot = final_plot, width = 12, height = 8, device = "svg")
      } else { # png
        ggsave(file, plot = final_plot, width = 12, height = 8, dpi = 300)
      }
    }
  )
  
  return(reactive({
    list(
      plot_types = input$plot_types,
      method = input$combo_method
    )
  }))
}
