# 森林图子模块 - 基于 sample_forest.r 重构（简化版）
# 只保留核心功能：列映射、表格配置、图形设置和文本自定义
# 数据从父模块传入，不包含数据上传和CSS

# 加载必要的包
library(ggplot2)
library(dplyr)
library(cowplot)
library(gridExtra)
library(tidyr)
library(DT)
library(shinyjs)
library(scales)
library(colourpicker)
library(RColorBrewer)
library(stringr)

forest_plot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        width = 12,
        title = "森林图参数配置",
        status = "primary",
        solidHeader = TRUE,
        sidebarLayout(
          sidebarPanel(
            width = 3,
            style = "height: 90vh; overflow-y: auto;",
            
            # 列映射设置
            tags$div(class = "well",
                     h4("数据列映射", style = "color: #007bff;"),
                     selectInput(ns("subgroup_col"), "亚组列", choices = NULL, width = "100%"),
                     selectInput(ns("study_col"), "研究列", choices = NULL, width = "100%"),
                     selectInput(ns("estimate_col"), "估计值列", choices = NULL, width = "100%"),
                     selectInput(ns("lower_col"), "下限列", choices = NULL, width = "100%"),
                     selectInput(ns("upper_col"), "上限列", choices = NULL, width = "100%")
            ),
            
            # 表格显示设置
            tags$div(class = "well",
                     h4("表格显示设置", style = "color: #007bff;"),
                     helpText("选择要在表格中显示的列（第一列将作为固定列）"),
                     uiOutput(ns("column_selection_ui")),
                     
                     hr(),
                     h5("列显示配置"),
                     uiOutput(ns("column_config_ui"))
            ),
            
            # 图形基本设置
            tags$div(class = "well",
                     h4("图形基本设置", style = "color: #007bff;"),
                     actionButton(ns("generate"), "生成森林图", 
                                  class = "btn-primary btn-block",
                                  style = "margin-bottom: 15px; font-weight: bold;"),
                     
                     fluidRow(
                       column(6, numericInput(ns("plot_width"), "宽度(英寸)", value = 14, min = 8, max = 20, step = 1)),
                       column(6, numericInput(ns("plot_height"), "高度(英寸)", value = 10, min = 6, max = 16, step = 1))
                     ),
                     sliderInput(ns("plot_ratio"), "表格/图形宽度比", 
                                 min = 0.3, max = 0.7, value = 0.55, step = 0.05),
                     sliderInput(ns("display_height"), "显示高度(像素)", 
                                 min = 400, max = 1200, value = 800, step = 50)
            )
          ),
          
          mainPanel(
            width = 9,
            tabsetPanel(
              id = ns("output_tabs"),
              tabPanel("森林图", 
                       div(style = "height: 10px;"),
                       uiOutput(ns("plot_ui")),
                       div(style = "height: 10px;"),
                       downloadButton(ns("download_plot"), "下载图形"),
                       
                       # 高级设置折叠面板
                       tags$div(class = "well",
                                h4("高级设置"),
                                fluidRow(
                                  column(6,
                                         tags$div(class = "panel panel-default",
                                                  tags$div(class = "panel-heading", "森林图设置"),
                                                  tags$div(class = "panel-body",
                                                           fluidRow(
                                                             column(6, numericInput(ns("x_min"), "X轴下限", value = 0, min = 0, step = 1)),
                                                             column(6, numericInput(ns("x_max"), "X轴上限", value = 100, min = 0, step = 1))
                                                           ),
                                                           numericInput(ns("ref_line"), "参考线位置", value = 1.0, step = 1),
                                                           sliderInput(ns("line_width"), "线条粗细", 
                                                                       min = 0.5, max = 3, value = 1.2, step = 0.1),
                                                           sliderInput(ns("line_height"), "短线长度", 
                                                                       min = 0.05, max = 0.3, value = 0.15, step = 0.01),
                                                           checkboxInput(ns("percentage_format"), "X轴显示为百分比", value = FALSE)
                                                  )
                                         )
                                  ),
                                  column(6,
                                         tags$div(class = "panel panel-default",
                                                  tags$div(class = "panel-heading", "布局与字体"),
                                                  tags$div(class = "panel-body",
                                                           sliderInput(ns("table_font_size"), "表格字体大小", 
                                                                       min = 2, max = 5, value = 3.0, step = 0.1),
                                                           sliderInput(ns("header_font_size"), "表头字体大小", 
                                                                       min = 2.5, max = 6, value = 3.5, step = 0.1),
                                                           numericInput(ns("first_col_width"), "第一列宽度比例", 
                                                                        min = 0.1, max = 0.5, value = 0.45, step = 0.05),
                                                           numericInput(ns("max_chars_per_line"), "第一列每行最大字符数", 
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
                                                           radioButtons(ns("color_mode"), "颜色模式",
                                                                        choices = c("交替颜色" = "alternating", 
                                                                                    "随机亚组颜色" = "random_subgroup"),
                                                                        selected = "alternating"),
                                                           
                                                           conditionalPanel(
                                                             condition = paste0("input['", ns("color_mode"), "'] == 'alternating'"),
                                                             colourInput(ns("color_picker"), "选择交替颜色", value = "#E6F3FF"),
                                                             sliderInput(ns("alpha"), "颜色透明度", 
                                                                         min = 0.1, max = 1, value = 0.4, step = 0.1)
                                                           ),
                                                           
                                                           conditionalPanel(
                                                             condition = paste0("input['", ns("color_mode"), "'] == 'random_subgroup'"),
                                                             selectInput(ns("color_palette"), "颜色调色板",
                                                                         choices = c("Set1", "Set2", "Set3", "Pastel1", "Pastel2", 
                                                                                     "Dark2", "Accent", "Paired", "Spectral"),
                                                                         selected = "Set1"),
                                                             sliderInput(ns("subgroup_alpha"), "颜色透明度", 
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
                                
                                # 文本设置
                                tags$div(class = "panel panel-default",
                                         tags$div(class = "panel-heading", "文本设置"),
                                         tags$div(class = "panel-body",
                                                  fluidRow(
                                                    column(6,
                                                           textInput(ns("plot_title"), "图形标题", 
                                                                     value = "交互式森林图",
                                                                     placeholder = "输入图形标题"),
                                                           tags$div(class = "info-text", 
                                                                    "提示：使用\"|\"符号表示换行，例如：\"主标题|副标题\""),
                                                           
                                                           textInput(ns("x_axis_label"), "X轴标签", 
                                                                     value = "风险比",
                                                                     placeholder = "输入X轴标签"),
                                                           tags$div(class = "info-text", 
                                                                    "提示：使用\"|\"符号表示换行"),
                                                           
                                                           numericInput(ns("title_size"), "标题字体大小", 
                                                                        min = 10, max = 24, value = 16, step = 1),
                                                           
                                                           numericInput(ns("axis_label_size"), "轴标签字体大小", 
                                                                        min = 8, max = 16, value = 12, step = 1)
                                                    ),
                                                    column(6,
                                                           textAreaInput(ns("plot_footer"), "图形脚注", 
                                                                         value = "注：点大小反映研究权重，区间线表示95%置信区间。|参考线位于HR=1.0处。",
                                                                         placeholder = "输入图形脚注",
                                                                         rows = 4),
                                                           tags$div(class = "info-text", 
                                                                    "提示：使用\"|\"符号表示换行"),
                                                           
                                                           numericInput(ns("footer_size"), "脚注字体大小", 
                                                                        min = 6, max = 14, value = 10, step = 1),
                                                           
                                                           colourInput(ns("footer_color"), "脚注颜色", value = "gray40"),
                                                           
                                                           checkboxInput(ns("show_footer"), "显示脚注", value = TRUE)
                                                    )
                                                  )
                                         )
                                )
                       )
              ),
              tabPanel("数据预览", 
                       div(style = "height: 10px;"),
                       DTOutput(ns("data_preview"))
              )
            )
          )
        )
      )
    )
  )
}

forest_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储用户选择和变量历史
  user_selections <- reactiveValues(
    subgroup_col = NULL,
    study_col = NULL,
    estimate_col = NULL,
    lower_col = NULL,
    upper_col = NULL,
    selected_cols = c(),
    display_names = list(),
    alignments = list()
  )
  
  # 观察数据变化，更新列选择
  observe({
    req(data())
    
    cols <- names(data())
    if (length(cols) == 0) return()
    
    # 更新列映射选择框
    updateSelectInput(session, "subgroup_col", choices = cols, 
                      selected = ifelse("subgroup" %in% cols, "subgroup", cols[1]))
    updateSelectInput(session, "study_col", choices = cols,
                      selected = ifelse("study" %in% cols, "study", 
                                       ifelse(length(cols) > 1, cols[2], cols[1])))
    updateSelectInput(session, "estimate_col", choices = cols,
                      selected = ifelse("estimate" %in% cols, "estimate",
                                       ifelse(length(cols) > 2, cols[3], cols[1])))
    updateSelectInput(session, "lower_col", choices = cols,
                      selected = ifelse("lower" %in% cols, "lower",
                                       ifelse(length(cols) > 3, cols[4], cols[1])))
    updateSelectInput(session, "upper_col", choices = cols,
                      selected = ifelse("upper" %in% cols, "upper",
                                       ifelse(length(cols) > 4, cols[5], cols[1])))
    
    # 初始化选中的列
    if (length(user_selections$selected_cols) == 0) {
      default_cols <- c("subgroup", "study")
      available_defaults <- default_cols[default_cols %in% cols]
      if (length(available_defaults) == 0 && length(cols) > 0) {
        available_defaults <- cols[1:min(2, length(cols))]
      }
      user_selections$selected_cols <- available_defaults
    }
    
    # 初始化列显示名称和对齐方式
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
  })
  
  # 动态生成列选择UI
  output$column_selection_ui <- renderUI({
    req(data())
    cols <- names(data())
    if (length(cols) == 0) return(tags$p("数据没有列"))
    
    tagList(
      wellPanel(
        style = "max-height: 200px; overflow-y: auto;",
        helpText("第一列将自动设置为固定列"),
        lapply(cols, function(col) {
          checkboxInput(
            inputId = ns(paste0("col_select_", col)),
            label = col,
            value = col %in% user_selections$selected_cols
          )
        })
      )
    )
  })
  
  # 观察列选择变化
  observe({
    req(data())
    cols <- names(data())
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
                       inputId = ns(paste0("name_", col)),
                       label = NULL,
                       placeholder = "显示名称",
                       value = ifelse(!is.null(user_selections$display_names[[col]]), 
                                      user_selections$display_names[[col]], col)
                     )
                   ),
                   column(
                     4,
                     selectInput(
                       inputId = ns(paste0("align_", col)),
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
  
  # 获取表格列对齐方式
  get_column_alignments <- reactive({
    alignments <- list()
    selected_cols <- user_selections$selected_cols
    
    for (col in selected_cols) {
      if (!is.null(user_selections$alignments[[col]])) {
        alignments[[col]] <- user_selections$alignments[[col]]
      } else {
        alignments[[col]] <- "center"
      }
    }
    return(alignments)
  })
  
  # 获取自定义列名
  get_custom_column_names <- reactive({
    names <- list()
    selected_cols <- user_selections$selected_cols
    
    for (col in selected_cols) {
      if (!is.null(user_selections$display_names[[col]])) {
        names[[col]] <- user_selections$display_names[[col]]
      } else {
        names[[col]] <- col
      }
    }
    return(names)
  })
  
  # 获取选中的表格列
  get_table_cols <- reactive({
    user_selections$selected_cols
  })
  
  # 智能文本换行函数
  smart_wrap_text <- function(text_vector, max_chars_per_line) {
    sapply(text_vector, function(text) {
      if (is.na(text) || text == "") return("")
      
      words <- str_split(text, " ")[[1]]
      lines <- character()
      current_line <- ""
      
      for (word in words) {
        if (current_line == "") {
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
          } else {
            current_line <- word
          }
        } else if (nchar(current_line) + 1 + nchar(word) <= max_chars_per_line) {
          current_line <- paste(current_line, word)
        } else {
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
            
            lines <- c(lines, current_line)
            current_line <- substr(word, 1, split_pos)
            remaining <- substr(word, split_pos + 1, nchar(word))
            if (remaining != "") {
              lines <- c(lines, current_line)
              current_line <- remaining
            }
          } else {
            lines <- c(lines, current_line)
            current_line <- word
          }
        }
      }
      
      if (current_line != "") {
        lines <- c(lines, current_line)
      }
      
      return(paste(lines, collapse = "\n"))
    }, USE.NAMES = FALSE)
  }
  
  # 处理换行文本函数
  process_line_breaks <- function(text) {
    if (is.null(text) || text == "") return("")
    # 将 "|" 替换为换行符
    gsub("\\|", "\n", text)
  }
  
  # 数据预览
  output$data_preview <- renderDT({
    req(data())
    
    datatable(data(), 
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
  
  # 处理数据，准备森林图
  processed_data <- reactive({
    req(data(), input$subgroup_col, input$study_col, 
        input$estimate_col, input$lower_col, input$upper_col)
    
    df <- data()
    
    # 检查必要列是否存在
    required_cols <- c(input$subgroup_col, input$study_col, 
                      input$estimate_col, input$lower_col, input$upper_col)
    missing_cols <- required_cols[!required_cols %in% names(df)]
    if (length(missing_cols) > 0) {
      showNotification(paste("缺少必要列:", paste(missing_cols, collapse = ", ")), 
                      type = "error")
      return(NULL)
    }
    
    # 转换数值列
    num_cols <- c(input$estimate_col, input$lower_col, input$upper_col)
    for (col in num_cols) {
      if (col %in% names(df)) {
        df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
      }
    }
    
    # 添加原始行ID以保持顺序
    df$original_row_id <- 1:nrow(df)
    
    # 计算y位置（从顶部到底部）
    df <- df %>% arrange(desc(original_row_id))
    df$y_pos <- 1:nrow(df)
    
    # 处理亚组
    df$subgroup_mapped <- as.character(df[[input$subgroup_col]])
    
    # 处理超出范围的值
    x_min_val <- ifelse(is.numeric(input$x_min), input$x_min, 0)
    x_max_val <- ifelse(is.numeric(input$x_max), input$x_max, 100)
    
    df$estimate_adj <- df[[input$estimate_col]]
    df$lower_adj <- df[[input$lower_col]]
    df$upper_adj <- df[[input$upper_col]]
    
    df$out_of_range_low <- df$lower_adj < x_min_val & !is.na(df$lower_adj)
    df$out_of_range_high <- df$upper_adj > x_max_val & !is.na(df$upper_adj)
    
    # 限制超出范围的值用于显示
    df$estimate_adj <- ifelse(df$estimate_adj < x_min_val, x_min_val, 
                             ifelse(df$estimate_adj > x_max_val, x_max_val, df$estimate_adj))
    df$lower_adj <- ifelse(df$lower_adj < x_min_val, x_min_val, df$lower_adj)
    df$upper_adj <- ifelse(df$upper_adj > x_max_val, x_max_val, df$upper_adj)
    
    # 设置背景颜色
    if (input$color_mode == "alternating") {
      # 按亚组交替颜色（而不是按行）
      # 获取唯一的亚组并保持顺序
      unique_subgroups <- unique(df$subgroup_mapped)
      # 创建亚组到颜色的映射：奇数亚组使用选定颜色，偶数亚组使用白色
      subgroup_colors <- setNames(
        ifelse(seq_along(unique_subgroups) %% 2 == 1, input$color_picker, "white"),
        unique_subgroups
      )
      # 将颜色映射到每一行
      df$bg_color <- subgroup_colors[df$subgroup_mapped]
    } else {
      # 随机亚组颜色
      subgroups <- unique(df$subgroup_mapped)
      colors <- brewer.pal(max(3, length(subgroups)), input$color_palette)
      subgroup_colors <- setNames(colors[1:length(subgroups)], subgroups)
      df$bg_color <- subgroup_colors[df$subgroup_mapped]
    }
    
    return(df)
  })
  
  # 动态设置图形高度
  output$plot_ui <- renderUI({
    plotOutput(ns("forest_plot"), height = paste0(input$display_height, "px"))
  })
  
  # 生成森林图
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
    
    # 1. 创建森林图形部分
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
        x = x_axis_label,
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
    
    # 2. 创建表格部分
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
  
  # 返回模块状态（可选）
  return(reactive({
    list(
      subgroup_col = input$subgroup_col,
      study_col = input$study_col,
      estimate_col = input$estimate_col,
      lower_col = input$lower_col,
      upper_col = input$upper_col
    )
  }))
}