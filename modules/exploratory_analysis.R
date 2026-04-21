# 探索分析模块
# 负责数据的交互式可视化和探索性分析

source("modules/common/ui_shell.R")

exploratory_analysis_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      app_card_box(
        width = 3,
        title = "变量托盘",
        subtitle = "继续保留可用变量浏览与类型提示，只统一入口卡片视觉",
        tone = "primary",
        status = "primary",
        solidHeader = FALSE,
        app_card_note("当前统一变量托盘卡片、说明块与滚动容器，不调整变量类型判定或输出内容。"),
        app_card_panel(
          tags$div(
            style = "max-height: 500px; overflow-y: auto;",
            uiOutput(ns("variable_tray"))
          )
        )
      ),
      app_card_box(
        width = 9,
        title = "图形控制器",
        subtitle = "继续保留图形类型切换、变量映射与标题设置链路",
        tone = "warning",
        status = "warning",
        solidHeader = FALSE,
        app_card_note("本轮只统一控制器入口卡、参数分区与说明块，不改变 tooltip、动态变量过滤与重置行为。"),
        app_card_panel(
          fluidRow(
            column(6,
                  selectizeInput(ns("plot_type_exp"), "图形类型",
                                choices = c("散点图", "箱线图", "直方图", "条形图")),
                  bsTooltip(ns("plot_type_exp"), "选择图形类型将自动过滤可用的变量选项")
            ),
            column(6, actionButton(ns("reset_mapping"), "重置映射", icon = icon("refresh")))
          )
        ),
        app_card_panel(
          tags$strong("变量映射"),
          app_card_note("继续通过动态 UI 输出 X/Y/颜色/分面变量选择；图形类型切换后保持原有变量过滤规则。"),
          fluidRow(
            column(3,
                  uiOutput(ns("aes_x")),
                  bsTooltip(ns("aes_x"), "X轴变量：散点图和箱线图需要数值变量，直方图和条形图需要分类变量")
            ),
            column(3,
                  uiOutput(ns("aes_y")),
                  bsTooltip(ns("aes_y"), "Y轴变量：散点图和箱线图需要数值变量")
            ),
            column(3,
                  uiOutput(ns("aes_color")),
                  bsTooltip(ns("aes_color"), "颜色变量：可以是分类变量或数值变量")
            ),
            column(3,
                  uiOutput(ns("aes_facet")),
                  bsTooltip(ns("aes_facet"), "分面变量：应该是分类变量")
            )
          )
        ),
        app_card_panel(
          tags$strong("标题与标签"),
          app_card_note("继续保留图形标题、副标题和坐标轴标签自定义输入，不改变默认回退文案逻辑。"),
          fluidRow(
            column(6,
                   textInput(ns("plot_title"), "图形标题", value = "", placeholder = "输入图形标题")
            ),
            column(6,
                   textInput(ns("plot_subtitle"), "图形副标题", value = "", placeholder = "输入图形副标题（可选）")
            )
          ),
          fluidRow(
            column(6,
                   textInput(ns("x_axis_label"), "X轴标签", value = "", placeholder = "输入X轴标签")
            ),
            column(6,
                   textInput(ns("y_axis_label"), "Y轴标签", value = "", placeholder = "输入Y轴标签")
            )
          )
        )
      )
    ),
    fluidRow(
      app_card_box(
        width = 12, 
        title = "图形输出", 
        subtitle = "继续保留 Plotly 结果输出与分页提示链路",
        tone = "success",
        status = "success",
        solidHeader = FALSE,
        app_card_note("当前统一结果卡与说明块，不调整 Plotly 渲染、错误占位图或分页提示逻辑。"),
        app_result_panel(
          title = "探索图形结果",
          note = "展示当前变量映射生成的交互式图形，并继续保留分页说明与异常提示输出。",
          tone = "success",
          plotly::plotlyOutput(ns("exploratory_plot"), height = "600px"),
          br(),
          uiOutput(ns("plotly_info"))
        )
      )
    )
  )
}

exploratory_analysis_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  
  # 探索分析变量托盘
  output$variable_tray <- renderUI({
    req(data())
    
    tagList(
      h4("可用变量"),
      tags$div(
        class = "variable-tray-container",
        lapply(names(data()), function(var) {
          var_type <- if (is.numeric(data()[[var]])) "numeric"
          else if (is.character(data()[[var]]) || is.factor(data()[[var]])) "categorical"
          else "other"
          
          type_display <- switch(var_type,
                                "numeric" = tags$span("123", style = "font-weight: bold; color: blue;"),
                                "categorical" = tags$span("abc", style = "font-weight: bold; color: green;"),
                                "other" = tags$span("?", style = "font-weight: bold; color: gray;"))
          
          tags$div(
            class = "variable-item",
            type_display,
            tags$span(var),
            style = "margin: 5px; padding: 5px; background: #f0f0f0; border-radius: 3px; display: flex; align-items: center; gap: 5px;"
          )
        })
      )
    )
  })
  
  # 图形映射控制器
  output$aes_x <- renderUI({
    req(data(), input$plot_type_exp)
    
    data_df <- data()
    var_types <- sapply(data_df, function(x) {
      if (is.numeric(x)) "numeric"
      else if (is.factor(x) || is.character(x)) "categorical"
      else "other"
    })
    
    allowed_types <- switch(input$plot_type_exp,
                           "散点图" = "numeric",
                           "箱线图" = "categorical",
                           "直方图" = "numeric",
                           "条形图" = "categorical")
    
    allowed_vars <- names(data_df)[var_types %in% allowed_types]
    
    selectizeInput(ns("x_var"), "X轴变量", choices = c("无" = "", allowed_vars))
  })
  
  output$aes_y <- renderUI({
    req(data(), input$plot_type_exp)
    
    data_df <- data()
    var_types <- sapply(data_df, function(x) {
      if (is.numeric(x)) "numeric"
      else if (is.factor(x) || is.character(x)) "categorical"
      else "other"
    })
    
    if (input$plot_type_exp %in% c("散点图", "箱线图")) {
      allowed_types <- "numeric"
      allowed_vars <- names(data_df)[var_types %in% allowed_types]
    } else {
      allowed_vars <- character(0)
    }
    
    selectizeInput(ns("y_var"), "Y轴变量", choices = c("无" = "", allowed_vars))
  })
  
  output$aes_color <- renderUI({
    req(data())
    data_df <- data()
    var_types <- sapply(data_df, function(x) {
      if (is.numeric(x)) "numeric"
      else if (is.factor(x) || is.character(x)) "categorical"
      else "other"
    })
    
    # 颜色变量可以是分类变量或数值变量（用于连续颜色映射）
    allowed_vars <- names(data_df)[var_types %in% c("categorical", "numeric")]
    
    selectizeInput(ns("color_var"), "颜色变量", choices = c("无" = "", allowed_vars))
  })
  
  output$aes_facet <- renderUI({
    req(data())
    data_df <- data()
    var_types <- sapply(data_df, function(x) {
      if (is.numeric(x)) "numeric"
      else if (is.factor(x) || is.character(x)) "categorical"
      else "other"
    })
    
    # 分面变量应该是分类变量
    allowed_vars <- names(data_df)[var_types %in% "categorical"]
    
    selectizeInput(ns("facet_var"), "分面变量", choices = c("无" = "", allowed_vars))
  })
  
  # Plotly分页信息显示
  output$plotly_info <- renderUI({
    req(input$plotly_pagination_info)
    tags$div(
      style = "background-color: #f8f9fa; border-left: 4px solid #007bff; padding: 10px; margin-top: 10px;",
      tags$strong("关于Plotly分页功能:"),
      tags$p(input$plotly_pagination_info)
    )
  })
  
  # 探索性图形
  output$exploratory_plot <- plotly::renderPlotly({
    req(data(), input$plot_type_exp)
    plot_family <- graphics_resolve_font_spec("sans")$unified
    
    # 验证必要的输入
    if (input$plot_type_exp %in% c("散点图", "箱线图") &&
        (is.null(input$x_var) || input$x_var == "" || is.null(input$y_var) || input$y_var == "")) {
      showNotification("散点图和箱线图需要选择X轴和Y轴变量", type = "warning")
      return(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = "请选择X轴和Y轴变量", size = 6, color = "red", family = plot_family) +
          theme_void(base_family = plot_family)
      ) %>% ggplotly() %>% layout(height = 600)
    }
    
    if (input$plot_type_exp %in% c("直方图", "条形图") &&
        (is.null(input$x_var) || input$x_var == "")) {
      showNotification("直方图和条形图需要选择X轴变量", type = "warning")
      return(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = "请选择X轴变量", size = 6, color = "red", family = plot_family) +
          theme_void(base_family = plot_family)
      ) %>% ggplotly() %>% layout(height = 600)
    }
    
    # 验证变量是否存在数据中
    if (!is.null(input$x_var) && input$x_var != "" && !input$x_var %in% names(data())) {
      showNotification(paste("X轴变量", input$x_var, "不存在于数据中"), type = "error")
      return(NULL)
    }
    
    if (!is.null(input$y_var) && input$y_var != "" && !input$y_var %in% names(data())) {
      showNotification(paste("Y轴变量", input$y_var, "不存在于数据中"), type = "error")
      return(NULL)
    }
    
    if (!is.null(input$color_var) && input$color_var != "" && !input$color_var %in% names(data())) {
      showNotification(paste("颜色变量", input$color_var, "不存在于数据中"), type = "error")
      return(NULL)
    }
    
    if (!is.null(input$facet_var) && input$facet_var != "" && !input$facet_var %in% names(data())) {
      showNotification(paste("分面变量", input$facet_var, "不存在于数据中"), type = "error")
      return(NULL)
    }
    
    tryCatch({
      p <- switch(input$plot_type_exp,
                  "散点图" = {
                    req(input$x_var, input$y_var)
                    # 检查变量类型是否匹配
                    if (!is.numeric(data()[[input$x_var]]) || !is.numeric(data()[[input$y_var]])) {
                      stop("散点图需要数值型变量作为X轴和Y轴")
                    }
                    
                    p <- ggplot(data(), aes(x = .data[[input$x_var]], y = .data[[input$y_var]]))
                    if (input$color_var != "") {
                      p <- p + geom_point(aes(color = .data[[input$color_var]]), alpha = 0.6, size = 3)
                    } else {
                      p <- p + geom_point(alpha = 0.6, size = 3)
                    }
                    p + theme_minimal(base_size = 14, base_family = plot_family) +
                      labs(x = input$x_var, y = input$y_var)
                  },
                  "箱线图" = {
                    req(input$x_var, input$y_var)
                    # 检查变量类型是否匹配
                    if (!is.numeric(data()[[input$y_var]])) {
                      stop("箱线图需要数值型变量作为Y轴")
                    }
                    
                    p <- ggplot(data(), aes(x = .data[[input$x_var]], y = .data[[input$y_var]]))
                    if (input$color_var != "") {
                      p <- p + geom_boxplot(aes(fill = .data[[input$color_var]]), alpha = 0.7)
                    } else {
                      p <- p + geom_boxplot(alpha = 0.7)
                    }
                    p + theme_minimal(base_size = 14, base_family = plot_family) +
                      labs(x = input$x_var, y = input$y_var)
                  },
                  "直方图" = {
                    req(input$x_var)
                    # 检查变量类型是否匹配
                    if (!is.numeric(data()[[input$x_var]])) {
                      stop("直方图需要数值型变量作为X轴")
                    }
                    
                    p <- ggplot(data(), aes(x = .data[[input$x_var]]))
                    if (input$color_var != "") {
                      p <- p + geom_histogram(aes(fill = .data[[input$color_var]]), bins = 30, alpha = 0.7, color = "white")
                    } else {
                      p <- p + geom_histogram(bins = 30, alpha = 0.7, color = "white")
                    }
                    p + theme_minimal(base_size = 14, base_family = plot_family) +
                      labs(x = input$x_var, y = "频数")
                  },
                  "条形图" = {
                    req(input$x_var)
                    p <- ggplot(data(), aes(x = .data[[input$x_var]]))
                    if (input$color_var != "") {
                      p <- p + geom_bar(aes(fill = .data[[input$color_var]]), alpha = 0.7, color = "white")
                    } else {
                      p <- p + geom_bar(alpha = 0.7, color = "white")
                    }
                    p + theme_minimal(base_size = 14, base_family = plot_family) +
                      labs(x = input$x_var, y = "计数")
                  })
      
      if (input$facet_var != "") {
        p <- p + facet_wrap(as.formula(paste("~", input$facet_var)))
      }
      
      # 添加自定义标题和坐标轴标签
      if (input$plot_title != "") {
        p <- p + ggtitle(input$plot_title)
      } else {
        p <- p + ggtitle(paste("图形类型:", input$plot_type_exp))
      }
      
      if (input$plot_subtitle != "") {
        p <- p + labs(subtitle = input$plot_subtitle)
      }
      
      if (input$x_axis_label != "") {
        p <- p + xlab(input$x_axis_label)
      } else if (!is.null(input$x_var) && input$x_var != "") {
        p <- p + xlab(input$x_var)
      }
      
      if (input$y_axis_label != "") {
        p <- p + ylab(input$y_axis_label)
      } else if (!is.null(input$y_var) && input$y_var != "") {
        p <- p + ylab(input$y_var)
      }
      
      ggplotly(p, height = 600) %>%
        layout(autosize = TRUE)
      
    }, error = function(e) {
      # 记录详细的错误信息到控制台
      message(paste("探索性图形生成错误详情:", e$message))
      message(paste("调用栈:", paste(deparse(e$call), collapse = "\n")))
      
      showNotification(paste("图形生成错误:", e$message), type = "error")
      
      # 返回错误信息图
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = paste("图形生成失败:\n", e$message),
                 size = 4, color = "red", family = plot_family) +
        theme_void(base_family = plot_family)
      
      ggplotly(p) %>% layout(height = 600)
    })
  })
  
  # 重置映射
  observeEvent(input$reset_mapping, {
    updateSelectizeInput(session, "x_var", selected = "")
    updateSelectizeInput(session, "y_var", selected = "")
    updateSelectizeInput(session, "color_var", selected = "")
    updateSelectizeInput(session, "facet_var", selected = "")
    updateTextInput(session, "plot_title", value = "")
    updateTextInput(session, "plot_subtitle", value = "")
    updateTextInput(session, "x_axis_label", value = "")
    updateTextInput(session, "y_axis_label", value = "")
  })
  
  # 返回模块状态（可选）
  return(reactive({
    list(
      x_var = input$x_var,
      y_var = input$y_var,
      color_var = input$color_var,
      facet_var = input$facet_var,
      plot_type = input$plot_type_exp
    )
  }))
  })
}
