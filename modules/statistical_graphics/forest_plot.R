# 森林图子模块 - 基于 sample_forest.r 重构（简化版）
# 只保留核心功能：列映射、表格配置、图形设置和文本自定义
# 数据从父模块传入，不包含数据上传和CSS

# 加载必要的包
library(shiny)
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
library(survival)

forest_plot_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      graphics_config_tabs_box(
        id = id,
        title = "森林图参数配置",
        collapsed = FALSE,
        tabs = list(
          tabPanel(
            "数据映射",
            br(),
            radioButtons(ns("data_mode"), "数据模式",
                         choices = c("预处理数据 (Pre-calculated)" = "precalculated",
                                     "原始数据分析 (Raw Data Analysis)" = "raw_data"),
                         selected = "precalculated", inline = TRUE),
            hr(),
            fluidRow(
              column(
                8,
                conditionalPanel(
                  condition = paste0("input['", ns("data_mode"), "'] == 'precalculated'"),
                  tags$div(class = "panel panel-default",
                           tags$div(class = "panel-heading", "数据列映射"),
                           tags$div(class = "panel-body",
                                    fluidRow(
                                      column(4, selectInput(ns("subgroup_col"), "变量名称列 (如: 性别)", choices = NULL, width = "100%")),
                                      column(4, selectInput(ns("study_col"), "分组值列 (如: 男/女)", choices = NULL, width = "100%")),
                                      column(4, selectInput(ns("estimate_col"), "估计值列 (HR/OR)", choices = NULL, width = "100%"))
                                    ),
                                    fluidRow(
                                      column(4, selectInput(ns("lower_col"), "下限列", choices = NULL, width = "100%")),
                                      column(4, selectInput(ns("upper_col"), "上限列", choices = NULL, width = "100%")),
                                      column(4, br(), helpText("总计5个必需列"))
                                    )))
                ),
                conditionalPanel(
                  condition = paste0("input['", ns("data_mode"), "'] == 'raw_data'"),
                  tags$div(class = "panel panel-primary",
                           tags$div(class = "panel-heading", "回归分析配置 (Cox / Logistic)"),
                           tags$div(class = "panel-body",
                                    radioButtons(ns("regression_type"), "回归模型类型",
                                                 choices = c("Cox 比例风险回归 (生存数据)" = "cox",
                                                             "Logistic 回归 (二分类结局)" = "logistic"),
                                                 selected = "cox", inline = TRUE),
                                    hr(),
                                    fluidRow(
                                      conditionalPanel(
                                        condition = paste0("input['", ns("regression_type"), "'] == 'cox'"),
                                        column(6, selectInput(ns("time_col"), "生存时间 (Time)", choices = NULL, width = "100%")),
                                        column(6, selectInput(ns("status_col"), "生存状态 (Status)", choices = NULL, width = "100%"))
                                      ),
                                      conditionalPanel(
                                        condition = paste0("input['", ns("regression_type"), "'] == 'logistic'"),
                                        column(12, selectInput(ns("outcome_col"), "结局变量 (Outcome, 0/1)", choices = NULL, width = "100%"))
                                      )
                                    ),
                                    selectizeInput(ns("covariates"), "分析变量 (Covariates)", choices = NULL, multiple = TRUE, width = "100%"),
                                    radioButtons(ns("analysis_method"), "分析方法",
                                                 choices = c("单因素分析 (Univariable)" = "univariate",
                                                             "多因素分析 (Multivariable)" = "multivariate"),
                                                 selected = "univariate", inline = TRUE),
                                    actionButton(ns("run_analysis"), "运行分析", class = "btn-info btn-block", icon = icon("calculator"))))
                )
              ),
              column(
                4,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "表格显示设置"),
                         tags$div(class = "panel-body",
                                  helpText("选择要在表格中显示的列（第一列将作为固定列）"),
                                  selectizeInput(
                                    ns("selected_table_cols"),
                                    label = NULL,
                                    choices = NULL,
                                    multiple = TRUE,
                                    options = list(
                                      placeholder = "点击选择表格列...",
                                      onInitialize = I("function() { this.setValue(''); }")
                                    )
                                  ),
                                  hr(),
                                  tags$div(class = "panel panel-default",
                                           tags$div(class = "panel-heading", style = "cursor: pointer;", "列显示配置（点击展开）"),
                                           tags$div(class = "panel-body", style = "padding: 10px;",
                                                    uiOutput(ns("column_config_ui"))))))
              )
            )
          ),
          tabPanel(
            "样式主题",
            br(),
            fluidRow(
              column(
                3,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "尺寸与显示"),
                  tags$div(
                    class = "panel-body",
                    sliderInput(ns("plot_ratio"), "表格/图形宽度比", min = 0.3, max = 0.7, value = 0.55, step = 0.05, width = "100%"),
                    helpText("画布尺寸、页面距与导出设置已统一移动到“输出与导出”页签。")
                  )
                )
              ),
              column(
                3,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "坐标与线条"),
                  tags$div(
                    class = "panel-body",
                    graphics_axis_range_controls_ui(
                      ns,
                      min_id = "x_min",
                      max_id = "x_max",
                      axis_label = "X轴",
                      min_value = 0,
                      max_value = 100,
                      min_step = 1,
                      max_step = 1
                    ),
                    graphics_reference_line_ui(
                      ns,
                      "ref_line",
                      label = "参考线",
                      default_value = 1,
                      default_color = "#1A1A1A",
                      default_linetype = "solid",
                      default_linewidth = 0.8
                    ),
                    sliderInput(ns("line_width"), "线条粗细", min = 0.5, max = 3, value = 1.2, step = 0.1, width = "100%"),
                    sliderInput(ns("line_height"), "短线长度", min = 0.05, max = 0.3, value = 0.15, step = 0.01, width = "100%"),
                    graphics_axis_tick_format_controls_ui(
                      ns,
                      decimals_id = "x_axis_decimals",
                      decimals_label = "X轴小数位数",
                      decimals_value = 1,
                      percent_id = "percentage_format",
                      percent_label = "显示百分号(%)",
                      percent_value = FALSE
                    )
                  )
                )
              )
              ,
              column(
                3,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "表格与配色"),
                  tags$div(
                    class = "panel-body",
                    sliderInput(ns("table_font_size"), "表格字体大小", min = 2, max = 5, value = 3.0, step = 0.1, width = "100%"),
                    sliderInput(ns("header_font_size"), "表头字体大小", min = 2.5, max = 6, value = 3.5, step = 0.1, width = "100%"),
                    numericInput(ns("first_col_width"), "第一列宽度比例", min = 0.1, max = 0.5, value = 0.45, step = 0.05, width = "100%"),
                    numericInput(ns("max_chars_per_line"), "第一列每行最大字符数", min = 5, max = 30, value = 45, step = 1, width = "100%"),
                    hr(),
                    radioButtons(ns("color_mode"), "颜色模式", choices = c("交替颜色" = "alternating", "随机亚组颜色" = "random_subgroup"), selected = "alternating", inline = TRUE),
                    conditionalPanel(
                      condition = paste0("input['", ns("color_mode"), "'] == 'alternating'"),
                      colourInput(ns("color_picker"), "选择交替颜色", value = "#E6F3FF", width = "100%"),
                      sliderInput(ns("alpha"), "颜色透明度", min = 0.1, max = 1, value = 0.4, step = 0.1, width = "100%")
                    ),
                    conditionalPanel(
                      condition = paste0("input['", ns("color_mode"), "'] == 'random_subgroup'"),
                      selectInput(ns("color_palette"), "颜色调色板", choices = c("Set1", "Set2", "Set3", "Pastel1", "Pastel2", "Dark2", "Accent", "Paired", "Spectral"), selected = "Set1", width = "100%"),
                      sliderInput(ns("subgroup_alpha"), "颜色透明度", min = 0.1, max = 1, value = 0.7, step = 0.1, width = "100%")
                    ),
                    helpText("交替颜色模式：奇数亚组使用选择的颜色，偶数亚组使用白色"),
                    helpText("随机亚组颜色模式：每个亚组使用不同的随机颜色")
                  )
                )
              ),
              column(
                3,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "文本与脚注"),
                  tags$div(
                    class = "panel-body",
                    fluidRow(
                      column(6, textInput(ns("plot_title"), "图形标题", value = "交互式森林图", placeholder = "输入图形标题", width = "100%")),
                      column(6, textInput(ns("x_axis_label"), "X轴标签", value = "风险比", placeholder = "输入X轴标签", width = "100%"))
                    ),
                    tags$div(class = "info-text", "提示：使用\"|\"符号表示换行，例如：\"主标题|副标题\""),
                    fluidRow(
                      column(6, numericInput(ns("title_size"), "标题字体大小", min = 10, max = 24, value = 16, step = 1, width = "100%")),
                      column(6, numericInput(ns("axis_label_size"), "轴标签字体大小", min = 8, max = 16, value = 12, step = 1, width = "100%"))
                    ),
                    hr(),
                    textAreaInput(ns("plot_footer"), "图形脚注", value = "注: 点大小反映研究权重, 区间线表示95%置信区间. | 参考线位于HR=1.0处.", placeholder = "输入图形脚注", rows = 3, width = "100%"),
                    fluidRow(
                      column(6, numericInput(ns("footer_size"), "脚注字体大小", min = 6, max = 14, value = 10, step = 1, width = "100%")),
                      column(6, colourInput(ns("footer_color"), "脚注颜色", value = "gray40", width = "100%"))
                    ),
                    checkboxInput(ns("show_footer"), "显示脚注", value = TRUE)
                  )
                )
              )
            )
          ),
          tabPanel(
            "输出与导出",
            br(),
            graphics_export_size_controls_ui(ns, download_id = "download_plot", include_size_mode = TRUE, include_download_button = FALSE)
          )
        )
      )
    ),
    
    # 图形显示区域 - 底部
    fluidRow(
      box(
        width = 12,
        title = "森林图输出",
        status = "success",
        solidHeader = TRUE,
        fluidRow(
          column(6, div(style = "text-align: left; margin-bottom: 10px;", actionButton(ns("generate"), "生成图形", class = "btn-primary"))),
          column(6, div(style = "text-align: right; margin-bottom: 10px;", downloadButton(ns("download_plot"), "下载图形", class = "btn-primary")))
        ),
        tabsetPanel(
          id = ns("output_tabs"),
          tabPanel("森林图",
                   div(style = "height: 10px;"),
                   uiOutput(ns("plot_ui")),
                   div(style = "height: 10px;")
          ),
          tabPanel("数据预览",
                   div(style = "height: 10px;"),
                   DTOutput(ns("data_preview"))
          ),
          tabPanel("统计报告",
                   div(style = "height: 10px;"),
                   uiOutput(ns("analysis_report_ui"))
          )
        )
      )
    )
  )
}

forest_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  size_config <- reactive({
    graphics_collect_size_config(
      input,
      defaults = list(
        static_width = 1200,
        static_height = 800,
        interactive_width = 1200,
        interactive_height = 800,
        export_width = graphics_px_to_in(1200, 96),
        export_height = graphics_px_to_in(800, 96),
        sync_ppi = 96,
        page_margin_top = 24,
        page_margin_right = 24,
        page_margin_bottom = 24,
        page_margin_left = 24,
        canvas_border = TRUE,
        canvas_border_color = "#D9D9D9",
        canvas_border_size = 0.8,
        canvas_background = "white"
      )
    )
  })
  
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
  
  # 智能数值格式化函数
  smart_format_number <- function(x, max_digits = 4) {
    sapply(x, function(val) {
      if (is.na(val)) return("")
      
      num_val <- suppressWarnings(as.numeric(val))
      if (is.na(num_val)) return(val) # 非数值直接返回
      
      abs_val <- abs(num_val)
      
      if (abs_val == 0) return("0")
      
      if (abs_val < 0.0001) {
        return(formatC(num_val, format = "e", digits = 2))
      } else if (abs_val < 0.001) {
        return(sprintf("%.4f", num_val))
      } else if (abs_val < 0.01) {
        return(sprintf("%.3f", num_val))
      } else if (abs_val < 1) {
        return(sprintf("%.2f", num_val)) # 或者 3 位
      } else if (abs_val < 10) {
        return(sprintf("%.2f", num_val))
      } else if (abs_val < 100) {
        return(sprintf("%.1f", num_val))
      } else {
        return(sprintf("%.0f", num_val))
      }
    })
  }

  # 观察数据变化，更新列选择
  observe({
    req(data())
    
    cols <- names(data())
    if (length(cols) == 0) return()
    
    # 获取当前选择的值，如果有效则保留
    cur_subgroup <- isolate(input$subgroup_col)
    sel_subgroup <- if (!is.null(cur_subgroup) && cur_subgroup %in% cols) cur_subgroup else ifelse("subgroup" %in% cols, "subgroup", cols[1])
    
    cur_study <- isolate(input$study_col)
    sel_study <- if (!is.null(cur_study) && cur_study %in% cols) cur_study else ifelse("study" %in% cols, "study", ifelse(length(cols) > 1, cols[2], cols[1]))
    
    cur_est <- isolate(input$estimate_col)
    sel_est <- if (!is.null(cur_est) && cur_est %in% cols) cur_est else ifelse("estimate" %in% cols, "estimate", ifelse(length(cols) > 2, cols[3], cols[1]))
    
    cur_lower <- isolate(input$lower_col)
    sel_lower <- if (!is.null(cur_lower) && cur_lower %in% cols) cur_lower else ifelse("lower" %in% cols, "lower", ifelse(length(cols) > 3, cols[4], cols[1]))
    
    cur_upper <- isolate(input$upper_col)
    sel_upper <- if (!is.null(cur_upper) && cur_upper %in% cols) cur_upper else ifelse("upper" %in% cols, "upper", ifelse(length(cols) > 4, cols[5], cols[1]))
    
    # 更新列映射选择框 (预处理模式)
    updateSelectInput(session, "subgroup_col", choices = cols, selected = sel_subgroup)
    updateSelectInput(session, "study_col", choices = cols, selected = sel_study)
    updateSelectInput(session, "estimate_col", choices = cols, selected = sel_est)
    updateSelectInput(session, "lower_col", choices = cols, selected = sel_lower)
    updateSelectInput(session, "upper_col", choices = cols, selected = sel_upper)
    
    # 更新分析配置选项 (原始数据模式)
    # 尝试智能识别 Time 和 Status
    time_candidates <- cols[grep("time|dur|os|pfs|rfs", tolower(cols))]
    status_candidates <- cols[grep("status|event|dead|death|censor", tolower(cols))]
    outcome_candidates <- cols[grep("response|outcome|recurrence|disease|event|status", tolower(cols))]
    
    cur_time <- isolate(input$time_col)
    sel_time <- if (!is.null(cur_time) && cur_time %in% cols) cur_time else if(length(time_candidates)>0) time_candidates[1] else cols[1]
    
    cur_status <- isolate(input$status_col)
    sel_status <- if (!is.null(cur_status) && cur_status %in% cols) cur_status else if(length(status_candidates)>0) status_candidates[1] else cols[2]
    
    cur_outcome <- isolate(input$outcome_col)
    sel_outcome <- if (!is.null(cur_outcome) && cur_outcome %in% cols) cur_outcome else if(length(outcome_candidates)>0) outcome_candidates[1] else cols[1]
    
    updateSelectInput(session, "time_col", choices = cols, selected = sel_time)
    updateSelectInput(session, "status_col", choices = cols, selected = sel_status)
    updateSelectInput(session, "outcome_col", choices = cols, selected = sel_outcome)
    updateSelectizeInput(session, "covariates", choices = cols, server = TRUE)

    # 不预设任何列，用户需手动选择
    if (length(user_selections$selected_cols) == 0) {
      user_selections$selected_cols <- character(0)
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
  
  # 当数据变化时更新selectizeInput的选项（不自动选择任何列）
  observe({
    req(data())
    cols <- names(data())
    if (length(cols) == 0) return()
    
    # 获取当前选择
    current_selected <- isolate(user_selections$selected_cols)
    # 过滤掉不存在于新数据中的已选列
    valid_selected <- intersect(current_selected, cols)
    
    # 如果有效选择与当前存储的选择不同，更新reactiveValues
    if (!identical(sort(valid_selected), sort(current_selected))) {
      user_selections$selected_cols <- valid_selected
    }
    
    # 更新selectizeInput的选项，不触发额外事件
    isolate({
      updateSelectizeInput(session, "selected_table_cols",
                           choices = cols,
                           selected = valid_selected,
                           server = TRUE)
    })
  })
  
  # 观察用户从selectizeInput中选择的变化，并在更新前保存当前配置
  observe({
    selected_cols <- input$selected_table_cols
    if (is.null(selected_cols)) selected_cols <- character(0)
    
    # 防止循环：只有当选择实际发生变化时才更新reactiveValues
    current <- isolate(user_selections$selected_cols)
    if (!identical(sort(selected_cols), sort(current))) {
      # 在更新selected_cols之前，保存当前所有列的配置
      for (col in current) {
        name_input <- paste0("name_", col)
        align_input <- paste0("align_", col)
        
        # 如果输入存在，保存其值
        if (!is.null(input[[name_input]]) && input[[name_input]] != "") {
          user_selections$display_names[[col]] <- input[[name_input]]
        }
        if (!is.null(input[[align_input]])) {
          user_selections$alignments[[col]] <- input[[align_input]]
        }
      }
      
      # 更新选中的列
      user_selections$selected_cols <- selected_cols
    }
  })
  
  # 生成列配置UI
  output$column_config_ui <- renderUI({
    selected_cols <- user_selections$selected_cols
    if (length(selected_cols) == 0) {
      return(tags$p("请先选择要显示的列"))
    }
    
    # 隔离对 display_names 和 alignments 的依赖，避免输入时不断重新渲染UI导致失焦跳出
    display_names <- isolate(user_selections$display_names)
    alignments <- isolate(user_selections$alignments)
    
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
                       value = ifelse(!is.null(display_names[[col]]), 
                                      display_names[[col]], col)
                     )
                   ),
                   column(
                     4,
                     selectInput(
                       inputId = ns(paste0("align_", col)),
                       label = NULL,
                       choices = c("左对齐" = "left", "居中" = "center", "右对齐" = "right"),
                       selected = ifelse(!is.null(alignments[[col]]), 
                                         alignments[[col]], 
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
    # 根据模式显示不同的数据
    if (input$data_mode == "raw_data") {
      # 如果有分析结果，优先显示分析结果
      if (input$run_analysis > 0) {
         res <- analysis_results()
         if (!is.null(res)) return(datatable(res, options = list(pageLength = 10, scrollX = TRUE)))
      }
      # 否则显示原始数据
      req(data())
      datatable(data(), options = list(pageLength = 10, scrollX = TRUE))
    } else {
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
    }
  })
  
  # ---------------------------------------------------------
  # 新增：统计报告生成逻辑
  # ---------------------------------------------------------
  output$analysis_report_ui <- renderUI({
    if (input$data_mode != "raw_data") {
      return(tags$div(
        class = "alert alert-info",
        "统计报告仅适用于'原始数据分析模式'。当前为'预处理数据模式'，无统计计算过程。"
      ))
    }
    
    if (input$run_analysis == 0 || is.null(analysis_results())) {
      return(tags$div(
        class = "alert alert-warning",
        "请先在左侧配置并运行回归分析，以生成统计报告。"
      ))
    }
    
    res <- analysis_results()
    reg_type <- input$regression_type
    method <- input$analysis_method
    
    # 1. 方法描述
    method_title <- ""
    method_desc <- ""
    
    if (reg_type == "cox") {
      method_title <- "Cox 比例风险回归模型 (Cox Proportional Hazards Model)"
      if (method == "univariate") {
        method_desc <- paste(
          "本分析采用**单因素 Cox 比例风险回归模型**，旨在单独评估每个变量对生存时间的影响。",
          "该方法假设变量的影响随时间保持恒定（比例风险假设）。",
          "结果以风险比 (Hazard Ratio, HR) 及其 95% 置信区间 (95% CI) 表示。",
          "HR > 1 表示该变量水平相对于参考水平增加了风险（如死亡风险），HR < 1 表示降低了风险。"
        )
      } else {
        method_desc <- paste(
          "本分析采用**多因素 Cox 比例风险回归模型**，旨在评估各变量在调整其他协变量影响后的独立预后价值。",
          "该模型同时纳入多个变量，能够校正混杂因素的影响。",
          "结果以调整后的风险比 (Adjusted Hazard Ratio, HR) 及其 95% 置信区间 (95% CI) 表示。",
          "显著的 P 值 (< 0.05) 表明该变量是独立的预后因子。"
        )
      }
    } else {
      method_title <- "Logistic 回归模型 (Logistic Regression Model)"
      if (method == "univariate") {
        method_desc <- paste(
          "本分析采用**单因素 Logistic 回归模型**，旨在单独评估每个变量对结局事件（二分类）发生概率的影响。",
          "结果以比值比 (Odds Ratio, OR) 及其 95% 置信区间 (95% CI) 表示。",
          "OR > 1 表示该变量水平相对于参考水平增加了事件发生的概率，OR < 1 表示降低了概率。"
        )
      } else {
        method_desc <- paste(
          "本分析采用**多因素 Logistic 回归模型**，旨在评估各变量在调整其他协变量影响后的独立预测价值。",
          "该模型能够校正混杂因素，识别影响结局发生的独立危险因素或保护因素。",
          "结果以调整后的比值比 (Adjusted Odds Ratio, OR) 及其 95% 置信区间 (95% CI) 表示。"
        )
      }
    }
    
    # 2. 结果解释
    interpretations <- list()
    
    # 筛选显著结果 (P < 0.05)
    sig_res <- res[!is.na(res$P_Value) & res$P_Value < 0.05, ]
    
    if (nrow(sig_res) == 0) {
      interpretations <- list("在当前的分析中，未发现 P 值小于 0.05 的显著变量。这可能意味着所选变量与结局之间没有强统计学关联，或者样本量不足以检测到这种关联。")
    } else {
      for (i in 1:nrow(sig_res)) {
        row <- sig_res[i, ]
        var_name <- row$Variable
        level_name <- row$Level
        est <- as.numeric(row$Estimate)
        lower <- as.numeric(row$Lower)
        upper <- as.numeric(row$Upper)
        p_val <- row$P_Value_Str
        
        effect_direction <- ifelse(est > 1, "增加", "降低")
        effect_metric <- ifelse(reg_type == "cox", "风险 (Hazard)", "发生概率 (Odds)")
        
        # 构建单条解释
        if (level_name == "Continuous") {
          interp <- sprintf(
            "变量 **%s** 是显著的影响因素 (P = %s)。随着 %s 每增加一个单位，结局%s将%s %.2f 倍 (95%% CI: %.2f - %.2f)。",
            var_name, p_val, var_name, effect_metric, effect_direction, est, lower, upper
          )
        } else {
          interp <- sprintf(
            "变量 **%s** 的 **%s** 水平相对于参考水平显示出统计学差异 (P = %s)。该组群的结局%s是参考组的 %.2f 倍 (95%% CI: %.2f - %.2f)，表现为显著%s。",
            var_name, level_name, p_val, effect_metric, est, lower, upper, effect_direction
          )
        }
        interpretations[[length(interpretations) + 1]] <- interp
      }
    }
    
    # 构建 HTML 输出
    tagList(
      tags$div(
        style = "padding: 20px; background-color: #f8f9fa; border-radius: 5px; border: 1px solid #e9ecef;",
        h3(icon("book"), "统计分析报告", style = "color: #2c3e50; margin-top: 0; border-bottom: 2px solid #3498db; padding-bottom: 10px;"),
        
        h4(icon("cogs"), "1. 分析方法描述", style = "color: #2980b9; margin-top: 20px;"),
        tags$div(
          style = "padding: 15px; background-color: white; border-left: 4px solid #3498db; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
          strong(method_title),
          p(style = "margin-top: 10px; line-height: 1.6; color: #555;", HTML(method_desc))
        ),
        
        h4(icon("chart-line"), "2. 结果统计解释 (P < 0.05)", style = "color: #2980b9; margin-top: 25px;"),
        tags$div(
          style = "padding: 15px; background-color: white; border-left: 4px solid #27ae60; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
          if (length(interpretations) > 0) {
            tags$ul(
              style = "padding-left: 20px; margin-bottom: 0;",
              lapply(interpretations, function(txt) {
                tags$li(style = "margin-bottom: 10px; line-height: 1.6; color: #333;", HTML(txt))
              })
            )
          } else {
            p("无显著结果。")
          }
        ),
        
        tags$div(
          style = "margin-top: 30px; font-size: 0.9em; color: #7f8c8d; text-align: center; border-top: 1px solid #ddd; padding-top: 10px;",
          "注：本报告由系统自动生成，仅供参考。临床决策请结合专业医学知识。"
        )
      )
    )
  })
  
  # ---------------------------------------------------------
  # 新增：回归分析逻辑 (Cox & Logistic)
  # ---------------------------------------------------------
  analysis_results <- eventReactive(input$run_analysis, {
    req(data(), input$covariates)
    
    df <- data()
    reg_type <- input$regression_type
    method <- input$analysis_method
    covariates <- input$covariates
    
    if (reg_type == "cox") {
      req(input$time_col, input$status_col)
      time_var <- input$time_col
      status_var <- input$status_col
      
      # 确保时间数值化
      df[[time_var]] <- as.numeric(df[[time_var]])
      # 确保状态数值化 (0/1)
      if (is.character(df[[status_var]]) || is.factor(df[[status_var]])) {
        lvls <- levels(as.factor(df[[status_var]]))
        if (length(lvls) == 2) {
          df[[status_var]] <- as.numeric(as.factor(df[[status_var]])) - 1
        }
      }
      df[[status_var]] <- as.numeric(df[[status_var]])
      
    } else {
      # Logistic Regression
      req(input$outcome_col)
      outcome_var <- input$outcome_col
      
      # 确保结局变量数值化 (0/1)
      if (is.character(df[[outcome_var]]) || is.factor(df[[outcome_var]])) {
        lvls <- levels(as.factor(df[[outcome_var]]))
        if (length(lvls) == 2) {
          df[[outcome_var]] <- as.numeric(as.factor(df[[outcome_var]])) - 1
        }
      }
      df[[outcome_var]] <- as.numeric(df[[outcome_var]])
    }

    # 定义通用的提取函数
    extract_model_res <- function(model, var, data, type = "cox") {
      if (inherits(model, "try-error")) return(NULL)
      
      summ <- summary(model)
      coefs <- summ$coefficients
      
      if (type == "cox") {
        conf <- summ$conf.int
        p_idx <- "Pr(>|z|)"
        est_col <- "exp(coef)"
        low_col <- "lower .95"
        upp_col <- "upper .95"
      } else {
        # Logistic (glm)
        # summary(glm) does not have conf.int directly
        # Need to calculate
        est <- coef(model)
        se <- coefs[, "Std. Error"]
        z_val <- coefs[, "z value"]
        p_val <- coefs[, "Pr(>|z|)"]
        
        # Calculate OR and CI
        or <- exp(est)
        ci_low <- exp(est - 1.96 * se)
        ci_high <- exp(est + 1.96 * se)
        
        # Construct a conf matrix like structure for easier indexing
        conf <- cbind(or, ci_low, ci_high)
        colnames(conf) <- c("OR", "2.5 %", "97.5 %")
        
        p_idx <- "Pr(>|z|)"
      }
      
      is_cat <- is.factor(data[[var]]) || is.character(data[[var]])
      
      if (is_cat) {
        lvls <- levels(as.factor(data[[var]]))
        n_lvls <- length(lvls)
        
        res <- data.frame(
          Variable = rep(var, n_lvls),
          Level = lvls,
          Estimate = NA,
          Lower = NA,
          Upper = NA,
          P_Value = NA,
          N = NA,
          Events = NA,
          stringsAsFactors = FALSE
        )
        
        # Reference level
        res$Estimate[1] <- 1.0
        
        # Other levels
        for (i in 2:n_lvls) {
          lvl <- lvls[i]
          term_pattern <- paste0(var, lvl) 
          
          if (type == "cox") {
             idx <- which(rownames(coefs) == term_pattern)
             if (length(idx) == 0) idx <- grep(paste0(var, ".*", lvl), rownames(coefs))
             
             if (length(idx) > 0) {
               idx <- idx[1]
               res$Estimate[i] <- conf[idx, est_col]
               res$Lower[i] <- conf[idx, low_col]
               res$Upper[i] <- conf[idx, upp_col]
               res$P_Value[i] <- coefs[idx, p_idx]
             }
          } else {
             # Logistic
             idx <- which(names(est) == term_pattern)
             if (length(idx) == 0) idx <- grep(paste0(var, ".*", lvl), names(est))
             
             if (length(idx) > 0) {
               idx <- idx[1]
               res$Estimate[i] <- or[idx]
               res$Lower[i] <- ci_low[idx]
               res$Upper[i] <- ci_high[idx]
               res$P_Value[i] <- p_val[idx]
             }
          }
        }
        
        # N & Events
        for (i in 1:n_lvls) {
          sub <- data[data[[var]] == lvls[i], ]
          res$N[i] <- nrow(sub)
          if (type == "cox") {
            res$Events[i] <- sum(sub[[status_var]] == 1, na.rm = TRUE)
          } else {
            res$Events[i] <- sum(sub[[outcome_var]] == 1, na.rm = TRUE)
          }
        }
        
      } else {
        # Continuous
        res <- data.frame(
          Variable = var,
          Level = "Continuous",
          Estimate = NA, Lower = NA, Upper = NA, P_Value = NA, N = NA, Events = NA,
          stringsAsFactors = FALSE
        )
        
        if (type == "cox") {
          idx <- which(rownames(coefs) == var)
          if (length(idx) > 0) {
            res$Estimate <- conf[idx, est_col]
            res$Lower <- conf[idx, low_col]
            res$Upper <- conf[idx, upp_col]
            res$P_Value <- coefs[idx, p_idx]
          }
          res$N <- nrow(data[!is.na(data[[var]]), ])
          res$Events <- sum(data[!is.na(data[[var]]), ][[status_var]] == 1, na.rm = TRUE)
        } else {
          idx <- which(names(est) == var)
          if (length(idx) > 0) {
            res$Estimate <- or[idx]
            res$Lower <- ci_low[idx]
            res$Upper <- ci_high[idx]
            res$P_Value <- p_val[idx]
          }
          res$N <- nrow(data[!is.na(data[[var]]), ])
          res$Events <- sum(data[!is.na(data[[var]]), ][[outcome_var]] == 1, na.rm = TRUE)
        }
      }
      return(res)
    }
    
    final_list <- list()
    
    if (method == "univariate") {
      for (cov in covariates) {
        if (reg_type == "cox") {
          f <- as.formula(paste("Surv(", time_var, ",", status_var, ") ~", cov))
          fit <- try(coxph(f, data = df), silent = TRUE)
          res <- extract_model_res(fit, cov, df, type = "cox")
        } else {
          f <- as.formula(paste(outcome_var, "~", cov))
          fit <- try(glm(f, data = df, family = binomial), silent = TRUE)
          res <- extract_model_res(fit, cov, df, type = "logistic")
        }
        if (!is.null(res)) final_list[[cov]] <- res
      }
    } else {
      # Multivariate
      if (reg_type == "cox") {
        f <- as.formula(paste("Surv(", time_var, ",", status_var, ") ~", paste(covariates, collapse = "+")))
        fit <- try(coxph(f, data = df), silent = TRUE)
        for (cov in covariates) {
          res <- extract_model_res(fit, cov, df, type = "cox")
          if (!is.null(res)) final_list[[cov]] <- res
        }
      } else {
        f <- as.formula(paste(outcome_var, "~", paste(covariates, collapse = "+")))
        fit <- try(glm(f, data = df, family = binomial), silent = TRUE)
        for (cov in covariates) {
          res <- extract_model_res(fit, cov, df, type = "logistic")
          if (!is.null(res)) final_list[[cov]] <- res
        }
      }
    }
    
    if (length(final_list) > 0) {
      out <- do.call(rbind, final_list)
      # 格式化 P 值 (保留用于显示，但保留原始值用于排序/逻辑)
      out$P_Value_Raw <- out$P_Value
      out$P_Value_Str <- ifelse(is.na(out$P_Value), "", 
                                ifelse(out$P_Value < 0.001, "<0.001", sprintf("%.3f", out$P_Value)))
      return(out)
    } else {
      showNotification("分析未产生有效结果，请检查数据", type = "warning")
      return(NULL)
    }
  })
  
  # 分析完成后，自动更新表格显示的列
  observeEvent(analysis_results(), {
    res <- analysis_results()
    if (!is.null(res)) {
       new_cols <- c("Variable", "Level", "N", "Events", "P_Value_Str", "Estimate", "Lower", "Upper")
       valid_cols <- intersect(new_cols, names(res))
       
       user_selections$selected_cols <- valid_cols
       updateSelectizeInput(session, "selected_table_cols", choices = names(res), selected = valid_cols)
       
       user_selections$alignments[["Variable"]] <- "left"
       user_selections$alignments[["Level"]] <- "center"
       user_selections$alignments[["Estimate"]] <- "center"
       
       # 自动调整 X 轴范围
       valid_est <- res[!is.na(res$Estimate) & !is.na(res$Lower) & !is.na(res$Upper), ]
       if (nrow(valid_est) > 0) {
         # 排除极值
         min_val <- min(valid_est$Lower[valid_est$Lower > 0.01], na.rm = TRUE)
         max_val <- max(valid_est$Upper[valid_est$Upper < 100], na.rm = TRUE)
         
         # 稍微放宽一点
         min_val <- floor(min_val * 0.9)
         max_val <- ceiling(max_val * 1.1)
         
         updateNumericInput(session, "x_min", value = min_val)
         updateNumericInput(session, "x_max", value = max_val)
       }
    }
  })

  # 处理数据，准备森林图
  processed_data <- reactive({
    
    if (input$data_mode == "precalculated") {
      # 原有逻辑：预处理数据
      req(data(), input$subgroup_col, input$study_col, 
          input$estimate_col, input$lower_col, input$upper_col)
      
      df <- data()
      
      # 映射列名
      cols_map <- list(
        subgroup = input$subgroup_col,
        study = input$study_col,
        estimate = input$estimate_col,
        lower = input$lower_col,
        upper = input$upper_col
      )
      
    } else {
      # 新逻辑：原始数据分析
      req(analysis_results())
      df <- analysis_results()
      
      # 硬编码映射列名 (分析结果的固定列名)
      cols_map <- list(
        subgroup = "Variable",
        study = "Level",
        estimate = "Estimate",
        lower = "Lower",
        upper = "Upper"
      )
    }
    
    # 检查必要列是否存在
    required_cols <- unlist(cols_map)
    missing_cols <- required_cols[!required_cols %in% names(df)]
    if (length(missing_cols) > 0) {
      # 仅在预处理模式下报错，因为分析模式下如果列不对是代码逻辑问题
      if (input$data_mode == "precalculated") {
         showNotification(paste("缺少必要列:", paste(missing_cols, collapse = ", ")), type = "error")
      }
      return(NULL)
    }
    
    # 转换数值列
    num_cols <- c(cols_map$estimate, cols_map$lower, cols_map$upper)
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
    df$subgroup_mapped <- as.character(df[[cols_map$subgroup]])
    
    # 处理超出范围的值
    x_min_val <- ifelse(is.numeric(input$x_min), input$x_min, 0)
    x_max_val <- ifelse(is.numeric(input$x_max), input$x_max, 100)
    
    df$estimate_adj <- df[[cols_map$estimate]]
    df$lower_adj <- df[[cols_map$lower]]
    df$upper_adj <- df[[cols_map$upper]]
    
    df$out_of_range_low <- df$lower_adj < x_min_val & !is.na(df$lower_adj)
    df$out_of_range_high <- df$upper_adj > x_max_val & !is.na(df$upper_adj)
    
    # 限制超出范围的值用于显示
    df$estimate_adj <- ifelse(df$estimate_adj < x_min_val, x_min_val, 
                             ifelse(df$estimate_adj > x_max_val, x_max_val, df$estimate_adj))
    df$lower_adj <- ifelse(df$lower_adj < x_min_val, x_min_val, df$lower_adj)
    df$upper_adj <- ifelse(df$upper_adj > x_max_val, x_max_val, df$upper_adj)
    
    # 设置背景颜色
    if (input$color_mode == "alternating") {
      unique_subgroups <- unique(df$subgroup_mapped)
      subgroup_colors <- setNames(
        ifelse(seq_along(unique_subgroups) %% 2 == 1, input$color_picker, "white"),
        unique_subgroups
      )
      df$bg_color <- subgroup_colors[df$subgroup_mapped]
    } else {
      subgroups <- unique(df$subgroup_mapped)
      colors <- brewer.pal(max(3, length(subgroups)), input$color_palette)
      subgroup_colors <- setNames(colors[1:length(subgroups)], subgroups)
      df$bg_color <- subgroup_colors[df$subgroup_mapped]
    }
    
    return(df)
  })

  
  # 动态设置图形高度
  output$plot_ui <- renderUI({
    cfg <- size_config()
    graphics_centered_output_container(
      plotOutput(ns("forest_plot"), height = paste0(cfg$static_height, "px"), width = "100%"),
      frame_width_px = cfg$static_width,
      frame_height_px = cfg$static_height
    )
  })
  
  # 生成森林图
  forest_plot_reactive <- eventReactive(input$generate, {
    req(processed_data())
    
    data <- processed_data()
    x_min <- input$x_min
    x_max <- input$x_max
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
    
    x_breaks <- pretty(c(x_min, x_max), n = 10)
    x_breaks <- x_breaks[x_breaks >= x_min & x_breaks <= x_max]
    if(length(x_breaks) < 2) x_breaks <- seq(x_min, x_max, length.out = 5)
    
    decimals <- if (is.null(input$x_axis_decimals)) 1 else input$x_axis_decimals
    
    if (isTRUE(input$percentage_format)) {
      fmt <- paste0("%.", decimals, "f%%")
      x_labels <- sprintf(fmt, x_breaks * 100)
    } else {
      fmt <- paste0("%.", decimals, "f")
      x_labels <- sprintf(fmt, x_breaks)
    }
    
    ref_line_spec <- graphics_collect_reference_line_spec(
      input,
      id_prefix = "ref_line",
      orientation = "v",
      fallback_value = 1,
      fallback_color = "#1A1A1A",
      fallback_linetype = "solid",
      fallback_linewidth = 0.8
    )
    
    # 1. 创建森林图形部分
    forest_plot <- ggplot(data, aes(x = estimate_adj, y = y_pos)) +
      geom_rect(aes(xmin = x_min, xmax = x_max, 
                    ymin = y_pos - 0.45, ymax = y_pos + 0.45,
                    fill = bg_color), alpha = alpha) +
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
      theme_minimal(base_size = 12, base_family = "sans") +
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
    forest_plot <- graphics_add_reference_lines(forest_plot, list(ref_line_spec))
    
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
          
          # 对数值列应用智能格式化
          # 检查是否为数值列 (Estimate, Lower, Upper, P_Value等)
          # 注意：在 raw_data 模式下，P_Value_Str 已经是格式化好的字符串，不需要再次格式化
          # 这里主要针对 Estimate, Lower, Upper 或者用户传入的原始数值
          
          is_numeric_col <- FALSE
          if (input$data_mode == "raw_data") {
             if (col_name %in% c("Estimate", "Lower", "Upper", "HR", "OR")) is_numeric_col <- TRUE
          } else {
             if (col_name %in% c(input$estimate_col, input$lower_col, input$upper_col)) is_numeric_col <- TRUE
          }
          
          if (is_numeric_col) {
             # 尝试转换为数值并格式化
             # 先暂时保留 NA/空值处理逻辑
             col_values_formatted <- sapply(col_values, function(v) {
                if (is.na(v) || v == "" || v == "NA") return(v)
                # 尝试转数字
                num <- suppressWarnings(as.numeric(v))
                if (!is.na(num)) {
                   # 应用智能格式化
                   if (abs(num) < 0.0001 && abs(num) > 0) return(formatC(num, format = "e", digits = 2))
                   if (abs(num) >= 100) return(sprintf("%.1f", num))
                   if (abs(num) >= 10) return(sprintf("%.2f", num))
                   if (abs(num) >= 1) return(sprintf("%.2f", num))
                   if (abs(num) >= 0.001) return(sprintf("%.3f", num))
                   return(sprintf("%.4f", num))
                }
                return(v)
             })
             col_values <- col_values_formatted
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
                    fontface = "bold", size = header_font_size, family = "sans")
        
        # 添加列内容
        table_plot <- table_plot +
          geom_text(aes_string(x = adjusted_x_pos, y = "y_pos",
                               label = paste0("table_col_", i)),
                    hjust = hjust_val, vjust = 0.5, size = table_font_size, family = "sans",
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
      cfg <- size_config()
      graphics_apply_canvas_frame(
        plot_obj,
        frame_width_px = cfg$static_width,
        frame_height_px = cfg$static_height,
        canvas_config = cfg
      )
    }
  }, width = function() {
    as.integer(size_config()$static_width)
  }, height = function() {
    as.integer(size_config()$static_height)
  })
  
  # 下载图形
  output$download_plot <- downloadHandler(
    filename = function() {
      export_fmt <- if (is.null(input$export_format) || !nzchar(input$export_format)) "png" else input$export_format
      build_plot_export_filename("forest_plot", export_fmt, include_time = TRUE)
    },
    content = function(file) {
      export_fmt <- if (is.null(input$export_format) || !nzchar(input$export_format)) "png" else input$export_format
      export_dpi <- suppressWarnings(as.numeric(input$export_dpi))
      if (is.na(export_dpi) || !is.finite(export_dpi)) export_dpi <- 600
      cfg <- size_config()
      save_plot_export(
        file = file,
        plot_obj = graphics_apply_canvas_frame(
          forest_plot_reactive(),
          frame_width_px = cfg$static_width,
          frame_height_px = cfg$static_height,
          canvas_config = cfg
        ),
        format = export_fmt,
        width = cfg$export_width,
        height = cfg$export_height,
        dpi = export_dpi,
        bg = "white"
      )
    }
  )
  
  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    graphics_restore_task_input_state(session, state)
    extra_state <- graphics_task_payload_extra_state(state)
    updateSelectInput(session, "subgroup_col", selected = extra_state$subgroup_col %||% input$subgroup_col)
    updateSelectInput(session, "study_col", selected = extra_state$study_col %||% input$study_col)
    updateSelectInput(session, "estimate_col", selected = extra_state$estimate_col %||% input$estimate_col)
    updateSelectInput(session, "lower_col", selected = extra_state$lower_col %||% input$lower_col)
    updateSelectInput(session, "upper_col", selected = extra_state$upper_col %||% input$upper_col)
    if (!is.null(extra_state$plot_title)) updateTextInput(session, "plot_title", value = extra_state$plot_title)
    if (!is.null(extra_state$x_min)) updateNumericInput(session, "x_min", value = extra_state$x_min)
    if (!is.null(extra_state$x_max)) updateNumericInput(session, "x_max", value = extra_state$x_max)
    if (!is.null(extra_state$line_width)) updateSliderInput(session, "line_width", value = extra_state$line_width)
    if (!is.null(extra_state$line_height)) updateSliderInput(session, "line_height", value = extra_state$line_height)
    if (!is.null(extra_state$x_axis_decimals)) updateNumericInput(session, "x_axis_decimals", value = extra_state$x_axis_decimals)
    if (!is.null(extra_state$percentage_format)) updateCheckboxInput(session, "percentage_format", value = isTRUE(extra_state$percentage_format))
    invisible(TRUE)
  }

  list(
    state = reactive({
      axis_range <- graphics_collect_axis_range_config(input, "x_min", "x_max")
      axis_tick <- graphics_collect_axis_tick_config(input, decimals_id = "x_axis_decimals", percent_id = "percentage_format")
      graphics_build_task_state(
        input,
        extra_state = list(
          subgroup_col = input$subgroup_col,
          study_col = input$study_col,
          estimate_col = input$estimate_col,
          lower_col = input$lower_col,
          upper_col = input$upper_col,
          plot_title = input$plot_title,
          x_min = axis_range$min,
          x_max = axis_range$max,
          line_width = input$line_width,
          line_height = input$line_height,
          x_axis_decimals = axis_tick$decimals,
          percentage_format = isTRUE(axis_tick$show_percent)
        )
      )
    }),
    apply_state = apply_state
  )
}
