# 生存分析图形子模块
# 负责生成生存曲线（Kaplan-Meier曲线）

# 加载必要的包
library(survival)
library(survminer)
library(plotly)
library(DT)
library(cowplot)

survival_analysis_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # 高级美学设置
    fluidRow(
      box(
        width = 12,
        title = "高级美学设置",
        status = "warning",
        collapsible = TRUE,
        collapsed = TRUE,
        fluidRow(
          column(12,
                 fluidRow(
                   column(9,
                          textInput(ns("plot_title"), "主标题", value = "", width = "100%")
                   ),
                   column(3,
                          numericInput(ns("title_size"), "主标题大小", value = 14, min = 8, max = 24, step = 1)
                   )
                 )
          )
        ),
        fluidRow(
          column(12,
                 fluidRow(
                   column(9,
                          textInput(ns("plot_caption"), "脚注", value = "", width = "100%")
                   ),
                   column(3,
                          numericInput(ns("caption_size"), "脚注大小", value = 10, min = 8, max = 20, step = 1)
                   )
                 )
          )
        ),
        fluidRow(
          column(6,
                 fluidRow(
                   column(9,
                          textInput(ns("plot_xlab"), "X轴标签", value = "", width = "100%")
                   ),
                   column(3,
                          numericInput(ns("xlab_size"), "X轴标签大小", value = 12, min = 8, max = 20, step = 1)
                   )
                 )
          ),
          column(6,
                 fluidRow(
                   column(9,
                          textInput(ns("plot_ylab"), "Y轴标签", value = "", width = "100%")
                   ),
                   column(3,
                          numericInput(ns("ylab_size"), "Y轴标签大小", value = 12, min = 8, max = 20, step = 1)
                   )
                 )
          )
        ),
        fluidRow(
          column(2,
                 numericInput(ns("line_size"), "线条大小", value = 0.6, min = 0.1, max = 5, step = 0.1)
          ),
          column(2,
                 selectInput(ns("line_type"), "线条类型",
                           choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted",
                                      "点虚线" = "dotdash", "长虚线" = "longdash"))
          ),
          column(2,
                 checkboxInput(ns("km_show_censor"), "显示删失符号", value = TRUE)
          ),
          column(2,
                 numericInput(ns("km_censor_size"), "删失点大小", value = 2, min = 1, max = 10, step = 0.5)
          ),
          column(2,
                 selectInput(ns("km_censor_shape"), "删失点形状",
                           choices = c("+" = 3, "I" = 124, "□" = 0, "○" = 1, "△" = 2, "◇" = 5, "☆" = 8),
                           selected = 3)
          ),
          column(2,
                 numericInput(ns("y_text_size"), "风险表Y轴标签大小", value = 10, min = 6, max = 20, step = 1)
          )
        )
      )
    ),
    
    # 生存曲线输出
    fluidRow(
      box(
        width = 12,
        title = "生存曲线输出",
        status = "info",
        solidHeader = TRUE,
        fluidRow(
          # 参数配置侧边栏
          column(3,
            wellPanel(
              h4("参数配置", style = "margin-top: 0px;"),
              selectizeInput(ns("km_time"), "时间变量 (数值型)", choices = NULL),
              selectizeInput(ns("km_status"), "状态变量 (数值型)", choices = NULL),
              selectizeInput(ns("strata_var"), "分层变量 (分组)", choices = c("无" = "None")),
              selectizeInput(ns("facet_var"), "分面变量 (分组)", choices = c("无" = "None")),
              # 分面值选择器（仅当选择了分面变量时显示）
              conditionalPanel(
                condition = paste0("input['", ns("facet_var"), "'] != 'None'"),
                uiOutput(ns("facet_value_ui"))
              ),
              radioButtons(ns("km_censor_value"), "删失值定义",
                         choices = c("0 = 删失, 1 = 事件" = "0", "1 = 删失, 0 = 事件" = "1"),
                         selected = "0"),
              checkboxInput(ns("km_show_risktable"), "显示风险表", value = TRUE),
              checkboxInput(ns("show_ci"), "显示置信区间", value = FALSE),
              # 时间范围滑块
              uiOutput(ns("time_range_slider")),
              br(),
              actionButton(ns("render_km_plot"), "生成图形", icon = icon("chart-line"),
                         class = "btn btn-primary"),
              br(), br(),
              # 导出格式选择
              selectInput(ns("export_format"), "导出格式",
                         choices = c("PDF" = "pdf", "PNG" = "png", "SVG" = "svg"),
                         selected = "pdf"),
              br(),
              downloadButton(ns("download_plot"), "导出图形")
            )
          ),
          # 主图显示区域
          column(9,
            tabsetPanel(
              id = ns("km_output_tabs"),
              tabPanel("静态图", plotOutput(ns("survPlot"), height = "600px")),
              tabPanel("交互式图", plotly::plotlyOutput(ns("interactiveSurvPlot"), height = "600px")),
              tabPanel("数据表", DTOutput(ns("km_data_table")))
            )
          )
        )
      )
    )
  )
}

survival_analysis_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储图形参数状态
  graphics_state <- reactiveValues(
    km_time = NULL,
    km_status = NULL,
    km_censor_value = "0",
    km_strata = "None",
    km_facet = "None",
    km_facet_values = NULL,
    km_show_risktable = TRUE,
    km_line_size = 0.6,
    km_line_type = "solid",
    km_censor_size = 3,
    km_censor_shape = 3,
    y_text_size = 10,
    title_size = 14,
    caption_size = 10,
    xlab_size = 12,
    ylab_size = 12
  )
  
  # 更新变量选择
  observe({
    req(data())
    
    # 获取分类变量和数值变量列表
    categorical_vars <- names(data())[sapply(data(), function(x) is.factor(x) || is.character(x) || is.logical(x))]
    numeric_vars <- names(data())[sapply(data(), is.numeric)]
    
    # 更新时间变量选择
    if(length(numeric_vars) > 0) {
      # 如果当前选择不在选项中，设置为第一个选项
      current_time_choice <- if(is.null(graphics_state$km_time) || !graphics_state$km_time %in% numeric_vars) numeric_vars[1] else graphics_state$km_time
      updateSelectizeInput(session, "km_time", choices = numeric_vars, selected = current_time_choice)
    } else {
      updateSelectizeInput(session, "km_time", choices = numeric_vars, selected = NULL)
    }
    
    # 更新状态变量选择
    if(length(numeric_vars) > 0) {
      # 如果当前选择不在选项中，设置为第一个选项
      current_status_choice <- if(is.null(graphics_state$km_status) || !graphics_state$km_status %in% numeric_vars) numeric_vars[1] else graphics_state$km_status
      updateSelectizeInput(session, "km_status", choices = numeric_vars, selected = current_status_choice)
    } else {
      updateSelectizeInput(session, "km_status", choices = numeric_vars, selected = NULL)
    }
    
    # 更新分层变量选择
    strata_choices <- c("无" = "None", categorical_vars)
    updateSelectizeInput(session, "strata_var", choices = strata_choices)
    
    # 更新分面变量选择
    facet_choices <- c("无" = "None", categorical_vars)
    updateSelectizeInput(session, "facet_var", choices = facet_choices)
  })
  
  # 强制初始化默认值（在数据可用时立即设置状态）
  observeEvent(data(), {
    req(data())
    isolate({
      current_data <- data()
      if(!is.null(current_data) && nrow(current_data) > 0) {
        numeric_vars <- names(current_data)[sapply(current_data, is.numeric)]
        if(length(numeric_vars) >= 2) {
          # 只有在当前状态为NULL时才设置默认值
          if(is.null(graphics_state$km_time)) {
            graphics_state$km_time <- numeric_vars[1]
            # 立即尝试更新UI选择
            updateSelectizeInput(session, "km_time", selected = numeric_vars[1])
          }
          if(is.null(graphics_state$km_status)) {
            graphics_state$km_status <- numeric_vars[2]
            # 立即尝试更新UI选择
            updateSelectizeInput(session, "km_status", selected = numeric_vars[2])
          }
        } else if(length(numeric_vars) == 1) {
          # 如果只有一个数值变量，设置为时间变量
          if(is.null(graphics_state$km_time)) {
            graphics_state$km_time <- numeric_vars[1]
            # 立即尝试更新UI选择
            updateSelectizeInput(session, "km_time", selected = numeric_vars[1])
          }
        }
      }
    })
  })
  
  # 在会话开始时也尝试设置默认值
  observe({
    req(data())
    # 确保变量选择框已填充选项后设置默认选择
    current_data <- data()
    if(!is.null(current_data) && nrow(current_data) > 0 && is.null(input$km_time) && is.null(graphics_state$km_time)) {
      numeric_vars <- names(current_data)[sapply(current_data, is.numeric)]
      if(length(numeric_vars) >= 1) {
        updateSelectizeInput(session, "km_time", selected = numeric_vars[1])
        graphics_state$km_time <- numeric_vars[1]
      }
      if(length(numeric_vars) >= 2) {
        updateSelectizeInput(session, "km_status", selected = numeric_vars[2])
        graphics_state$km_status <- numeric_vars[2]
      }
    }
  })
  
  # 初始化时设置默认值
  observeEvent(data(), {
    req(data())
    isolate({
      current_data <- data()
      if(!is.null(current_data) && nrow(current_data) > 0) {
        numeric_vars <- names(current_data)[sapply(current_data, is.numeric)]
        if(length(numeric_vars) >= 2) {
          # 设置默认选择并更新状态
          if(is.null(graphics_state$km_time)) {
            graphics_state$km_time <- numeric_vars[1]
          }
          if(is.null(graphics_state$km_status)) {
            graphics_state$km_status <- numeric_vars[2]
          }
        } else if(length(numeric_vars) == 1) {
          # 如果只有一个数值变量，设置为时间变量
          if(is.null(graphics_state$km_time)) {
            graphics_state$km_time <- numeric_vars[1]
          }
        }
      }
    })
  }, once = TRUE)  # 只在数据首次可用时运行一次
  
  
  # 动态分面值选择器UI
  output$facet_value_ui <- renderUI({
    req(data(), input$facet_var)
    
    if (input$facet_var != "None" && input$facet_var %in% names(data())) {
      # 获取分面变量的唯一值
      facet_col <- data()[[input$facet_var]]
      facet_values <- unique(facet_col)
      facet_values <- facet_values[!is.na(facet_values)]
      
      # 转换为字符向量
      facet_values_char <- as.character(facet_values)
      # 过滤空值
      facet_values_char <- facet_values_char[facet_values_char != ""]
      
      # 创建选择列表，只包含实际的分面值（不包含"全部"）
      choices <- facet_values_char
      if (length(choices) > 0) {
        selectInput(ns("facet_value"), "分面值选择", choices = choices, selected = if(is.null(graphics_state$km_facet_values) || !graphics_state$km_facet_values %in% choices) choices[1] else graphics_state$km_facet_values)
      } else {
        selectInput(ns("facet_value"), "分面值选择", choices = NULL)
      }
    } else {
      NULL
    }
 })
  
  # 观察并保存图形参数
  observe({
    graphics_state$km_time <- input$km_time
    graphics_state$km_status <- input$km_status
    graphics_state$km_censor_value <- input$km_censor_value
    graphics_state$km_facet_values <- input$facet_value
    graphics_state$km_show_risktable <- input$km_show_risktable
    graphics_state$km_line_size <- input$line_size
    graphics_state$km_line_type <- input$line_type
    graphics_state$km_censor_size <- input$km_censor_size
    graphics_state$km_censor_shape <- input$km_censor_shape
    graphics_state$y_text_size <- input$y_text_size
    graphics_state$title_size <- input$title_size
    graphics_state$caption_size <- input$caption_size
    graphics_state$xlab_size <- input$xlab_size
    graphics_state$ylab_size <- input$ylab_size
  })
  
  # 获取过滤后的数据
  filtered_data <- reactive({
    req(data())
    data <- data()
    
    # 如果选择了分面变量，则过滤数据
    if (input$facet_var != "None" && input$facet_var %in% names(data) && !is.null(input$facet_value)) {
      # 确保分面值被选中
      facet_col <- data[[input$facet_var]]
      # 转换为字符进行比较
      filtered_data <- data[as.character(facet_col) == as.character(input$facet_value), ]
      return(filtered_data)
    }
    return(data)
  })
  
  
  # 动态时间范围滑块UI
  output$time_range_slider <- renderUI({
    req(input$km_time)
    data <- filtered_data()
    
    if (is.null(data) || nrow(data) == 0) {
      ns <- session$ns
      helpText("没有可用的数据")
    } else if (input$km_time %in% names(data)) {
      time_var <- data[[input$km_time]]
      
      if (!is.null(time_var) && is.numeric(time_var)) {
        # 移除NA值
        time_var <- time_var[!is.na(time_var)]
        
        if (length(time_var) > 0) {
          time_max <- max(time_var, na.rm = TRUE)
          time_range_max <- min(ceiling(time_max) + 50, 1000)  # 最大限制为1000
          
          ns <- session$ns
          sliderInput(
            ns("time_range"),
            paste("时间范围 (最大值:", time_range_max, ")"),
            min = 0,
            max = time_range_max,
            value = c(0, time_range_max)
          )
        } else {
          ns <- session$ns
          helpText("时间变量没有有效数据")
        }
      } else {
        ns <- session$ns
        helpText("请选择数值型时间变量")
      }
    } else {
      ns <- session$ns
      helpText("请选择时间变量")
    }
  })
  
  # 创建生存对象
  surv_obj <- reactive({
    req(input$km_time, input$km_status, filtered_data())
    
    data <- filtered_data()
    
    # 确保变量存在且数据不为空
    validate(
      need(input$km_time %in% names(data), "请选择有效的时间变量"),
      need(input$km_status %in% names(data), "请选择有效的状态变量"),
      need(nrow(data) > 0, "选择的分面值没有数据")
    )
    
    # 处理删失值定义
    time_var <- data[[input$km_time]]
    status_var <- data[[input$km_status]]
    
    # 根据删失值定义调整状态变量 (0=删失, 1=事件 vs 1=删失, 0=事件)
    if (input$km_censor_value == "1") {
      # 如果定义是1=删失, 0=事件，则需要翻转状态值
      status_var <- ifelse(status_var == 1, 0, ifelse(status_var == 0, 1, status_var))
    }
    
    # 检查状态变量是否只包含0和1
    unique_status <- unique(status_var)
    valid_status <- unique_status[!is.na(unique_status)]
    
    if (!all(valid_status %in% c(0, 1))) {
      # 如果状态变量包含其他值，将其转换为0和1
      # 将最小值设为0（删失），其余设为1（事件）
      min_status <- min(valid_status, na.rm = TRUE)
      status_var <- ifelse(status_var == min_status, 0, 1)
    }
    
    Surv(time_var, status_var)
  })
  
  # 拟合生存曲线
  fit <- reactive({
    req(surv_obj(), filtered_data())
    data <- filtered_data()
    
    # 检查是否有足够的数据进行拟合
    if (nrow(data) == 0) {
      stop("没有足够的数据进行生存分析")
    }
    
    # 检查生存对象是否有效
    if (any(is.na(surv_obj()))) {
      stop("生存对象包含无效值")
    }
    
    if (input$strata_var == "None") {
      # 无分层
      surv_fit(surv_obj() ~ 1, data = data)
    } else {
      # 有分层
      validate(
        need(input$strata_var %in% names(data), "请选择有效的分层变量"),
        need(nrow(data) > 0, "选择的分面值没有数据")
      )
      formula_str <- paste("surv_obj() ~", input$strata_var)
      surv_fit(as.formula(formula_str), data = data)
    }
  })
  
  # 创建生存曲线图
  create_surv_plot <- function() {
    req(fit(), filtered_data())
    data <- filtered_data()
    
    # 使用滑块控制的时间范围
    time_range <- if (!is.null(input$time_range)) {
      input$time_range
    } else {
      # 如果没有滑块，使用基于时间变量的最大值+50
      time_var_name <- input$km_time
      time_max <- max(data[[time_var_name]], na.rm = TRUE)
      time_range_max <- min(ceiling(time_max) + 50, 1000)  # 限制最大值为1000
      c(0, time_range_max)
    }
    
    # 创建生存曲线图
    p <- ggsurvplot(
      fit(),
      data = data,
      risk.table = input$km_show_risktable,
      conf.int = input$show_ci,
      pval = TRUE,
      censor = input$km_show_censor,
      censor.size = input$km_censor_size,
      censor.shape = as.numeric(input$km_censor_shape),
      xlim = time_range,
      break.time.by = round((time_range[2] - time_range[1]) / 10),
      ggtheme = theme_bw(),
      palette = input$plot_palette,
      legend = "top",  # 显示图例在顶部
      legend.title = "Strata",  # 设置图例标题
      legend.labs = if (!is.null(fit()$strata)) {
        # 如果有分层变量，使用分层变量名作为图例标签
        levels(as.factor(fit()$strata))
      } else {
        # 如果没有分层变量，不显示图例
        NULL
      }
    )
    
    # 应用线条样式
    if (!is.null(input$line_size) && !is.null(input$line_type)) {
      p$plot <- p$plot +
        update_geom_defaults("step", list(size = input$line_size, linetype = input$line_type))
    }
    
    # 应用高级美学设置（标题、脚注和标签）
    # 处理标题换行
    if (!is.null(input$plot_title) && input$plot_title != "") {
      # 将\n替换为实际换行符
      formatted_title <- gsub("\\\\n", "\n", input$plot_title)
      p$plot <- p$plot + labs(title = formatted_title)
    }
    
    # 处理脚注 - 放在图形底部左对齐
    if (!is.null(input$plot_caption) && input$plot_caption != "") {
      # 将\n替换为实际换行符
      formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
      p$plot <- p$plot + labs(caption = formatted_caption)
      
      # 设置脚注样式：左对齐，调整位置
      p$plot <- p$plot + theme(
        plot.caption = element_text(hjust = 0, vjust = 1, size = 10),  # 左对齐
        plot.caption.position = "plot"  # 脚注在整个图形底部
      )
    }
    
    if (!is.null(input$plot_xlab) && input$plot_xlab != "") {
      # 处理X轴标签换行
      formatted_xlab <- gsub("\\\\n", "\n", input$plot_xlab)
      p$plot <- p$plot + labs(x = formatted_xlab)
    } else {
      p$plot <- p$plot + labs(x = input$km_time)
    }
    if (!is.null(input$plot_ylab) && input$plot_ylab != "") {
      # 处理Y轴标签换行
      formatted_ylab <- gsub("\\\\n", "\n", input$plot_ylab)
      p$plot <- p$plot + labs(y = formatted_ylab)
    } else {
      p$plot <- p$plot + labs(y = "生存概率")
    }
    
    # 如果需要显示风险表，组合图形
    if (input$km_show_risktable && !is.null(p$table)) {
      # 设置风险表主题
      p$table <- p$table +
        theme_minimal() +
        theme(
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          plot.margin = margin(0, 0, 0, 0, "pt")
        )
      
      # 设置Y轴文本大小
      p$table <- p$table +
        theme(axis.text.y = element_text(size = input$y_text_size))
      
      # 使用cowplot包组合图形，确保脚注位置正确
      combined_plot <- plot_grid(
        p$plot,
        p$table,
        ncol = 1,
        align = "v",
        axis = "lr",
        rel_heights = c(2, 0.5)
      )
      
      # 添加额外的主题设置确保脚注位置
      combined_plot + theme(
        plot.caption = element_text(hjust = 0, vjust = 1, size = 10),
        plot.caption.position = "plot"
      )
    } else {
      # 如果不显示风险表，只返回生存曲线图
      # 确保脚注位置正确
      p$plot + theme(
        plot.caption = element_text(hjust = 0, vjust = 1, size = 10),
        plot.caption.position = "plot"
      )
    }
  }
  
  # 生成生存曲线图
  output$survPlot <- renderPlot({
    input$render_km_plot  # 依赖于render_km_plot按钮
    req(fit())
    create_surv_plot()
  }, height = 600)
  
  # 交互式生存曲线图
  output$interactiveSurvPlot <- renderPlotly({
    input$render_km_plot  # 依赖于render_km_plot按钮
    req(fit(), filtered_data())
    data <- filtered_data()
    
    # 创建基础生存曲线图
    time_range <- if (!is.null(input$time_range)) {
      input$time_range
    } else {
      time_var_name <- input$km_time
      time_max <- max(data[[time_var_name]], na.rm = TRUE)
      time_range_max <- min(ceiling(time_max) + 50, 1000)
      c(0, time_range_max)
    }
    
    p <- ggsurvplot(
      fit(),
      data = data,
      conf.int = input$show_ci,
      pval = TRUE,
      censor = input$km_show_censor,
      censor.size = input$km_censor_size,
      censor.shape = as.numeric(input$km_censor_shape),
      xlim = time_range,
      break.time.by = round((time_range[2] - time_range[1]) / 10),
      ggtheme = theme_bw(),
      palette = input$plot_palette,
      legend = "top",  # 显示图例在顶部
      legend.title = "Strata",  # 设置图例标题
      legend.labs = if (!is.null(fit()$strata)) {
        # 如果有分层变量，使用分层变量名作为图例标签
        levels(as.factor(fit()$strata))
      } else {
        # 如果没有分层变量，不显示图例
        NULL
      }
    )$plot
    
    # 应用线条样式
    if (!is.null(input$line_size) && !is.null(input$line_type)) {
      p <- p +
        update_geom_defaults("step", list(size = input$line_size, linetype = input$line_type))
    }
    
    # 应用高级美学设置
    # 处理标题换行
    if (!is.null(input$plot_title) && input$plot_title != "") {
      # 将\n替换为实际换行符
      formatted_title <- gsub("\\\\n", "\n", input$plot_title)
      p <- p + labs(title = formatted_title)
    } else if (input$facet_var != "None" && !is.null(input$facet_value)) {
      p <- p + labs(title = paste("交互式生存分析曲线 -", input$facet_var, "=", input$facet_value))
    } else {
      p <- p + labs(title = "交互式生存分析曲线")
    }
    
    # 处理脚注 - 放在图形底部左对齐
    if (!is.null(input$plot_caption) && input$plot_caption != "") {
      # 将\n替换为实际换行符
      formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
      p <- p + labs(caption = formatted_caption)
      
      # 设置脚注样式：左对齐
      p <- p + theme(
        plot.caption = element_text(hjust = 0, vjust = 1, size = 10)  # 左对齐
      )
    }
    
    # 处理X轴标签换行
    if (!is.null(input$plot_xlab) && input$plot_xlab != "") {
      formatted_xlab <- gsub("\\\\n", "\n", input$plot_xlab)
      p <- p + labs(x = formatted_xlab)
    } else {
      p <- p + labs(x = input$km_time)
    }
    
    # 处理Y轴标签换行
    if (!is.null(input$plot_ylab) && input$plot_ylab != "") {
      formatted_ylab <- gsub("\\\\n", "\n", input$plot_ylab)
      p <- p + labs(y = formatted_ylab)
    } else {
      p <- p + labs(y = "生存概率")
    }
    
    # 转换为plotly交互式图形
    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(height = 600)
  })
  
  # 生存分析数据表
  output$km_data_table <- renderDT({
    req(fit())
    
    # 获取生存分析结果数据
    tryCatch({
      surv_summary <- summary(fit(), censored = TRUE)
      
      # 创建生存分析结果表格
      if (!is.null(surv_summary$time)) {
        # 提取生存分析结果
        time_points <- surv_summary$time
        n_risk <- surv_summary$n.risk
        n_event <- surv_summary$n.event
        n_censor <- surv_summary$n.censor
        surv_prob <- surv_summary$surv
        lower_ci <- surv_summary$lower
        upper_ci <- surv_summary$upper
        
        # 创建结果数据框
        surv_df <- data.frame(
          时间 = time_points,
          "风险人数" = n_risk,
          "事件数" = n_event,
          "删失数" = n_censor,
          "生存概率" = round(surv_prob, 4),
          "置信区间下限" = round(lower_ci, 4),
          "置信区间上限" = round(upper_ci, 4)
        )
        
        # 为表格添加格式
        DT::datatable(surv_df, options = list(
          pageLength = 10,
          scrollX = TRUE,
          columnDefs = list(
            list(className = 'dt-center', targets = 0:6)
          )
        )) %>%
          formatRound(columns = c("生存概率", "置信区间下限", "置信区间上限"), digits = 4)
      } else {
        # 如果无法获取生存分析结果，显示提示信息
        data.frame(错误 = "无法生成生存分析数据表", 信息 = "请检查输入数据")
      }
    }, error = function(e) {
      # 如果出现错误，返回错误信息
      data.frame(错误 = "生成数据表时出错", 信息 = e$message)
    })
  })
  
  # 下载静态图
  output$download_plot <- downloadHandler(
    filename = function() {
      paste("survival_plot_", Sys.Date(), ".", input$export_format, sep = "")
    },
    content = function(file) {
      plot_format <- input$export_format
      if (plot_format == "pdf") {
        ggsave(file, plot = create_surv_plot(), width = 10, height = 8, device = "pdf",
               bg = "white", dpi = 300)
      } else if (plot_format == "svg") {
        ggsave(file, plot = create_surv_plot(), width = 10, height = 8, device = "svg",
               bg = "white")
      } else {  # png
        ggsave(file, plot = create_surv_plot(), width = 10, height = 8, device = "png",
               bg = "white", dpi = 300)
      }
    }
  )
  
  # 返回模块状态
  return(reactive({
    list(
      time_var = input$km_time,
      status_var = input$km_status,
      strata_var = input$strata_var,
      facet_var = input$facet_var,
      facet_value = input$facet_value
    )
  }))
}
