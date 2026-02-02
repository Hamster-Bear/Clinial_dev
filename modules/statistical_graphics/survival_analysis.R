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
        status = "primary",
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
          ),
          column(2,
                 checkboxInput(ns("show_grid"), "显示网格线", value = FALSE)
          )
        ),
        fluidRow(
          column(4,
                 checkboxInput(ns("show_median"), "显示中位生存时间", value = TRUE)
          ),
          column(4,
                 checkboxInput(ns("show_stats"), "显示统计量(P值/HR)", value = TRUE)
          ),
          column(4,
                 selectInput(ns("legend_position"), "图例位置",
                             choices = c("top-right", "top", "top-left", "left", "right", "bottom-left", "bottom", "bottom-right", "none"),
                             selected = "top-right")
          )
        ),
        fluidRow(
          column(12,
                 textInput(ns("legend_title"), "图例标题", value = "", placeholder = "留空则使用变量名")
          )
        ),
        conditionalPanel(
          condition = paste0("input['", ns("strata_var"), "'] != 'None'"),
          fluidRow(
            column(12,
              box(
                width = 12,
                title = "分层变量标签映射",
                status = "warning",
                collapsible = TRUE,
                collapsed = TRUE,
                uiOutput(ns("strata_labels_ui"))
              )
            )
          )
        ),
        fluidRow(
          column(12,
                 h5("文本位置设置"),
                 selectInput(ns("text_position_preset"), "预设位置",
                             choices = c("自动（默认）" = "auto",
                                         "左上" = "top-left",
                                         "右上" = "top-right",
                                         "左下" = "bottom-left",
                                         "右下" = "bottom-right",
                                         "自定义" = "custom"),
                             selected = "auto")
          )
        ),
        conditionalPanel(
          condition = paste0("input['", ns("text_position_preset"), "'] == 'custom'"),
          fluidRow(
            column(3, numericInput(ns("median_x"), "中位生存X坐标", value = 0.98, min = 0, max = 1, step = 0.01)),
            column(3, numericInput(ns("median_y"), "中位生存Y坐标", value = 0.95, min = 0, max = 1, step = 0.01)),
            column(3, numericInput(ns("stats_x"), "统计量X坐标", value = 0.02, min = 0, max = 1, step = 0.01)),
            column(3, numericInput(ns("stats_y"), "统计量Y坐标", value = 0.95, min = 0, max = 1, step = 0.01))
          )
        ),
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
              conditionalPanel(
                condition = paste0("input['", ns("strata_var"), "'] != 'None'"),
                uiOutput(ns("hr_reference_ui"))
              ),
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
              # 时间范围滑块
              uiOutput(ns("time_range_slider")),
              # 时间轴步长设置
              numericInput(ns("time_step"), "时间轴步长", value = NULL, min = 1, max = 1000, step = 1),
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
      ),
      tags$script(HTML('
        $(document).ready(function() {
          // 使用事件委托，禁用所有当前和未来出现的select和.selectize-input的鼠标滚轮事件
          $(document).on("mousewheel DOMMouseScroll", "select, .selectize-input", function(e) {
            e.preventDefault();
            e.stopPropagation();
          });
        });
      '))
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
    ylab_size = 12,
    show_grid = FALSE,
    time_step = NULL,
    show_median = TRUE,
    show_stats = TRUE,
    legend_position = "top-right",
    legend_title = "",
    text_position_preset = "auto",
    median_x = 0.98,
    median_y = 0.95,
    stats_x = 0.02,
    stats_y = 0.95,
    hr_reference = NULL,
    strata_labels = list()
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
  
  # 动态HR参考组选择UI
  output$hr_reference_ui <- renderUI({
    req(data(), input$strata_var)
    
    if (input$strata_var != "None" && input$strata_var %in% names(data())) {
      # 获取分层变量的唯一值
      strata_col <- data()[[input$strata_var]]
      strata_values <- unique(strata_col)
      strata_values <- strata_values[!is.na(strata_values)]
      
      # 转换为字符向量
      strata_values_char <- as.character(strata_values)
      # 过滤空值
      strata_values_char <- strata_values_char[strata_values_char != ""]
      
      if (length(strata_values_char) > 1) {
        selectInput(
          ns("hr_reference"),
          "HR参考组（与其他组比较）",
          choices = c("无（自动选择第一组）" = "auto", strata_values_char),
          selected = if(is.null(graphics_state$hr_reference) || !graphics_state$hr_reference %in% c("auto", strata_values_char)) "auto" else graphics_state$hr_reference
        )
      } else {
        NULL
      }
    } else {
      NULL
    }
  })
  
  # 动态分层变量标签映射UI
  output$strata_labels_ui <- renderUI({
    req(data(), input$strata_var)
    
    if (input$strata_var != "None" && input$strata_var %in% names(data())) {
      # 获取分层变量的唯一值
      strata_col <- data()[[input$strata_var]]
      strata_values <- unique(strata_col)
      strata_values <- strata_values[!is.na(strata_values)]
      
      # 转换为字符向量
      strata_values_char <- as.character(strata_values)
      # 过滤空值
      strata_values_char <- strata_values_char[strata_values_char != ""]
      
      if (length(strata_values_char) > 0) {
        # 为每个值创建一个文本输入框
        tagList(
          h5("为每个分层值设置自定义标签"),
          p("留空则使用原始值"),
          lapply(strata_values_char, function(val) {
            textInput(ns(paste0("strata_label_", val)),
                     label = paste("值:", val),
                     value = "",
                     placeholder = val)
          })
        )
      } else {
        p("没有可用的分层值")
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
    graphics_state$show_grid <- input$show_grid
    graphics_state$time_step <- input$time_step
    graphics_state$show_median <- input$show_median
    graphics_state$show_stats <- input$show_stats
    graphics_state$legend_position <- input$legend_position
    graphics_state$legend_title <- input$legend_title
    graphics_state$text_position_preset <- input$text_position_preset
    graphics_state$median_x <- input$median_x
    graphics_state$median_y <- input$median_y
    graphics_state$stats_x <- input$stats_x
    graphics_state$stats_y <- input$stats_y
    graphics_state$hr_reference <- input$hr_reference
    
    # 收集分层变量标签映射
    if (!is.null(input$strata_var) && input$strata_var != "None") {
      req(data())
      strata_col <- data()[[input$strata_var]]
      strata_values <- unique(strata_col)
      strata_values <- strata_values[!is.na(strata_values)]
      strata_values_char <- as.character(strata_values)
      strata_values_char <- strata_values_char[strata_values_char != ""]
      
      label_list <- list()
      for (val in strata_values_char) {
        input_name <- paste0("strata_label_", val)
        if (!is.null(input[[input_name]])) {
          label_list[[val]] <- input[[input_name]]
        }
      }
      graphics_state$strata_labels <- label_list
    } else {
      graphics_state$strata_labels <- list()
    }
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
      helpText("没有可用的数据")
    } else if (input$km_time %in% names(data)) {
      time_var <- data[[input$km_time]]
      
      if (!is.null(time_var) && is.numeric(time_var)) {
        # 移除NA值
        time_var <- time_var[!is.na(time_var)]
        
        if (length(time_var) > 0) {
          time_max <- max(time_var, na.rm = TRUE)
          time_range_max <- time_max + 30  # 最大值 = 实际最大值 + 30
          
          # 生成滑块并添加禁用鼠标滚轮的脚本
          tagList(
            sliderInput(
              ns("time_range"),
              paste("时间范围 (最大值:", round(time_max, 2), ")"),
              min = 0,
              max = time_range_max,
              value = c(0, time_range_max)
            ),
            tags$script(HTML(sprintf("
              $(document).ready(function() {
                // 禁用滑块区域的鼠标滚轮事件
                $('#%s').on('mousewheel DOMMouseScroll', function(e) {
                  e.preventDefault();
                  e.stopPropagation();
                });
                
                // 同时禁用滑块内部input元素的滚轮事件
                $('#%s').closest('.shiny-input-container').find('input').on('mousewheel DOMMouseScroll', function(e) {
                  e.preventDefault();
                  e.stopPropagation();
                });
              });
            ", ns("time_range"), ns("time_range"))))
          )
        } else {
          helpText("时间变量没有有效数据")
        }
      } else {
        helpText("请选择数值型时间变量")
      }
    } else {
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
  
  # 获取标签映射后的分层变量值
  mapped_strata <- reactive({
    req(data(), input$strata_var)
    if (input$strata_var == "None") return(NULL)
    
    strata_col <- data()[[input$strata_var]]
    strata_values <- as.character(strata_col)
    
    # 应用标签映射
    labels <- graphics_state$strata_labels
    if (length(labels) > 0) {
      for (orig in names(labels)) {
        if (labels[[orig]] != "") {
          strata_values[strata_values == orig] <- labels[[orig]]
        }
      }
    }
    return(strata_values)
  })
  
  # 创建生存曲线图
  create_surv_plot <- function() {
    req(fit(), filtered_data())
    data <- filtered_data()
    
    # 时间范围设置
    time_range <- if (!is.null(input$time_range)) {
      input$time_range
    } else {
      time_var_name <- input$km_time
      time_max <- max(data[[time_var_name]], na.rm = TRUE)
      time_range_max <- time_max + 30  # 最大值 = 实际最大值 + 30
      c(0, time_range_max)
    }
    
    # 计算时间步长 - 使用自定义步长或自动计算
    time_step <- if (!is.null(input$time_step) && !is.na(input$time_step) && input$time_step > 0) {
      input$time_step
    } else {
      round((time_range[2] - time_range[1]) / 10)
    }
    
    # 如果有标签映射，创建一个使用映射标签的副本数据
    plot_data <- data
    if (input$strata_var != "None" && length(graphics_state$strata_labels) > 0) {
      # 复制数据以避免修改原始数据
      plot_data <- data
      strata_col <- plot_data[[input$strata_var]]
      strata_values <- as.character(strata_col)
      labels <- graphics_state$strata_labels
      for (orig in names(labels)) {
        if (labels[[orig]] != "") {
          strata_values[strata_values == orig] <- labels[[orig]]
        }
      }
      plot_data[[input$strata_var]] <- factor(strata_values, levels = unique(strata_values))
    }
    
    # 使用映射后的数据重新拟合生存曲线
    if (input$strata_var != "None" && length(graphics_state$strata_labels) > 0) {
      # 重新创建生存对象
      time_var <- plot_data[[input$km_time]]
      status_var <- plot_data[[input$km_status]]
      if (input$km_censor_value == "1") {
        status_var <- ifelse(status_var == 1, 0, ifelse(status_var == 0, 1, status_var))
      }
      unique_status <- unique(status_var)
      valid_status <- unique_status[!is.na(unique_status)]
      if (!all(valid_status %in% c(0, 1))) {
        min_status <- min(valid_status, na.rm = TRUE)
        status_var <- ifelse(status_var == min_status, 0, 1)
      }
      surv_obj_local <- Surv(time_var, status_var)
      
      # 重新拟合
      if (input$strata_var == "None") {
        fit_local <- surv_fit(surv_obj_local ~ 1, data = plot_data)
      } else {
        formula_str <- paste("surv_obj_local ~", input$strata_var)
        fit_local <- surv_fit(as.formula(formula_str), data = plot_data)
      }
    } else {
      # 使用原始拟合
      fit_local <- fit()
      plot_data <- data
    }
    
    # 计算图例标题文本
    legend_title_text <- ifelse(input$legend_title != "", input$legend_title,
                               ifelse(input$strata_var != "None", input$strata_var, ""))
    # 如果图例标题为空字符串，设置为NULL，避免产生空标签
    if (legend_title_text == "") {
      legend_title_text <- NULL
    }
    
    # 创建生存曲线图 - 启用默认图例，禁用默认置信区间和删失点
    p <- suppressWarnings(ggsurvplot(
      fit_local,
      data = plot_data,
      risk.table = input$km_show_risktable,
      conf.int = FALSE,  # 关键：禁用默认置信区间
      pval = FALSE,
      censor = FALSE,  # 关键：禁用默认删失点
      xlim = time_range,
      break.time.by = time_step,  # 使用自定义时间步长
      ggtheme = theme_bw(),
      palette = "Set1",
      surv.alpha = 1,  # 设置生存曲线透明度为1，避免alpha警告
      legend.title = legend_title_text,
      legend.labs = NULL  # 使用默认标签，避免产生未知标签
    ))
    
    # 计算并标注中位生存时间
    if (input$show_median) {
      median_surv <- surv_median(fit_local)
      if (!is.null(median_surv) && nrow(median_surv) > 0) {
        # 直接使用fit_local的strata作为标签（已经过映射处理）
        median_surv$label <- paste0(median_surv$strata, ": ",
                                    round(median_surv$median, 2),
                                    " (95%CI: ",
                                    round(median_surv$lower, 2), "-",
                                    round(median_surv$upper, 2), ")")
        
        # 确定标注位置
        # 1. 根据预设位置或自定义坐标计算x,y
        preset <- input$text_position_preset
        n_groups <- nrow(median_surv)
        
        # 定义预设位置映射
        if (preset == "auto") {
          # 自动布局：右侧垂直排列，从0.95开始向下，根据分组数量动态调整行距
          x_pos <- max(time_range) * 0.98
          # 动态行距：根据分组数量压缩，最少留0.1的间距，最多到0.6
          start_y <- 0.95
          end_y <- max(0.6, 0.95 - (n_groups-1)*0.1)
          y_positions <- seq(start_y, end_y, length.out = n_groups)
        } else if (preset == "top-left") {
          x_pos <- min(time_range) + 0.02 * diff(time_range)
          start_y <- 0.95
          end_y <- max(0.6, 0.95 - (n_groups-1)*0.1)
          y_positions <- seq(start_y, end_y, length.out = n_groups)
        } else if (preset == "top-right") {
          x_pos <- max(time_range) * 0.98
          start_y <- 0.95
          end_y <- max(0.6, 0.95 - (n_groups-1)*0.1)
          y_positions <- seq(start_y, end_y, length.out = n_groups)
        } else if (preset == "bottom-left") {
          x_pos <- min(time_range) + 0.02 * diff(time_range)
          start_y <- 0.4
          end_y <- max(0.05, 0.4 - (n_groups-1)*0.1)
          y_positions <- seq(start_y, end_y, length.out = n_groups)
        } else if (preset == "bottom-right") {
          x_pos <- max(time_range) * 0.98
          start_y <- 0.4
          end_y <- max(0.05, 0.4 - (n_groups-1)*0.1)
          y_positions <- seq(start_y, end_y, length.out = n_groups)
        } else if (preset == "custom") {
          # 使用自定义坐标（比例坐标转换为实际坐标）
          # input$median_x是比例（0-1），需要转换为实际x坐标
          x_pos <- min(time_range) + input$median_x * diff(time_range)
          # input$median_y是比例（0-1），需要转换为实际y坐标（生存概率范围0-1）
          # 但注意：图形的y轴范围是0-1，所以可以直接使用
          base_y <- input$median_y
          # 根据分组数量动态分配y位置，从base_y向下排列，行距0.05
          y_positions <- base_y - seq(0, n_groups-1) * 0.05
        }
        
        median_surv$x <- x_pos
        median_surv$y <- y_positions
        # 添加标注到图形
        p$plot <- p$plot +
          geom_text(data = median_surv,
                    aes(x = x, y = y, label = label),
                    hjust = ifelse(preset %in% c("top-left", "bottom-left"), 0, 1),
                    vjust = 0.5, size = 3.5,
                    color = "black", fontface = "bold")
      }
    }
    
    # 计算并显示统计量（P值/HR）
    if (input$show_stats) {
      # 计算log-rank检验P值
      logrank_p <- tryCatch({
        survdiff_obj <- survdiff(surv_obj() ~ data[[input$strata_var]], data = data)
        pchisq(survdiff_obj$chisq, length(survdiff_obj$n) - 1, lower.tail = FALSE)
      }, error = function(e) NA)
      
      # 准备统计量文本
      stats_text <- ""
      if (!is.na(logrank_p)) {
        stats_text <- paste0(stats_text, "Log-rank P = ", formatC(logrank_p, format = "f", digits = 3))
      }
      
      # 如果存在分层变量，计算Cox回归HR（支持多分类和参考组选择）
      if (input$strata_var != "None") {
        strata_var <- data[[input$strata_var]]
        strata_levels <- unique(strata_var)
        n_levels <- length(strata_levels)
        
        # 确定参考组
        reference <- input$hr_reference
        if (is.null(reference) || reference == "auto") {
          # 自动选择第一组作为参考
          reference_level <- as.character(strata_levels[1])
        } else {
          reference_level <- reference
        }
        
        # 重新编码因子变量，将参考组设为基线
        strata_fac <- factor(strata_var)
        if (reference_level %in% levels(strata_fac)) {
          strata_fac <- relevel(strata_fac, ref = reference_level)
        }
        
        # 拟合Cox模型
        cox_fit <- tryCatch({
          coxph(surv_obj() ~ strata_fac, data = data)
        }, error = function(e) NULL)
        
        if (!is.null(cox_fit)) {
          cox_summary <- summary(cox_fit)
          n_coef <- nrow(cox_summary$coefficients)
          
          if (n_coef > 0) {
            # 构建HR表格文本（新格式：组别vs参考组 HR=值 (95%CI: 下限-上限)）
            hr_lines <- c()
            # 标签映射
            labels <- graphics_state$strata_labels
            map_label <- function(x) {
              # 如果x在labels中有直接映射，则使用
              if (x %in% names(labels) && labels[[x]] != "") {
                return(labels[[x]])
              }
              # 否则，尝试提取等号后面的部分
              if (grepl("=", x)) {
                extracted <- sub(".*=", "", x)
                if (extracted %in% names(labels) && labels[[extracted]] != "") {
                  return(labels[[extracted]])
                }
              }
              # 如果都没有，返回原始x
              return(x)
            }
            for (i in 1:n_coef) {
              hr <- exp(cox_summary$coefficients[i, 1])
              hr_lower <- exp(cox_summary$coefficients[i, 1] - 1.96 * cox_summary$coefficients[i, 3])
              hr_upper <- exp(cox_summary$coefficients[i, 1] + 1.96 * cox_summary$coefficients[i, 3])
              # 获取对比组名称（去掉因子前缀）
              contrast_name <- rownames(cox_summary$coefficients)[i]
              # 移除因子变量名前缀（例如"strata_fac"）
              contrast_clean <- gsub("^.*?([^.]+)$", "\\1", contrast_name)  # 简单提取最后一个单词
              # 如果前缀存在，尝试移除
              if (grepl("strata_fac", contrast_name)) {
                contrast_clean <- gsub("strata_fac", "", contrast_name)
              }
              # 应用标签映射
              contrast_mapped <- map_label(contrast_clean)
              reference_mapped <- map_label(reference_level)
              # 构建新格式
              hr_line <- paste0(contrast_mapped, " vs ", reference_mapped,
                                " HR = ", formatC(hr, format = "f", digits = 2),
                                " (95%CI: ", formatC(hr_lower, format = "f", digits = 2), "-",
                                formatC(hr_upper, format = "f", digits = 2), ")")
              hr_lines <- c(hr_lines, hr_line)
            }
            
            # 如果有HR结果，添加到统计量文本（每行单独一行，去掉Cox P值和标题）
            if (length(hr_lines) > 0) {
              # 如果已有log-rank P值，先加换行
              if (stats_text != "") {
                stats_text <- paste0(stats_text, "\n")
              }
              # 将HR行连接起来，每行用换行分隔
              stats_text <- paste0(stats_text, paste(hr_lines, collapse = "\n"))
            }
          }
        }
      }
      
      # 确定统计量文本位置
      preset <- input$text_position_preset
      if (preset == "auto") {
        # 默认左上角
        stats_x <- min(time_range) + 0.02 * diff(time_range)
        stats_y <- 0.95
        hjust_val <- 0
        vjust_val <- 1
      } else if (preset == "top-left") {
        stats_x <- min(time_range) + 0.02 * diff(time_range)
        stats_y <- 0.95
        hjust_val <- 0
        vjust_val <- 1
      } else if (preset == "top-right") {
        stats_x <- max(time_range) * 0.98
        stats_y <- 0.95
        hjust_val <- 1
        vjust_val <- 1
      } else if (preset == "bottom-left") {
        stats_x <- min(time_range) + 0.02 * diff(time_range)
        stats_y <- 0.05
        hjust_val <- 0
        vjust_val <- 0
      } else if (preset == "bottom-right") {
        stats_x <- max(time_range) * 0.98
        stats_y <- 0.05
        hjust_val <- 1
        vjust_val <- 0
      } else if (preset == "custom") {
        # 使用自定义坐标
        stats_x <- min(time_range) + input$stats_x * diff(time_range)
        stats_y <- input$stats_y
        hjust_val <- ifelse(input$stats_x < 0.5, 0, 1)
        vjust_val <- ifelse(input$stats_y < 0.5, 0, 1)
      }
      
      # 将统计量文本添加到图形
      if (stats_text != "") {
        p$plot <- p$plot +
          annotate("text", x = stats_x, y = stats_y, label = stats_text,
                   hjust = hjust_val, vjust = vjust_val, size = 3.5,
                   color = "black", fontface = "bold")
      }
    }
    
    # 手动添加删失点，并生成单独的图例
    if (input$km_show_censor) {
      # 获取生存数据
      surv_data <- surv_summary(fit())
      
      # 只选择删失点
      censored_points <- surv_data[surv_data$n.censor > 0, ]
      
      if (nrow(censored_points) > 0) {
        # 手动添加删失点，使用固定颜色和形状，但显示图例
        p$plot <- p$plot +
          geom_point(
            data = censored_points,
            aes(x = time, y = surv, shape = "删失"),
            size = input$km_censor_size,
            color = "black",  # 固定颜色，不映射
            alpha = 1         # 固定透明度
          ) +
          scale_shape_manual(
            name = "",
            values = c("删失" = as.numeric(input$km_censor_shape))
          )
      }
    }
    
    
    # 修复图例和透明度警告
    # 注意：图例标题已经在ggsurvplot中通过legend.title设置，这里无需重复设置
    # 确保形状图例正确，并移除alpha图例
    p$plot <- p$plot +
      guides(
        shape = guide_legend(title = ""),
        alpha = "none"
      )
    
    # 移除任何可能存在的alpha美学映射
    if ("alpha" %in% names(p$plot$layers)) {
      p$plot$layers <- lapply(p$plot$layers, function(layer) {
        if ("alpha" %in% names(layer$aes_params)) {
          layer$aes_params$alpha <- NULL
        }
        layer
      })
    }
    
    # 应用线条样式
    p$plot <- p$plot +
      update_geom_defaults("step", list(size = input$line_size, linetype = input$line_type))
    
    # 添加网格线控制
    if (!input$show_grid) {
      p$plot <- p$plot +
        theme(panel.grid.major = element_blank(),
              panel.grid.minor = element_blank())
    }

    # 设置图例位置
    if (input$legend_position == "none") {
      p$plot <- p$plot + theme(legend.position = "none")
    } else if (input$legend_position %in% c("top", "bottom", "left", "right")) {
      p$plot <- p$plot + theme(legend.position = input$legend_position)
    } else {
      # 处理角落位置
      pos_map <- list(
        "top-left"     = c(0, 1),
        "top-right"    = c(1, 1),
        "bottom-left"  = c(0, 0),
        "bottom-right" = c(1, 0)
      )
      pos <- pos_map[[input$legend_position]]
      if (!is.null(pos)) {
        p$plot <- p$plot +
          theme(legend.position = pos, legend.justification = pos)
      }
    }

    # 其余的美学设置（标题、标签等）保持不变...
    # 处理标题
    if (!is.null(input$plot_title) && input$plot_title != "") {
      formatted_title <- gsub("\\\\n", "\n", input$plot_title)
      p$plot <- p$plot + labs(title = formatted_title)
    }
    
    # 脚注处理将在组合图形时进行
    
    # 处理坐标轴标签
    if (!is.null(input$plot_xlab) && input$plot_xlab != "") {
      formatted_xlab <- gsub("\\\\n", "\n", input$plot_xlab)
      p$plot <- p$plot + labs(x = formatted_xlab)
    } else {
      p$plot <- p$plot + labs(x = input$km_time)
    }
    
    if (!is.null(input$plot_ylab) && input$plot_ylab != "") {
      formatted_ylab <- gsub("\\\\n", "\n", input$plot_ylab)
      p$plot <- p$plot + labs(y = formatted_ylab)
    } else {
      p$plot <- p$plot + labs(y = "生存概率")
    }
    


    # 组合图形（风险表处理）
    if (input$km_show_risktable && !is.null(p$table)) {
      p$table <- p$table +
        theme_minimal() +
        theme(
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          plot.margin = margin(0, 0, 0, 0, "pt"),
          axis.text.y = element_text(size = input$y_text_size)
        )
      
      # 创建图形列表
      plot_list <- list(p$plot, p$table)
      
      # 如果有脚注，创建脚注文本并添加到图形列表最后
      if (!is.null(input$plot_caption) && input$plot_caption != "") {
        formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
        caption_plot <- ggplot() +
          theme_void() +
          labs(caption = formatted_caption) +
          theme(plot.caption = element_text(hjust = 0, vjust = 0, size = input$caption_size))
        
        plot_list <- c(plot_list, list(caption_plot))
        rel_heights <- c(2, 0.5, 0.2)
      } else {
        rel_heights <- c(2, 0.5)
      }
      
      # 组合图形
      combined_plot <- plot_grid(
        plotlist = plot_list,
        ncol = 1,
        align = "v",
        axis = "lr",
        rel_heights = rel_heights
      )
      
      combined_plot
    } else {
      # 不显示风险表的情况
      if (!is.null(input$plot_caption) && input$plot_caption != "") {
        formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
        p$plot <- p$plot + labs(caption = formatted_caption) +
          theme(plot.caption = element_text(hjust = 0, vjust = 1, size = input$caption_size))
      }
      p$plot
    }
  }
  
  # 生成生存曲线图
  output$survPlot <- renderPlot({
    input$render_km_plot  # 依赖于render_km_plot按钮
    req(fit())
    create_surv_plot()
  }, height = 600)
  
  # 创建专门的交互式生存曲线图（避免转换警告）
  create_interactive_surv_plot <- function() {
    req(fit(), filtered_data())
    data <- filtered_data()
    
    # 时间范围设置
    time_range <- if (!is.null(input$time_range)) {
      input$time_range
    } else {
      time_var_name <- input$km_time
      time_max <- max(data[[time_var_name]], na.rm = TRUE)
      time_range_max <- time_max + 30  # 最大值 = 实际最大值 + 30
      c(0, time_range_max)
    }
    
    # 计算时间步长 - 使用自定义步长或自动计算
    time_step <- if (!is.null(input$time_step) && !is.na(input$time_step) && input$time_step > 0) {
      input$time_step
    } else {
      round((time_range[2] - time_range[1]) / 10)
    }
    
    # 计算图例标题文本
    legend_title_text <- ifelse(input$legend_title != "", input$legend_title,
                               ifelse(input$strata_var != "None", input$strata_var, ""))
    # 如果图例标题为空字符串，设置为NULL，避免产生空标签
    if (legend_title_text == "") {
      legend_title_text <- NULL
    }
    
    # 创建生存曲线图 - 启用默认图例，禁用默认置信区间和删失点
    p <- suppressWarnings(ggsurvplot(
      fit(),
      data = data,
      risk.table = FALSE,  # 交互式图不显示风险表
      conf.int = FALSE,  # 关键：禁用默认置信区间
      pval = FALSE,
      censor = FALSE,  # 关键：完全禁用默认删失点
      xlim = time_range,
      break.time.by = time_step,  # 使用自定义时间步长
      ggtheme = theme_bw(),
      palette = "Set1",
      surv.alpha = 1,  # 设置生存曲线透明度为1，避免alpha警告
      legend.title = legend_title_text,
      legend.labs = NULL  # 使用默认标签，避免产生未知标签
    ))$plot
    
    # 手动添加删失点，并生成单独的图例
    if (input$km_show_censor) {
      # 获取生存数据
      surv_data <- surv_summary(fit())
      
      # 只选择删失点
      censored_points <- surv_data[surv_data$n.censor > 0, ]
      
      if (nrow(censored_points) > 0) {
        # 手动添加删失点，使用固定颜色和形状，但显示图例
        p <- p +
          geom_point(
            data = censored_points,
            aes(x = time, y = surv, shape = "删失"),
            size = input$km_censor_size,
            color = "black",  # 固定颜色，不映射
            alpha = 1         # 固定透明度
          ) +
          scale_shape_manual(
            name = "",
            values = c("删失" = as.numeric(input$km_censor_shape))
          )
      }
    }
    
    
    # 修复图例和透明度警告
    # 注意：颜色图例已经在ggsurvplot中通过legend.title设置，无需重复设置
    # 确保形状图例正确（标题为空），并移除alpha图例
    p <- p +
      guides(
        shape = guide_legend(title = ""),
        alpha = "none"
      )
    
    # 移除任何可能存在的alpha美学映射
    if ("alpha" %in% names(p$layers)) {
      p$layers <- lapply(p$layers, function(layer) {
        if ("alpha" %in% names(layer$aes_params)) {
          layer$aes_params$alpha <- NULL
        }
        layer
      })
    }
    
    # 应用线条样式
    p <- p +
      update_geom_defaults("step", list(size = input$line_size, linetype = input$line_type))
    
    # 处理标题
    if (!is.null(input$plot_title) && input$plot_title != "") {
      formatted_title <- gsub("\\\\n", "\n", input$plot_title)
      p <- p + labs(title = formatted_title)
    } else if (input$facet_var != "None" && !is.null(input$facet_value)) {
      p <- p + labs(title = paste("交互式生存分析曲线 -", input$facet_var, "=", input$facet_value))
    } else {
      p <- p + labs(title = "交互式生存分析曲线")
    }
    
    # 处理脚注
    if (!is.null(input$plot_caption) && input$plot_caption != "") {
      formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
      p <- p + labs(caption = formatted_caption) +
        theme(plot.caption = element_text(hjust = 0, vjust = 1, size = 10))
    }
    
    # 处理坐标轴标签
    if (!is.null(input$plot_xlab) && input$plot_xlab != "") {
      formatted_xlab <- gsub("\\\\n", "\n", input$plot_xlab)
      p <- p + labs(x = formatted_xlab)
    } else {
      p <- p + labs(x = input$km_time)
    }
    
    if (!is.null(input$plot_ylab) && input$plot_ylab != "") {
      formatted_ylab <- gsub("\\\\n", "\n", input$plot_ylab)
      p <- p + labs(y = formatted_ylab)
    } else {
      p <- p + labs(y = "生存概率")
    }
    
    return(p)
  }
  
  # 交互式生存曲线图
  output$interactiveSurvPlot <- renderPlotly({
    input$render_km_plot
    req(fit(), filtered_data())
    
    # 创建专门的交互式图形
    interactive_plot <- create_interactive_surv_plot()
    
    # 转换为plotly，指定高度避免弃用警告
    plotly_obj <- ggplotly(interactive_plot, height = 600, tooltip = c("x", "y", "colour"))
    
    
    return(plotly_obj)
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
