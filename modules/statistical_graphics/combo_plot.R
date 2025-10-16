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
library(viridis)
library(shinyalert)
library(scales)

combo_plot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        width = 12,
        title = "组合图形参数配置",
        status = "primary",
        solidHeader = TRUE,
        fluidRow(
          column(4,
                 selectizeInput(ns("main_x_var"), "主X轴变量:", 
                              choices = c("无" = "none"), selected = "none")
          ),
          column(4,
                 selectizeInput(ns("main_y_var"), "主Y轴变量:", 
                              choices = c("无" = "none"), selected = "none")
          ),
          column(4,
                 selectizeInput(ns("group_var"), "全局分组变量:", 
                              choices = c("无分组" = "none"), selected = "none")
          )
        ),
        fluidRow(
          column(4,
                 selectizeInput(ns("secondary_x_var"), "次X轴变量:", 
                              choices = c("无" = "none"), selected = "none")
          ),
          column(4,
                 selectizeInput(ns("secondary_y_var"), "次Y轴变量:", 
                              choices = c("无" = "none"), selected = "none")
          ),
          column(4,
                 selectizeInput(ns("facet_var"), "全局分面变量:", 
                              choices = c("无分面" = "none"), selected = "none")
          )
        )
      )
    ),
    
    # 图形组合设置
    fluidRow(
      box(
        width = 12,
        title = "图形组合设置",
        status = "primary",
        solidHeader = TRUE,
        fluidRow(
          column(6,
                 checkboxGroupInput(ns("plot_types"), "选择图形类型:",
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
                                  selected = c("scatter", "line"))
          ),
          column(6,
                 radioButtons(ns("combo_method"), "组合方式:",
                            choices = c(
                              "叠加显示" = "overlay",
                              "并排显示" = "side_by_side",
                              "上下显示" = "top_bottom"
                            ),
                            selected = "overlay")
          )
        )
      )
    ),
    
    # 详细参数设置
    fluidRow(
      box(
        width = 12,
        title = "详细参数设置",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = TRUE,
        
        # 散点图设置
        conditionalPanel(
          condition = paste0("input['", ns("plot_types"), "'].includes('scatter')"),
          div(class = "individual-plot-settings",
              h4("散点图设置"),
              fluidRow(
                column(3,
                       selectInput(ns("scatter_x_var"), "X轴变量:",
                                 choices = c("使用主轴" = "main_axis", "使用次轴" = "secondary_axis", "无" = "none"), selected = "main_axis")
                ),
                column(3,
                       selectInput(ns("scatter_y_var"), "Y轴变量:",
                                 choices = c("使用主轴" = "main_axis", "使用次轴" = "secondary_axis", "无" = "none"), selected = "main_axis")
                ),
                column(2,
                       numericInput(ns("scatter_size"), "散点大小:", value = 2, min = 0.5, max = 10)
                ),
                column(2,
                       numericInput(ns("scatter_alpha"), "透明度:", value = 0.7, min = 0, max = 1, step = 0.1)
                ),
                column(2,
                       checkboxInput(ns("scatter_jitter"), "抖动:", value = FALSE)
                )
              )
          )
        ),
        
        # 折线图设置
        conditionalPanel(
          condition = paste0("input['", ns("plot_types"), "'].includes('line')"),
          div(class = "individual-plot-settings",
              h4("折线图设置"),
              fluidRow(
                column(3,
                       selectInput(ns("line_x_var"), "X轴变量:",
                                 choices = c("使用主轴" = "main_axis", "使用次轴" = "secondary_axis", "无" = "none"), selected = "main_axis")
                ),
                column(3,
                       selectInput(ns("line_y_var"), "Y轴变量:",
                                 choices = c("使用主轴" = "main_axis", "使用次轴" = "secondary_axis", "无" = "none"), selected = "main_axis")
                ),
                column(2,
                       numericInput(ns("line_width"), "线条宽度:", value = 1, min = 0.1, max = 5)
                ),
                column(2,
                       numericInput(ns("line_alpha"), "透明度:", value = 1, min = 0, max = 1, step = 0.1)
                ),
                column(2,
                       checkboxInput(ns("line_smooth"), "平滑线:", value = FALSE)
                )
              )
          )
        ),
        
        # 箱线图设置
        conditionalPanel(
          condition = paste0("input['", ns("plot_types"), "'].includes('boxplot')"),
          div(class = "individual-plot-settings",
              h4("箱线图设置"),
              fluidRow(
                column(3,
                       selectInput(ns("boxplot_x_var"), "X轴变量:",
                                 choices = c("使用主轴" = "main_axis", "使用次轴" = "secondary_axis", "无" = "none"), selected = "main_axis")
                ),
                column(3,
                       selectInput(ns("boxplot_y_var"), "Y轴变量:",
                                 choices = c("使用主轴" = "main_axis", "使用次轴" = "secondary_axis", "无" = "none"), selected = "main_axis")
                ),
                column(2,
                       numericInput(ns("boxplot_width"), "箱宽:", value = 0.5, min = 0.1, max = 1, step = 0.1)
                ),
                column(2,
                       numericInput(ns("boxplot_alpha"), "透明度:", value = 0.7, min = 0, max = 1, step = 0.1)
                ),
                column(2,
                       checkboxInput(ns("boxplot_outliers"), "显示异常值:", value = TRUE)
                )
              )
          )
        )
      )
    ),
    
    # 图形显示和输出控制
    fluidRow(
      column(8,
             box(
               width = 12,
               title = "组合图形预览",
               status = "success",
               solidHeader = TRUE,
               uiOutput(ns("plot_output"))
             )
      ),
      column(4,
             box(
               width = 12,
               title = "输出控制",
               status = "primary",
               solidHeader = TRUE,
               actionButton(ns("refresh_plot"), "刷新图形", class = "btn-primary btn-block"),
               br(), br(),
               selectInput(ns("export_format"), "导出格式",
                         choices = c("PNG" = "png", "PDF" = "pdf", "SVG" = "svg"),
                         selected = "png"),
               downloadButton(ns("download_plot"), "导出图形", class = "btn-block")
             )
      )
    )
  )
}

combo_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储图形参数状态
  graphics_state <- reactiveValues(
    main_x_var = NULL,
    main_y_var = NULL,
    secondary_x_var = NULL,
    secondary_y_var = NULL,
    group_var = NULL,
    facet_var = NULL,
    plot_types = c("scatter", "line"),
    combo_method = "overlay"
  )
  
  # 更新变量选择
  observe({
    req(data())
    vars <- names(data())
    
    # 更新所有变量选择
    updateSelectizeInput(session, "main_x_var", choices = c("无" = "none", vars), selected = "none")
    updateSelectizeInput(session, "main_y_var", choices = c("无" = "none", vars), selected = "none")
    updateSelectizeInput(session, "secondary_x_var", choices = c("无" = "none", vars), selected = "none")
    updateSelectizeInput(session, "secondary_y_var", choices = c("无" = "none", vars), selected = "none")
    updateSelectizeInput(session, "group_var", choices = c("无分组" = "none", vars), selected = "none")
    updateSelectizeInput(session, "facet_var", choices = c("无分面" = "none", vars), selected = "none")
  })
  
  # 观察并保存图形参数
  observe({
    graphics_state$main_x_var <- input$main_x_var
    graphics_state$main_y_var <- input$main_y_var
    graphics_state$secondary_x_var <- input$secondary_x_var
    graphics_state$secondary_y_var <- input$secondary_y_var
    graphics_state$group_var <- input$group_var
    graphics_state$facet_var <- input$facet_var
    graphics_state$plot_types <- input$plot_types
    graphics_state$combo_method <- input$combo_method
  })
  
  # 获取实际变量名的辅助函数
  get_actual_variable <- function(plot_specific_var, main_axis_var, secondary_axis_var, data_vars) {
    if (plot_specific_var == "main_axis") {
      if (main_axis_var == "none") {
        return(NULL)
      } else {
        return(main_axis_var)
      }
    } else if (plot_specific_var == "secondary_axis") {
      if (secondary_axis_var == "none") {
        return(NULL)
      } else {
        return(secondary_axis_var)
      }
    } else if (plot_specific_var == "none") {
      return(NULL)
    } else {
      if (plot_specific_var %in% data_vars) {
        return(plot_specific_var)
      } else {
        return(NULL)
      }
    }
  }
  
  # 创建单个图形的函数
  create_single_plot <- function(plot_type, data) {
    req(data)
    
    data_vars <- names(data)
    
    # 根据图形类型获取变量设置
    x_var_input <- switch(plot_type,
                         "scatter" = input$scatter_x_var,
                         "line" = input$line_x_var,
                         "boxplot" = input$boxplot_x_var,
                         "main_axis")
    
    y_var_input <- switch(plot_type,
                         "scatter" = input$scatter_y_var,
                         "line" = input$line_y_var,
                         "boxplot" = input$boxplot_y_var,
                         "main_axis")
    
    # 获取实际变量名
    x_var <- get_actual_variable(x_var_input, input$main_x_var, input$secondary_x_var, data_vars)
    y_var <- get_actual_variable(y_var_input, input$main_y_var, input$secondary_y_var, data_vars)
    group_var <- if (input$group_var != "none") input$group_var else NULL
    
    # 检查必需的变量
    if (is.null(x_var) && plot_type != "density" && plot_type != "histogram") {
      return(ggplot() +
               labs(title = paste("错误:", plot_type, "图需要X轴变量"),
                    subtitle = "请选择有效的X轴变量") +
               theme_void())
    }
    
    # 创建基础图形
    if (!is.null(y_var)) {
      p <- ggplot(data, aes_string(x = x_var, y = y_var))
    } else {
      p <- ggplot(data, aes_string(x = x_var))
    }
    
    # 添加分组
    if (!is.null(group_var)) {
      p <- p + aes_string(color = group_var, fill = group_var, group = group_var)
    }
    
    # 添加几何对象
    if (plot_type == "scatter") {
      position <- if(input$scatter_jitter) {
        position_jitter(width = 0.2, height = 0.2)
      } else {
        "identity"
      }
      
      p <- p + geom_point(
        size = input$scatter_size,
        alpha = input$scatter_alpha,
        position = position
      )
    } else if (plot_type == "line") {
      if (is.null(group_var)) {
        p <- p + aes(group = 1)
      }
      p <- p + geom_line(
        size = input$line_width,
        alpha = input$line_alpha
      )
      if (input$line_smooth) {
        p <- p + geom_smooth(se = FALSE, method = "loess")
      }
    } else if (plot_type == "boxplot") {
      p <- p + geom_boxplot(
        width = input$boxplot_width,
        alpha = input$boxplot_alpha,
        outlier.shape = if(input$boxplot_outliers) 16 else NA
      )
    }
    
    # 应用主题
    p <- p + theme_minimal() +
      labs(title = plot_type)
    
    return(p)
  }
  
  # 创建叠加组合图形
  create_overlay_plot <- reactive({
    req(input$plot_types, data(), input$combo_method)
    
    # 仅在叠加模式下执行
    if (input$combo_method != "overlay") {
      return(ggplot() + theme_void() + labs(title = "非叠加模式下不使用此函数"))
    }
    
    data <- data()
    data_vars <- names(data)
    
    # 如果没有选择任何图形类型
    if (length(input$plot_types) == 0) {
      return(ggplot() +
               labs(title = "请选择至少一个图形类型") +
               theme_void())
    }
    
    # 获取主次轴变量
    main_x_var <- if (input$main_x_var != "none") input$main_x_var else NULL
    main_y_var <- if (input$main_y_var != "none") input$main_y_var else NULL
    
    # 至少需要一个主轴变量
    if (is.null(main_x_var) && is.null(main_y_var)) {
      return(ggplot() + labs(title = "叠加模式需要至少指定一个主轴变量") + theme_void())
    }
    
    # 创建基础图形对象
    p <- ggplot(data)
    
    # 添加分组
    group_var <- if (input$group_var != "none") input$group_var else NULL
    if (!is.null(group_var)) {
      p <- p + aes_string(color = group_var, fill = group_var, group = group_var)
    }
    
    # 遍历每个选中的图形类型并添加图层
    for (plot_type in input$plot_types) {
      if (plot_type == "scatter") {
        x_var <- get_actual_variable(input$scatter_x_var, input$main_x_var, input$secondary_x_var, data_vars)
        y_var <- get_actual_variable(input$scatter_y_var, input$main_y_var, input$secondary_y_var, data_vars)
        
        if (!is.null(x_var) && !is.null(y_var)) {
          position <- if(input$scatter_jitter) {
            position_jitter(width = 0.2, height = 0.2)
          } else {
            "identity"
          }
          
          p <- p + geom_point(
            aes_string(x = x_var, y = y_var),
            size = input$scatter_size,
            alpha = input$scatter_alpha,
            position = position
          )
        }
      } else if (plot_type == "line") {
        x_var <- get_actual_variable(input$line_x_var, input$main_x_var, input$secondary_x_var, data_vars)
        y_var <- get_actual_variable(input$line_y_var, input$main_y_var, input$secondary_y_var, data_vars)
        
        if (!is.null(x_var) && !is.null(y_var)) {
          if (is.null(group_var)) {
            p <- p + geom_line(aes_string(x = x_var, y = y_var, group = 1),
                              size = input$line_width,
                              alpha = input$line_alpha)
          } else {
            p <- p + geom_line(aes_string(x = x_var, y = y_var),
                              size = input$line_width,
                              alpha = input$line_alpha)
          }
          
          if (input$line_smooth) {
            if (is.null(group_var)) {
              p <- p + geom_smooth(aes_string(x = x_var, y = y_var, group = 1), 
                                  se = FALSE, method = "loess")
            } else {
              p <- p + geom_smooth(aes_string(x = x_var, y = y_var), 
                                  se = FALSE, method = "loess")
            }
          }
        }
      } else if (plot_type == "boxplot") {
        x_var <- get_actual_variable(input$boxplot_x_var, input$main_x_var, input$secondary_x_var, data_vars)
        y_var <- get_actual_variable(input$boxplot_y_var, input$main_y_var, input$secondary_y_var, data_vars)
        
        if (!is.null(x_var) && !is.null(y_var)) {
          p <- p + geom_boxplot(
            aes_string(x = x_var, y = y_var),
            width = input$boxplot_width,
            alpha = input$boxplot_alpha,
            outlier.shape = if(input$boxplot_outliers) 16 else NA
          )
        }
      }
    }
    
    # 设置坐标轴标签
    if (!is.null(main_x_var)) {
      p <- p + xlab(main_x_var)
    }
    if (!is.null(main_y_var)) {
      p <- p + ylab(main_y_var)
    }
    
    # 添加标题
    plot_types_names <- c(
      "scatter" = "散点图", "line" = "折线图", "bar" = "柱状图",
      "boxplot" = "箱线图", "density" = "密度图", "histogram" = "直方图",
      "area" = "面积图", "violin" = "小提琴图"
    )
    selected_names <- plot_types_names[input$plot_types]
    p <- p + labs(title = paste("组合图形 (叠加):", paste(selected_names, collapse = " + ")))
    
    return(p)
  })
  
  # 输出图形UI
  output$plot_output <- renderUI({
    req(input$combo_method)
    
    if (input$combo_method == "overlay") {
      plotlyOutput(ns("main_plot"), height = "500px")
    } else if (input$combo_method == "side_by_side") {
      plotlyOutput(ns("side_plot"), height = "500px")
    } else if (input$combo_method == "top_bottom") {
      plotlyOutput(ns("top_bottom_plot"), height = "500px")
    }
  })
  
  # 叠加显示图形
  output$main_plot <- renderPlotly({
    p <- create_overlay_plot()
    ggplotly(p)
  })
  
  # 并排显示图形
  output$side_plot <- renderPlotly({
    req(input$plot_types, data())
    
    plot_list <- list()
    for (plot_type in input$plot_types) {
      p <- create_single_plot(plot_type, data())
      plot_list[[plot_type]] <- ggplotly(p)
    }
    
    if (length(plot_list) > 0) {
      subplot(plot_list, nrows = 1, shareX = FALSE, shareY = FALSE)
    } else {
      ggplotly(ggplot() + theme_void())
    }
  })
  
  # 上下显示图形
  output$top_bottom_plot <- renderPlotly({
    req(input$plot_types, data())
    
    plot_list <- list()
    for (plot_type in input$plot_types) {
      p <- create_single_plot(plot_type, data())
      plot_list[[plot_type]] <- ggplotly(p)
    }
    
    if (length(plot_list) > 0) {
      subplot(plot_list, nrows = length(plot_list), shareX = FALSE, shareY = FALSE)
    } else {
      ggplotly(ggplot() + theme_void())
    }
  })
  
  # 下载处理
  output$download_plot <- downloadHandler(
    filename = function() {
      paste("combo_plot_", Sys.Date(), ".", input$export_format, sep = "")
    },
    content = function(file) {
      plot_obj <- create_overlay_plot()
      plot_format <- input$export_format
      
      if (plot_format == "pdf") {
        ggsave(file, plot = plot_obj, width = 10, height = 8, device = "pdf")
      } else if (plot_format == "svg") {
        ggsave(file, plot = plot_obj, width = 10, height = 8, device = "svg")
      } else { # png
        ggsave(file, plot = plot_obj, width = 10, height = 8, dpi = 300)
      }
    }
  )
  
  # 返回模块状态
  return(reactive({
    list(
      main_x_var = input$main_x_var,
      main_y_var = input$main_y_var,
      plot_types = input$plot_types,
      combo_method = input$combo_method
    )
  }))
}