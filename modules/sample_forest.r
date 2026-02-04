library(shiny)
library(ggplot2)
library(dplyr)
library(cowplot)
library(gridExtra)
library(tidyr)
library(DT)
library(readxl)
library(shinyjs)
library(scales)
library(colourpicker)
library(RColorBrewer)
library(stringr)

# 示例数据
sample_data <- data.frame(
  subgroup = rep(c("心血管疾病", "糖尿病", "高血压"), each = 4),
  study = c("北京中心", "上海中心", "广州中心", "深圳中心",
            "杭州中心", "南京中心", "成都中心", "武汉中心",
            "西安中心", "郑州中心", "长沙中心", "合肥中心"),
  estimate = c(1.25, 1.15, 1.32, 1.08, 0.92, 0.85, 0.97, 0.88, 1.42, 1.35, 1.28, 1.18),
  lower = c(0.95, 0.88, 1.05, 0.82, 0.75, 0.68, 0.80, 0.72, 1.15, 1.08, 1.02, 0.95),
  upper = c(1.55, 1.42, 1.59, 1.34, 1.09, 1.02, 1.14, 1.04, 1.69, 1.62, 1.54, 1.41),
  n = c(100, 120, 110, 105, 95, 100, 115, 105, 125, 130, 120, 115),
  events = c(25, 28, 30, 22, 18, 15, 20, 17, 35, 32, 30, 25)
)

# UI定义
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$style(HTML("
      .well { 
        background-color: #f8f9fa; 
        border: 1px solid #dee2e6; 
        border-radius: 0.375rem;
        padding: 15px;
        margin-bottom: 15px;
      }
      .panel-default {
        border: 1px solid #dee2e6;
        border-radius: 0.375rem;
        margin-bottom: 15px;
      }
      .panel-heading {
        background-color: #e9ecef;
        padding: 10px 15px;
        border-bottom: 1px solid #dee2e6;
      }
      .panel-title {
        margin: 0;
        font-size: 14px;
        font-weight: bold;
      }
      .panel-body {
        padding: 15px;
      }
      .btn-block {
        width: 100%;
      }
      .validation-error {
        color: #dc3545;
        font-weight: bold;
      }
      .validation-success {
        color: #28a745;
        font-weight: bold;
      }
      .validation-warning {
        color: #ffc107;
        font-weight: bold;
      }
      .column-setting-row {
        margin-bottom: 10px;
        padding: 10px;
        background-color: #f8f9fa;
        border-radius: 5px;
        border: 1px solid #dee2e6;
      }
      .column-checkbox {
        margin-right: 10px;
      }
      .column-config-section {
        max-height: 300px;
        overflow-y: auto;
        margin-top: 15px;
        padding: 10px;
        border: 1px solid #dee2e6;
        border-radius: 5px;
        background-color: #f8f9fa;
      }
      .settings-section {
        margin-bottom: 20px;
      }
      .main-settings {
        background-color: #e8f4fd;
        border-left: 4px solid #007bff;
      }
      .advanced-settings {
        background-color: #f8f9fa;
      }
      /* 固定列样式 */
      .fixed-first-col {
        position: sticky;
        left: 0;
        background-color: white;
        z-index: 10;
        border-right: 2px solid #dee2e6;
      }
      .fixed-header {
        position: sticky;
        top: 0;
        background-color: white;
        z-index: 20;
        border-bottom: 2px solid #dee2e6;
      }
      .info-text {
        font-size: 12px;
        color: #6c757d;
        font-style: italic;
        margin-top: 5px;
      }
    "))
  ),
  titlePanel("交互式森林图生成器"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      style = "height: 90vh; overflow-y: auto;",
      
      # 主要设置区域
      tags$div(class = "well main-settings",
               h4("主要设置", style = "color: #007bff;"),
               actionButton("generate", "生成森林图", 
                            class = "btn-primary btn-block",
                            style = "margin-bottom: 15px; font-weight: bold;"),
               
               # 数据设置
               tags$div(class = "settings-section",
                        h5("数据设置"),
                        fileInput("file", "上传数据文件", 
                                  accept = c(".csv", ".xlsx", ".xls"),
                                  width = "100%"),
                        checkboxInput("use_sample", "使用示例数据", value = TRUE),
                        actionButton("validate_data", "验证数据", class = "btn-info btn-block")
               ),
               uiOutput("validation_status")
      ),
      
      # 列映射设置
      tags$div(class = "well",
               h5("数据列映射"),
               selectInput("subgroup_col", "亚组列", choices = NULL, width = "100%"),
               selectInput("study_col", "研究列", choices = NULL, width = "100%"),
               selectInput("estimate_col", "估计值列", choices = NULL, width = "100%"),
               selectInput("lower_col", "下限列", choices = NULL, width = "100%"),
               selectInput("upper_col", "上限列", choices = NULL, width = "100%")
      ),
      
      # 表格显示设置
      tags$div(class = "well",
               h5("表格显示设置"),
               helpText("选择要在表格中显示的列（第一列将始终显示在最左侧作为固定列）"),
               uiOutput("column_selection_ui"),
               
               hr(),
               h5("列显示配置"),
               uiOutput("column_config_ui")
      ),
      
      # 图形基本设置
      tags$div(class = "well",
               h5("图形基本设置"),
               fluidRow(
                 column(6, numericInput("plot_width", "宽度(英寸)", value = 14, min = 8, max = 20, step = 1)),
                 column(6, numericInput("plot_height", "高度(英寸)", value = 10, min = 6, max = 16, step = 1))
               ),
               sliderInput("plot_ratio", "表格/图形宽度比", 
                           min = 0.3, max = 0.7, value = 0.55, step = 0.05),
               sliderInput("display_height", "显示高度(像素)", 
                           min = 400, max = 1200, value = 800, step = 50)
      )
    ),
    
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("森林图", 
                 div(style = "height: 10px;"),
                 uiOutput("plot_ui"),
                 div(style = "height: 10px;"),
                 downloadButton("download_plot", "下载图形"),
                 
                 # 高级设置放在主面板底部
                 tags$div(class = "well advanced-settings",
                          h4("高级设置"),
                          fluidRow(
                            column(6,
                                   tags$div(class = "panel panel-default",
                                            tags$div(class = "panel-heading", "森林图设置"),
                                            tags$div(class = "panel-body",
                                                     fluidRow(
                                                       column(6, numericInput("x_min", "X轴下限", value = 0, min = 0, step = 1)),
                                                       column(6, numericInput("x_max", "X轴上限", value = 100, min = 0, step = 1))
                                                     ),
                                                     numericInput("ref_line", "参考线位置", value = 1.0, step = 1),
                                                     sliderInput("line_width", "线条粗细", 
                                                                 min = 0.5, max = 3, value = 1.2, step = 0.1),
                                                     sliderInput("line_height", "短线长度", 
                                                                 min = 0.05, max = 0.3, value = 0.15, step = 0.01),
                                                     checkboxInput("percentage_format", "X轴显示为百分比", value = FALSE)
                                            )
                                   )
                            ),
                            column(6,
                                   tags$div(class = "panel panel-default",
                                            tags$div(class = "panel-heading", "布局与字体"),
                                            tags$div(class = "panel-body",
                                                     sliderInput("subgroup_spacing", "亚组间距", 
                                                                 min = 0.1, max = 2.0, value = 0.5, step = 0.1),
                                                     helpText("控制不同亚组之间的间距"),
                                                     sliderInput("table_font_size", "表格字体大小", 
                                                                 min = 2, max = 5, value = 3.0, step = 0.1),
                                                     sliderInput("header_font_size", "表头字体大小", 
                                                                 min = 2.5, max = 6, value = 3.5, step = 0.1),
                                                     numericInput("first_col_width", "第一列宽度比例", 
                                                                  min = 0.1, max = 0.5, value = 0.45, step = 0.05),
                                                     numericInput("max_chars_per_line", "第一列每行最大字符数", 
                                                                  min = 5, max = 30, value = 45, step = 1)
                                            )
                                   )
                            )
                          ),
                          
                          # 颜色设置
                          tags$div(class = "panel panel-default",
                                   tags$div(class = "panel-heading", "颜色设置"),
                                   tags$div(class = "panel-body",
                                            fluidRow(
                                              column(6,
                                                     radioButtons("color_mode", "颜色模式",
                                                                  choices = c("交替颜色" = "alternating", 
                                                                              "随机亚组颜色" = "random_subgroup"),
                                                                  selected = "alternating"),
                                                     
                                                     conditionalPanel(
                                                       condition = "input.color_mode == 'alternating'",
                                                       colourInput("color_picker", "选择交替颜色", value = "#E6F3FF"),
                                                       sliderInput("alpha", "颜色透明度", 
                                                                   min = 0.1, max = 1, value = 0.4, step = 0.1)
                                                     ),
                                                     
                                                     conditionalPanel(
                                                       condition = "input.color_mode == 'random_subgroup'",
                                                       selectInput("color_palette", "颜色调色板",
                                                                   choices = c("Set1", "Set2", "Set3", "Pastel1", "Pastel2", 
                                                                               "Dark2", "Accent", "Paired", "Spectral"),
                                                                   selected = "Set1"),
                                                       sliderInput("subgroup_alpha", "颜色透明度", 
                                                                   min = 0.1, max = 1, value = 0.7, step = 0.1)
                                                     )
                                              ),
                                              column(6,
                                                     helpText("交替颜色模式：奇数行使用选择的颜色，偶数行使用白色"),
                                                     helpText("随机亚组颜色模式：每个亚组使用不同的随机颜色"),
                                                     br(),
                                                     helpText("提示：调整透明度可以改善文本的可读性")
                                              )
                                            )
                                   )
                          ),
                          
                          # 文本设置 - 新增部分
                          tags$div(class = "panel panel-default",
                                   tags$div(class = "panel-heading", "文本设置"),
                                   tags$div(class = "panel-body",
                                            fluidRow(
                                              column(6,
                                                     textInput("plot_title", "图形标题", 
                                                               value = "交互式森林图",
                                                               placeholder = "输入图形标题"),
                                                     tags$div(class = "info-text", 
                                                              "提示：使用\"|\"符号表示换行，例如：\"主标题|副标题\""),
                                                     
                                                     textInput("x_axis_label", "X轴标签", 
                                                               value = "风险比",
                                                               placeholder = "输入X轴标签"),
                                                     tags$div(class = "info-text", 
                                                              "提示：使用\"|\"符号表示换行"),
                                                     
                                                     numericInput("title_size", "标题字体大小", 
                                                                  min = 10, max = 24, value = 16, step = 1),
                                                     
                                                     numericInput("axis_label_size", "轴标签字体大小", 
                                                                  min = 8, max = 16, value = 12, step = 1)
                                              ),
                                              column(6,
                                                     textAreaInput("plot_footer", "图形脚注", 
                                                                   value = "注：点大小反映研究权重，区间线表示95%置信区间。|参考线位于HR=1.0处。",
                                                                   placeholder = "输入图形脚注",
                                                                   rows = 4),
                                                     tags$div(class = "info-text", 
                                                              "提示：使用\"|\"符号表示换行"),
                                                     
                                                     numericInput("footer_size", "脚注字体大小", 
                                                                  min = 6, max = 14, value = 10, step = 1),
                                                     
                                                     colourInput("footer_color", "脚注颜色", value = "gray40"),
                                                     
                                                     checkboxInput("show_footer", "显示脚注", value = TRUE)
                                              )
                                            )
                                   )
                          )
                 )
        ),
        tabPanel("数据预览", 
                 div(style = "height: 10px;"),
                 DTOutput("data_preview")),
        tabPanel("数据验证", 
                 div(style = "height: 10px;"),
                 verbatimTextOutput("data_validation"))
      )
    )
  )
)

# 服务器逻辑
server <- function(input, output, session) {
  
  # 存储用户选择和变量历史
  user_selections <- reactiveValues(
    subgroup_col = NULL,
    study_col = NULL,
    estimate_col = NULL,
    lower_col = NULL,
    upper_col = NULL,
    selected_cols = c(),
    display_names = list(),
    alignments = list(),
    fixed_first_col = TRUE  # 新增：标记第一列为固定列
  )
  
  # 反应式数据
  raw_data_reactive <- reactive({
    if (input$use_sample) {
      return(sample_data)
    } else {
      req(input$file)
      
      ext <- tools::file_ext(input$file$name)
      
      tryCatch({
        if (ext == "csv") {
          encodings <- c("UTF-8", "GBK", "UTF-8-BOM", "latin1")
          for (enc in encodings) {
            result <- try(silent = TRUE, {
              read.csv(input$file$datapath, fileEncoding = enc)
            })
            if (!inherits(result, "try-error") && ncol(result) > 0) {
              return(result)
            }
          }
          stop("无法读取CSV文件，请检查文件编码")
        } else if (ext %in% c("xlsx", "xls")) {
          return(read_excel(input$file$datapath))
        } else {
          stop("不支持的文件格式")
        }
      }, error = function(e) {
        showNotification(paste("文件读取错误:", e$message), type = "error")
        return(NULL)
      })
    }
  })
  
  # 数据验证状态
  output$validation_status <- renderUI({
    data <- raw_data_reactive()
    if (is.null(data)) return(NULL)
    
    req_cols <- c(input$subgroup_col, input$study_col, input$estimate_col, 
                  input$lower_col, input$upper_col)
    missing_cols <- req_cols[!req_cols %in% names(data)]
    
    num_cols <- c(input$estimate_col, input$lower_col, input$upper_col)
    non_numeric_cols <- c()
    
    for (col in num_cols) {
      if (col %in% names(data)) {
        converted <- suppressWarnings(as.numeric(data[[col]]))
        if (any(is.na(converted) & !is.na(data[[col]]))) {
          non_numeric_cols <- c(non_numeric_cols, col)
        }
      }
    }
    
    if (length(missing_cols) > 0) {
      tags$div(class = "validation-error",
               paste("缺少列:", paste(missing_cols, collapse = ", ")))
    } else if (length(non_numeric_cols) > 0) {
      tags$div(class = "validation-warning",
               paste("以下列包含非数值数据:", paste(non_numeric_cols, collapse = ", ")))
    } else {
      tags$div(class = "validation-success", "数据验证通过")
    }
  })
  
  # 观察列映射变化并保存选择
  observe({
    if (!is.null(input$subgroup_col)) user_selections$subgroup_col <- input$subgroup_col
    if (!is.null(input$study_col)) user_selections$study_col <- input$study_col
    if (!is.null(input$estimate_col)) user_selections$estimate_col <- input$estimate_col
    if (!is.null(input$lower_col)) user_selections$lower_col <- input$lower_col
    if (!is.null(input$upper_col)) user_selections$upper_col <- input$upper_col
  })
  
  # 更新列选择 - 保留用户选择
  observe({
    data <- raw_data_reactive()
    if (!is.null(data)) {
      cols <- names(data)
      
      safe_update_select <- function(input_id, stored_val, default_val) {
        selected_val <- if (!is.null(stored_val) && stored_val %in% cols) {
          stored_val
        } else if (default_val %in% cols) {
          default_val
        } else if (length(cols) >= 1) {
          cols[1]
        } else {
          NULL
        }
        
        updateSelectInput(session, input_id, choices = cols, selected = selected_val)
      }
      
      safe_update_select("subgroup_col", user_selections$subgroup_col, "subgroup")
      safe_update_select("study_col", user_selections$study_col, "study") 
      safe_update_select("estimate_col", user_selections$estimate_col, "estimate")
      safe_update_select("lower_col", user_selections$lower_col, "lower")
      safe_update_select("upper_col", user_selections$upper_col, "upper")
      
      if (length(user_selections$selected_cols) == 0) {
        default_cols <- c("subgroup", "study")
        available_defaults <- default_cols[default_cols %in% cols]
        if (length(available_defaults) == 0 && length(cols) > 0) {
          available_defaults <- cols[1:min(2, length(cols))]
        }
        user_selections$selected_cols <- available_defaults
      }
      
      for (col in cols) {
        if (is.null(user_selections$display_names[[col]])) {
          user_selections$display_names[[col]] <- col
        }
        if (is.null(user_selections$alignments[[col]])) {
          if (col %in% c("subgroup", "study")) {
            user_selections$alignments[[col]] <- "left"
          } else if (col %in% c("estimate", "lower", "upper", "n", "events")) {
            user_selections$alignments[[col]] <- "right"
          } else {
            user_selections$alignments[[col]] <- "center"
          }
        }
      }
    }
  })
  
  # 动态生成列选择UI
  output$column_selection_ui <- renderUI({
    data <- raw_data_reactive()
    if (is.null(data)) return(tags$p("请先上传数据或使用示例数据"))
    
    cols <- names(data)
    
    tagList(
      wellPanel(
        style = "max-height: 200px; overflow-y: auto;",
        helpText("第一列将自动设置为固定列"),
        lapply(cols, function(col) {
          checkboxInput(
            inputId = paste0("col_select_", col),
            label = col,
            value = col %in% user_selections$selected_cols
          )
        })
      )
    )
  })
  
  # 观察列选择变化
  observe({
    data <- raw_data_reactive()
    if (is.null(data)) return()
    
    cols <- names(data)
    selected_cols <- c()
    
    for (col in cols) {
      input_id <- paste0("col_select_", col)
      if (!is.null(input[[input_id]]) && input[[input_id]]) {
        selected_cols <- c(selected_cols, col)
      }
    }
    
    user_selections$selected_cols <- selected_cols
  })
  
  # 生成列配置UI
  output$column_config_ui <- renderUI({
    selected_cols <- user_selections$selected_cols
    if (length(selected_cols) == 0) {
      return(tags$p("请先选择要显示的列"))
    }
    
    tagList(
      tags$div(class = "column-config-section",
               lapply(seq_along(selected_cols), function(i) {
                 col <- selected_cols[i]
                 is_first_col <- i == 1
                 
                 fluidRow(
                   class = "column-setting-row",
                   column(
                     4,
                     tags$div(style = "padding-top: 8px;", 
                              strong(col),
                              if(is_first_col) tags$span(style = "color: #007bff; font-weight: bold;", " (固定列)"))
                   ),
                   column(
                     4,
                     textInput(
                       inputId = paste0("name_", col),
                       label = NULL,
                       placeholder = "显示名称",
                       value = ifelse(!is.null(user_selections$display_names[[col]]), 
                                      user_selections$display_names[[col]], col)
                     )
                   ),
                   column(
                     4,
                     selectInput(
                       inputId = paste0("align_", col),
                       label = NULL,
                       choices = c("左对齐" = "left", "居中" = "center", "右对齐" = "right"),
                       selected = ifelse(!is.null(user_selections$alignments[[col]]), 
                                         user_selections$alignments[[col]], 
                                         ifelse(is_first_col, "left", "center"))
                     )
                   )
                 )
               })
      )
    )
  })
  
  # 观察列设置变化并更新reactiveValues
  observe({
    selected_cols <- user_selections$selected_cols
    if (length(selected_cols) == 0) return()
    
    for (col in selected_cols) {
      name_input <- paste0("name_", col)
      align_input <- paste0("align_", col)
      
      if (!is.null(input[[name_input]]) && input[[name_input]] != "") {
        user_selections$display_names[[col]] <- input[[name_input]]
      }
      
      if (!is.null(input[[align_input]])) {
        user_selections$alignments[[col]] <- input[[align_input]]
      }
    }
  })
  
  # 处理数据 - 确保保持原始数据顺序
  processed_data <- eventReactive(input$generate, {
    req(raw_data_reactive(), input$subgroup_col, input$study_col, 
        input$estimate_col, input$lower_col, input$upper_col)
    
    data <- raw_data_reactive()
    
    required_cols <- c(input$subgroup_col, input$study_col, input$estimate_col,
                       input$lower_col, input$upper_col)
    missing_cols <- required_cols[!required_cols %in% names(data)]
    if (length(missing_cols) > 0) {
      showNotification(paste("缺少必要列:", paste(missing_cols, collapse = ", ")), 
                       type = "error")
      return(NULL)
    }
    
    processed <- data
    
    # 保持原始数据顺序，添加原始行号
    processed$original_row_id <- seq_len(nrow(processed))
    
    processed$subgroup_mapped <- data[[input$subgroup_col]]
    processed$study_mapped <- data[[input$study_col]]
    
    processed$estimate_mapped <- tryCatch({
      as.numeric(data[[input$estimate_col]])
    }, warning = function(w) {
      showNotification("估计值列包含非数值数据", type = "warning")
      rep(NA_real_, nrow(data))
    }, error = function(e) {
      showNotification("估计值列转换错误", type = "error")
      rep(NA_real_, nrow(data))
    })
    
    processed$lower_mapped <- tryCatch({
      as.numeric(data[[input$lower_col]])
    }, warning = function(w) {
      showNotification("下限列包含非数值数据", type = "warning")
      rep(NA_real_, nrow(data))
    })
    
    processed$upper_mapped <- tryCatch({
      as.numeric(data[[input$upper_col]])
    }, warning = function(w) {
      showNotification("上限列包含非数值数据", type = "warning")
      rep(NA_real_, nrow(data))
    })
    
    x_min <- input$x_min
    x_max <- input$x_max
    
    color_mode <- input$color_mode
    alpha <- ifelse(color_mode == "alternating", input$alpha, input$subgroup_alpha)
    
    # 保持原始亚组顺序
    subgroup_order <- unique(processed$subgroup_mapped)
    
    if (color_mode == "alternating") {
      color1 <- input$color_picker
      color2 <- "#FFFFFF"
      
      subgroup_color_map <- data.frame(
        subgroup = subgroup_order,
        subgroup_color_id = seq_along(subgroup_order)
      )
      
      processed <- processed %>%
        left_join(subgroup_color_map, by = c("subgroup_mapped" = "subgroup")) %>%
        mutate(
          bg_color = ifelse(subgroup_color_id %% 2 == 1, color1, color2)
        )
    } else {
      n_subgroups <- length(subgroup_order)
      
      if (n_subgroups <= 8) {
        colors <- brewer.pal(max(3, n_subgroups), input$color_palette)
        colors <- colors[1:n_subgroups]
      } else {
        colors <- rainbow(n_subgroups)
      }
      
      color_map <- data.frame(
        subgroup = subgroup_order,
        bg_color = colors
      )
      
      processed <- processed %>%
        left_join(color_map, by = c("subgroup_mapped" = "subgroup"))
    }
    
    processed <- processed %>%
      mutate(
        out_of_range_low = !is.na(lower_mapped) & lower_mapped < x_min,
        out_of_range_high = !is.na(upper_mapped) & upper_mapped > x_max,
        
        lower_adj = pmax(lower_mapped, x_min, na.rm = TRUE),
        upper_adj = pmin(upper_mapped, x_max, na.rm = TRUE),
        estimate_adj = case_when(
          is.na(estimate_mapped) ~ NA_real_,
          estimate_mapped < x_min ~ x_min + 0.02,
          estimate_mapped > x_max ~ x_max - 0.02,
          TRUE ~ estimate_mapped
        )
      ) %>%
      mutate(
        estimate_text = ifelse(is.na(estimate_mapped), "NA", 
                               sprintf("%.2f", estimate_mapped)),
        ci_text = ifelse(is.na(lower_mapped) | is.na(upper_mapped), "NA",
                         sprintf("%.2f-%.2f", lower_mapped, upper_mapped)),
        weight = ifelse(!is.na(lower_mapped) & !is.na(upper_mapped), 
                        1/(upper_mapped - lower_mapped)^2, NA),
        point_size = ifelse(!is.na(weight), 
                            scales::rescale(weight, to = c(2, 5), na.rm = TRUE), 3)
      )
    
    # 按照原始数据顺序计算y位置
    processed <- calculate_y_positions(processed, input$subgroup_spacing)
    
    return(processed)
  })
  
  # 计算y位置函数 - 保持原始数据顺序
  calculate_y_positions <- function(data, subgroup_spacing) {
    # 按照原始数据顺序分组计算
    data_with_y <- data %>%
      arrange(original_row_id) %>%  # 确保按照原始顺序
      group_by(subgroup_mapped) %>%
      mutate(
        subgroup_row_id = row_number(),
        subgroup_n_rows = n()
      ) %>%
      ungroup() %>%
      group_by(subgroup_mapped) %>%
      mutate(
        subgroup_start = first(original_row_id),
        subgroup_end = last(original_row_id)
      ) %>%
      ungroup() %>%
      arrange(desc(original_row_id)) %>%  # 从下往上排列，保持原始顺序
      mutate(
        y_pos = row_number()
      ) %>%
      arrange(original_row_id)  # 最后恢复原始顺序
    
    return(data_with_y)
  }
  
  # 获取列对齐设置
  get_column_alignments <- reactive({
    selected_cols <- user_selections$selected_cols
    if (length(selected_cols) == 0) return(list())
    
    alignments <- list()
    for (col in selected_cols) {
      alignments[[col]] <- user_selections$alignments[[col]]
    }
    return(alignments)
  })
  
  # 获取自定义列名
  get_custom_column_names <- reactive({
    selected_cols <- user_selections$selected_cols
    if (length(selected_cols) == 0) return(list())
    
    custom_names <- list()
    for (col in selected_cols) {
      custom_names[[col]] <- user_selections$display_names[[col]]
    }
    return(custom_names)
  })
  
  # 获取选中的表格列
  get_table_cols <- reactive({
    selected_cols <- user_selections$selected_cols
    if (length(selected_cols) == 0) {
      return(c("subgroup_mapped", "study_mapped", "estimate_text", "ci_text"))
    }
    return(selected_cols)
  })
  
  # 智能文本换行函数
  smart_wrap_text <- function(text, max_chars_per_line = 15) {
    if (is.null(text) || length(text) == 0) return(text)
    
    sapply(text, function(x) {
      if (is.na(x) || nchar(x) <= max_chars_per_line) {
        return(x)
      } else {
        words <- strsplit(x, " ")[[1]]
        lines <- character(0)
        current_line <- ""
        
        for (word in words) {
          if (nchar(current_line) + nchar(word) + ifelse(current_line == "", 0, 1) <= max_chars_per_line) {
            if (current_line == "") {
              current_line <- word
            } else {
              current_line <- paste(current_line, word)
            }
          } else {
            if (current_line != "") {
              lines <- c(lines, current_line)
            }
            current_line <- word
            
            if (nchar(word) > max_chars_per_line) {
              split_pos <- max_chars_per_line
              while (split_pos > 0 && substr(word, split_pos, split_pos) != " " && 
                     substr(word, split_pos, split_pos) != "-" && 
                     substr(word, split_pos, split_pos) != "/") {
                split_pos <- split_pos - 1
              }
              
              if (split_pos == 0) {
                split_pos <- max_chars_per_line
              }
              
              lines <- c(lines, substr(word, 1, split_pos))
              current_line <- substr(word, split_pos + 1, nchar(word))
            }
          }
        }
        
        if (current_line != "") {
          lines <- c(lines, current_line)
        }
        
        return(paste(lines, collapse = "\n"))
      }
    }, USE.NAMES = FALSE)
  }
  
  # 处理换行文本函数 - 新增
  process_line_breaks <- function(text) {
    if (is.null(text) || text == "") return("")
    # 将 "|" 替换为换行符
    gsub("\\|", "\n", text)
  }
  
  # 数据验证输出
  output$data_validation <- renderPrint({
    data <- raw_data_reactive()
    if (is.null(data)) return("无数据")
    
    cat("=== 数据验证报告 ===\n\n")
    cat("数据概览:\n")
    cat("行数:", nrow(data), "\n")
    cat("列数:", ncol(data), "\n")
    cat("\n列信息:\n")
    print(str(data))
    
    req_cols <- c(input$subgroup_col, input$study_col, input$estimate_col, 
                  input$lower_col, input$upper_col)
    missing_cols <- req_cols[!req_cols %in% names(data)]
    if (length(missing_cols) > 0) {
      cat("\n❌ 警告: 缺少必要列:", paste(missing_cols, collapse = ", "), "\n")
    } else {
      cat("\n✅ 必要列检查通过\n")
    }
    
    num_cols <- c(input$estimate_col, input$lower_col, input$upper_col)
    cat("\n数值列检查:\n")
    for (col in num_cols) {
      if (col %in% names(data)) {
        na_count <- sum(is.na(data[[col]]))
        
        if (!is.numeric(data[[col]])) {
          cat("列", col, ": ❌ 非数值类型\n")
          converted <- suppressWarnings(as.numeric(data[[col]]))
          failed_count <- sum(is.na(converted) & !is.na(data[[col]]))
          if (failed_count > 0) {
            cat("      ", failed_count, "个值无法转换为数值\n")
          }
        } else {
          cat("列", col, ": ✅ 数值类型, NA值数量 =", na_count, "\n")
        }
      }
    }
    
    cat("\n数据质量摘要:\n")
    if (nrow(data) == 0) {
      cat("❌ 数据为空\n")
    } else if (length(missing_cols) > 0) {
      cat("❌ 数据不完整\n")
    } else {
      has_non_numeric <- FALSE
      for (col in num_cols) {
        if (col %in% names(data) && !is.numeric(data[[col]])) {
          has_non_numeric <- TRUE
          break
        }
      }
      
      if (has_non_numeric) {
        cat("⚠️  数据包含非数值列\n")
      } else {
        cat("✅ 数据质量良好\n")
      }
    }
    
    cat("\n当前列映射:\n")
    cat("亚组列:", input$subgroup_col, "\n")
    cat("研究列:", input$study_col, "\n")
    cat("估计值列:", input$estimate_col, "\n")
    cat("下限列:", input$lower_col, "\n")
    cat("上限列:", input$upper_col, "\n")
  })
  
  # 动态设置图形高度
  output$plot_ui <- renderUI({
    plotOutput("forest_plot", height = paste0(input$display_height, "px"))
  })
  
  # 生成森林图 - 添加自定义文本选项
  forest_plot_reactive <- eventReactive(input$generate, {
    req(processed_data())
    
    data <- processed_data()
    x_min <- input$x_min
    x_max <- input$x_max
    ref_line <- input$ref_line
    line_width <- input$line_width
    line_height <- input$line_height
    table_font_size <- input$table_font_size
    header_font_size <- input$header_font_size
    alpha <- ifelse(input$color_mode == "alternating", input$alpha, input$subgroup_alpha)
    table_ratio <- input$plot_ratio
    first_col_width <- input$first_col_width
    max_chars_per_line <- input$max_chars_per_line
    
    # 获取文本设置
    plot_title <- process_line_breaks(input$plot_title)
    x_axis_label <- process_line_breaks(input$x_axis_label)
    plot_footer <- process_line_breaks(input$plot_footer)
    title_size <- input$title_size
    axis_label_size <- input$axis_label_size
    footer_size <- input$footer_size
    footer_color <- input$footer_color
    show_footer <- input$show_footer
    
    column_alignments <- get_column_alignments()
    custom_column_names <- get_custom_column_names()
    table_cols <- get_table_cols()
    
    # 确保数据按照原始顺序排列
    data <- data %>% arrange(original_row_id)
    
    y_breaks <- data$y_pos
    n_rows <- nrow(data)
    
    header_offset <- ifelse(n_rows > 15, 1.3, 1.1)
    line_offset <- ifelse(n_rows > 15, 0.9, 0.6)
    y_upper_limit <- ifelse(n_rows > 15, 1.8, 1.5)
    
    if (input$percentage_format) {
      x_breaks <- seq(x_min, x_max, length.out = 11)
      x_labels <- sprintf("%.0f%%", x_breaks * 100)
    } else {
      x_breaks <- seq(x_min, x_max, length.out = 11)
      x_labels <- sprintf("%.0f", x_breaks)
    }
    
    # 1. 创建森林图形部分 - 保持原始数据顺序
    forest_plot <- ggplot(data, aes(x = estimate_adj, y = y_pos)) +
      geom_rect(aes(xmin = x_min, xmax = x_max, 
                    ymin = y_pos - 0.45, ymax = y_pos + 0.45,
                    fill = bg_color), alpha = alpha) +
      geom_vline(xintercept = ref_line, linetype = "solid", color = "black", linewidth = 0.8) +
      geom_vline(xintercept = seq(x_min, x_max, length.out = 8), linetype = "dotted", 
                 color = "gray70", alpha = 0.6, linewidth = 0.3) +
      geom_errorbar(data = filter(data, !is.na(estimate_adj)),
                    aes(xmin = lower_adj, xmax = upper_adj), 
                    orientation = "y",
                    width = line_height, linewidth = line_width, color = "#2E86AB") +
      geom_point(data = filter(data, !is.na(estimate_adj)),
                 aes(size = 3), fill = "#A23B72", color = "white", 
                 shape = 21, stroke = 1) +
      geom_segment(data = filter(data, !is.na(estimate_adj) & out_of_range_low),
                   aes(x = x_min, xend = x_min - 0.03, y = y_pos, yend = y_pos),
                   arrow = arrow(length = unit(0.2, "cm"), type = "closed"),
                   color = "#2E86AB", linewidth = line_width) +
      geom_segment(data = filter(data, !is.na(estimate_adj) & out_of_range_high),
                   aes(x = x_max, xend = x_max + 0.03, y = y_pos, yend = y_pos),
                   arrow = arrow(length = unit(0.2, "cm"), type = "closed"),
                   color = "#2E86AB", linewidth = line_width) +
      {
        subgroup_boundaries <- data %>%
          group_by(subgroup_mapped) %>%
          summarise(
            min_y = min(y_pos),
            max_y = max(y_pos)
          ) %>%
          arrange(desc(min_y)) %>%
          mutate(
            boundary_y = min_y - 0.5
          ) %>%
          filter(boundary_y > min(data$y_pos) - 0.5)
        
        geom_hline(data = subgroup_boundaries, 
                   aes(yintercept = boundary_y), 
                   linetype = "dashed", 
                   color = "gray50", linewidth = 0.5)
      } +
      scale_fill_identity() +
      scale_size_identity() +
      scale_y_continuous(
        breaks = y_breaks,
        labels = NULL,
        limits = c(min(y_breaks) - 0.6, max(y_breaks) + y_upper_limit),
        expand = expansion(mult = c(0, 0))
      ) +
      scale_x_continuous(
        breaks = x_breaks,
        labels = x_labels,
        limits = c(x_min - 0.05, x_max + 0.05),
        expand = c(0, 0)
      ) +
      labs(
        x = x_axis_label,  # 使用自定义X轴标签
        y = NULL
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
        panel.grid.minor.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.title.x = element_text(face = "bold", size = axis_label_size, margin = margin(t = 10)),
        axis.text.x = element_text(color = "black", size = 10),
        plot.margin = margin(10, 15, 10, 5)
      )
    
    # 2. 创建表格部分 - 保持原始数据顺序
    create_table_plot <- function(data, table_cols, table_font_size, header_font_size, 
                                  alpha, header_offset, line_offset, y_upper_limit, 
                                  alignments, custom_names, first_col_width, max_chars_per_line) {
      
      n_cols <- length(table_cols)
      
      # 重新设计列位置计算
      col_widths <- numeric(n_cols)
      col_positions <- numeric(n_cols)
      
      if (n_cols == 1) {
        # 只有一列时，占据整个宽度
        col_widths[1] <- 1
        col_positions[1] <- 0.5
      } else {
        # 多列时，第一列固定宽度，其他列平分剩余空间
        col_widths[1] <- first_col_width
        remaining_width <- 1 - first_col_width
        col_widths[2:n_cols] <- remaining_width / (n_cols - 1)
        
        # 计算每列的中心位置
        current_pos <- 0
        for (i in 1:n_cols) {
          col_positions[i] <- current_pos + col_widths[i] / 2
          current_pos <- current_pos + col_widths[i]
        }
      }
      
      # 准备表头数据
      header_data <- data.frame(
        col_index = 1:n_cols,
        x = col_positions,
        label = sapply(table_cols, function(col) {
          if (!is.null(custom_names[[col]])) {
            custom_names[[col]]
          } else {
            col
          }
        }),
        y = max(data$y_pos) + header_offset
      )
      
      # 准备表格内容数据 - 保持原始顺序
      table_data <- data
      for(i in seq_along(table_cols)) {
        col_name <- table_cols[i]
        
        if (col_name %in% names(table_data)) {
          col_values <- as.character(table_data[[col_name]])
          col_values[is.na(col_values)] <- "NA"
          
          # 如果是亚组列，只显示每个亚组的第一个
          if (col_name == input$subgroup_col) {
            # 标记每个亚组的第一行
            subgroup_first <- !duplicated(table_data$subgroup_mapped)
            # 只保留亚组第一行的值，其他行设为空字符串
            col_values[!subgroup_first] <- ""
          }
          
          # 第一列应用文本换行
          if (i == 1) {
            col_values <- smart_wrap_text(col_values, max_chars_per_line)
          }
        } else {
          col_values <- rep(paste0("Missing: ", col_name), nrow(table_data))
        }
        
        table_data[[paste0("table_col_", i)]] <- col_values
      }
      
      # 创建基础表格图形
      table_plot <- ggplot(table_data, aes(x = 0, y = y_pos)) +
        geom_rect(aes(xmin = -Inf, xmax = Inf, 
                      ymin = y_pos - 0.45, ymax = y_pos + 0.45,
                      fill = bg_color), alpha = alpha) +
        geom_hline(yintercept = max(data$y_pos) + line_offset, color = "black", linewidth = 0.8)
      
      # 添加表头和列内容
      for(i in seq_along(table_cols)) {
        col_name <- table_cols[i]
        x_pos <- col_positions[i]
        col_width <- col_widths[i]
        
        # 获取对齐设置，第一列强制左对齐
        if (i == 1) {
          alignment <- "left"
        } else {
          alignment <- ifelse(!is.null(alignments[[col_name]]), alignments[[col_name]], "center")
        }
        
        # 根据对齐方式设置hjust和x偏移
        if (alignment == "left") {
          hjust_val <- 0
          adjusted_x_pos <- x_pos - col_width / 2 + 0.01
        } else if (alignment == "right") {
          hjust_val <- 1
          adjusted_x_pos <- x_pos + col_width / 2 - 0.01
        } else {
          hjust_val <- 0.5
          adjusted_x_pos <- x_pos
        }
        
        # 为每个表头单独创建数据框
        header_row <- data.frame(
          x = adjusted_x_pos,
          y = max(data$y_pos) + header_offset,
          label = ifelse(!is.null(custom_names[[col_name]]), 
                         custom_names[[col_name]], col_name)
        )
        
        # 添加表头
        table_plot <- table_plot +
          geom_text(data = header_row, 
                    aes(x = x, y = y, label = label),
                    hjust = hjust_val, vjust = 0.5, 
                    fontface = "bold", size = header_font_size)
        
        # 添加列内容
        table_plot <- table_plot +
          geom_text(aes_string(x = adjusted_x_pos, y = "y_pos",
                               label = paste0("table_col_", i)), 
                    hjust = hjust_val, vjust = 0.5, size = table_font_size,
                    lineheight = 0.8)
      }
      
      # 添加亚组分隔线
      subgroup_boundaries <- data %>%
        group_by(subgroup_mapped) %>%
        summarise(
          min_y = min(y_pos),
          max_y = max(y_pos)
        ) %>%
        arrange(desc(min_y)) %>%
        mutate(
          boundary_y = min_y - 0.5
        ) %>%
        filter(boundary_y > min(data$y_pos) - 0.5)
      
      table_plot <- table_plot +
        geom_hline(data = subgroup_boundaries, 
                   aes(yintercept = boundary_y), 
                   linetype = "dashed", 
                   color = "gray50", linewidth = 0.5) +
        scale_fill_identity() +
        scale_y_continuous(
          breaks = y_breaks,
          labels = NULL,
          limits = c(min(y_breaks) - 0.6, max(y_breaks) + y_upper_limit),
          expand = expansion(mult = c(0, 0))
        ) +
        scale_x_continuous(limits = c(0, 1)) +
        labs(x = NULL, y = NULL) +
        theme_void() +
        theme(
          plot.margin = margin(10, 5, 10, 15)
        )
      table_plot <- table_plot +
        geom_hline(aes(yintercept = min(data$y_pos) - 0.5), 
                   linetype = "solid", 
                   color = "black", linewidth = 0.8)
      return(table_plot)
    }
    
    table_plot <- create_table_plot(data, table_cols, table_font_size, header_font_size, 
                                    alpha, header_offset, line_offset, y_upper_limit, 
                                    column_alignments, custom_column_names, first_col_width, max_chars_per_line)
    
    # 3. 组合图形
    aligned_plots <- align_plots(table_plot, forest_plot, align = "v", axis = "lr")
    
    combined_plot <- plot_grid(
      aligned_plots[[1]],
      aligned_plots[[2]],
      ncol = 2, 
      align = "h",
      rel_widths = c(table_ratio, 1 - table_ratio)
    )
    
    # 4. 添加标题和脚注 - 使用自定义设置
    title_gg <- ggdraw() + 
      draw_label(plot_title, 
                 fontface = 'bold', size = title_size, hjust = 0.5)
    
    # 动态生成脚注
    footer_text <- plot_footer
    if (any(data$out_of_range_low | data$out_of_range_high, na.rm = TRUE)) {
      footer_text <- paste0(footer_text, " ")
    }
    
    footer_gg <- ggdraw() + 
      draw_label(footer_text, 
                 size = footer_size, hjust = 0, x = 0.02, 
                 color = footer_color)
    
    # 5. 最终组合
    if (show_footer) {
      final_plot <- plot_grid(
        title_gg, 
        combined_plot,
        footer_gg,
        ncol = 1,
        rel_heights = c(0.08, 0.85, 0.07)
      )
    } else {
      final_plot <- plot_grid(
        title_gg, 
        combined_plot,
        ncol = 1,
        rel_heights = c(0.08, 0.92)
      )
    }
    
    return(final_plot)
  })
  
  # 显示森林图
  output$forest_plot <- renderPlot({
    plot_obj <- forest_plot_reactive()
    if (is.null(plot_obj)) {
      plot(1, 1, type = "n", axes = FALSE, xlab = "", ylab = "")
      text(1, 1, "无法生成图形，请检查数据设置", col = "red", cex = 1.5)
    } else {
      plot_obj
    }
  })
  
  # 下载图形
  output$download_plot <- downloadHandler(
    filename = function() {
      paste("forest_plot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png", sep = "")
    },
    content = function(file) {
      plot_obj <- forest_plot_reactive()
      if (!is.null(plot_obj)) {
        ggsave(file, plot_obj, 
               width = input$plot_width, 
               height = input$plot_height, 
               dpi = 300, bg = "white")
      }
    }
  )
  
  # 显示数据预览
  output$data_preview <- renderDT({
    data <- raw_data_reactive()
    if (is.null(data)) return(NULL)
    
    datatable(data, 
              extensions = c('FixedColumns', 'FixedHeader'),
              options = list(
                pageLength = 10,
                scrollX = TRUE,
                fixedColumns = list(leftColumns = 1),
                fixedHeader = TRUE,
                language = list(
                  url = '//cdn.datatables.net/plug-ins/1.10.11/i18n/Chinese.json'
                )
              ),
              rownames = FALSE) %>%
      formatStyle(1, className = 'fixed-first-col') %>%
      formatStyle(0, target = 'row', fontSize = '12px')
  })
}

# 运行应用
shinyApp(ui = ui, server = server)