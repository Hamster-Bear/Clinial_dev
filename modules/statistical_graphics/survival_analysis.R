# 生存分析图形子模块
# 负责生成生存曲线（Kaplan-Meier曲线）

# 加载必要的包
library(survival)
library(survminer)
library(plotly)
library(DT)
library(cowplot)

.resolve_survival_choice <- function(input_value, state_value, choices, default_value = NULL) {
  if (length(choices) == 0) return(default_value %||% NULL)
  if (!is.null(input_value) && input_value %in% choices) return(input_value)
  if (!is.null(state_value) && state_value %in% choices) return(state_value)
  if (!is.null(default_value) && default_value %in% choices) return(default_value)
  choices[1]
}

.format_survival_group_label <- function(strata_name, strata_var = NULL, strata_labels = list(), overall_label = "all") {
  label <- as.character(strata_name %||% "all")
  if (!nzchar(label) || identical(tolower(label), "all")) return(overall_label %||% "all")
  if (!is.null(strata_var) && nzchar(strata_var)) {
    prefix <- paste0(strata_var, "=")
    if (startsWith(label, prefix)) {
      label <- substr(label, nchar(prefix) + 1, nchar(label))
    }
  }
  if (grepl("=", label, fixed = TRUE)) {
    label <- sub("^.*=", "", label)
  }
  mapped <- strata_labels[[label]]
  if (!is.null(mapped) && nzchar(trimws(mapped))) trimws(mapped) else label
}

.extract_survival_legend_labs <- function(fit_obj, strata_var = NULL, strata_labels = list(), overall_label = "all") {
  if (is.null(fit_obj$strata)) return(overall_label %||% "all")
  vapply(
    names(fit_obj$strata),
    function(x) .format_survival_group_label(x, strata_var, strata_labels, overall_label),
    character(1)
  )
}

.apply_survival_line_style <- function(plot_obj, line_size, line_type) {
  plot_obj$layers <- lapply(plot_obj$layers, function(layer) {
    if (any(class(layer$geom) %in% c("GeomStep", "GeomLine"))) {
      layer$aes_params$linewidth <- line_size
      layer$aes_params$size <- line_size
      layer$aes_params$linetype <- line_type
    }
    layer
  })
  plot_obj
}

survival_analysis_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      graphics_config_tabs_box(
        id = id,
        title = "生存分析参数配置",
        collapsed = FALSE,
        tabs = list(
          tabPanel(
            "数据映射",
            br(),
            fluidRow(
              column(
                6,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "数据映射"),
                         tags$div(class = "panel-body",
                                  selectizeInput(ns("km_time"), "时间变量 (数值型)", choices = NULL, width = "100%"),
                                  selectizeInput(ns("km_status"), "状态变量 (数值型)", choices = NULL, width = "100%"),
                                  fluidRow(
                                    column(6, selectizeInput(ns("strata_var"), "分层变量 (分组)", choices = c("无" = "None"), width = "100%")),
                                    column(6, selectizeInput(ns("facet_var"), "分面变量 (分组)", choices = c("无" = "None"), width = "100%"))
                                  ),
                                  conditionalPanel(
                                    condition = paste0("input['", ns("strata_var"), "'] != 'None'"),
                                    uiOutput(ns("hr_reference_ui"))
                                  ),
                                  conditionalPanel(
                                    condition = paste0("input['", ns("facet_var"), "'] != 'None'"),
                                    uiOutput(ns("facet_value_ui"))
                                  )))
              ),
              column(
                6,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "处理与筛选"),
                         tags$div(class = "panel-body",
                                  radioButtons(ns("km_censor_value"), "删失值定义",
                                               choices = c("0 = 删失, 1 = 事件" = "0", "1 = 删失, 0 = 事件" = "1"),
                                               selected = "0", inline = TRUE),
                                  hr(),
                                  uiOutput(ns("time_range_slider")),
                                  numericInput(ns("time_step"), "时间轴步长", value = NULL, min = 1, max = 1000, step = 1, width = "100%")))
              )
            )
          ),
          tabPanel(
            "分析参数",
            br(),
            fluidRow(
              column(
                6,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "曲线与风险表"),
                         tags$div(class = "panel-body",
                                  fluidRow(
                                    column(6, numericInput(ns("line_size"), "线条粗细", value = 0.6, min = 0.1, max = 5, step = 0.1, width = "100%")),
                                    column(6, selectInput(ns("line_type"), "线条类型",
                                                          choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted",
                                                                      "点虚线" = "dotdash", "长虚线" = "longdash"), width = "100%"))
                                  ),
                                  checkboxInput(ns("km_show_censor"), "显示删失符号", value = TRUE),
                                  conditionalPanel(
                                    condition = paste0("input['", ns("km_show_censor"), "'] == true"),
                                    fluidRow(
                                      column(6, numericInput(ns("km_censor_size"), "删失点大小", value = 2, min = 1, max = 10, step = 0.5, width = "100%")),
                                      column(6, selectInput(ns("km_censor_shape"), "删失点形状",
                                                            choices = c("+" = 3, "I" = 124, "□" = 0, "○" = 1, "△" = 2, "◇" = 5, "☆" = 8),
                                                            selected = 3, width = "100%"))
                                    )
                                  ),
                                  checkboxInput(ns("km_show_risktable"), "显示风险表", value = TRUE),
                                  checkboxInput(ns("show_grid"), "显示网格线", value = FALSE)))
              ),
              column(
                6,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "统计标注"),
                         tags$div(class = "panel-body",
                                  checkboxInput(ns("show_median"), "显示中位生存时间", value = TRUE),
                                  checkboxInput(ns("show_stats"), "显示统计量(P值/HR)", value = TRUE),
                                  selectInput(ns("text_position_preset"), "统计文本位置预设",
                                              choices = c("自动（默认）" = "auto",
                                                          "左上" = "top-left",
                                                          "右上" = "top-right",
                                                          "左下" = "bottom-left",
                                                          "右下" = "bottom-right",
                                                          "自定义" = "custom"),
                                              selected = "bottom-left", width = "100%"),
                                  conditionalPanel(
                                    condition = paste0("input['", ns("text_position_preset"), "'] == 'custom'"),
                                    h5("自定义坐标 (0-1相对位置)"),
                                    fluidRow(
                                      column(6, numericInput(ns("median_x"), "中位生存X", value = 0.98, min = 0, max = 1, step = 0.01, width = "100%")),
                                      column(6, numericInput(ns("median_y"), "中位生存Y", value = 0.95, min = 0, max = 1, step = 0.01, width = "100%"))
                                    ),
                                    fluidRow(
                                      column(6, numericInput(ns("stats_x"), "统计量X", value = 0.02, min = 0, max = 1, step = 0.01, width = "100%")),
                                      column(6, numericInput(ns("stats_y"), "统计量Y", value = 0.95, min = 0, max = 1, step = 0.01, width = "100%"))
                                    )
                                  )))
              )
            )
          ),
          tabPanel(
            "样式主题",
            br(),
            fluidRow(
              column(
                6,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "标题与坐标轴"),
                         tags$div(class = "panel-body",
                                  textInput(ns("plot_title"), "主标题", value = "", placeholder = "输入标题", width = "100%"),
                                  fluidRow(
                                    column(6, numericInput(ns("title_size"), "标题大小", value = 14, min = 8, max = 24, step = 1, width = "100%")),
                                    column(6, numericInput(ns("caption_size"), "脚注大小", value = 10, min = 8, max = 20, step = 1, width = "100%"))
                                  ),
                                  textInput(ns("plot_caption"), "脚注", value = "", placeholder = "输入脚注", width = "100%"),
                                  fluidRow(
                                    column(6, textInput(ns("plot_xlab"), "X轴标签", value = "", width = "100%")),
                                    column(6, numericInput(ns("xlab_size"), "X轴字号", value = 12, min = 8, max = 20, step = 1, width = "100%"))
                                  ),
                                  fluidRow(
                                    column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "", width = "100%")),
                                    column(6, numericInput(ns("ylab_size"), "Y轴字号", value = 12, min = 8, max = 20, step = 1, width = "100%"))
                                  )))
              ),
              column(
                6,
                tags$div(class = "panel panel-default",
                         tags$div(class = "panel-heading", "图例与文字"),
                         tags$div(class = "panel-body",
                                  fluidRow(
                                    column(4, numericInput(ns("axis_text_size"), "坐标刻度字号", value = 10, min = 6, max = 20, step = 1, width = "100%")),
                                    column(4, numericInput(ns("legend_text_size"), "图例文本字号", value = 10, min = 6, max = 20, step = 1, width = "100%")),
                                    column(4, numericInput(ns("stats_text_size"), "统计标注字号", value = 10, min = 6, max = 20, step = 1, width = "100%"))
                                  ),
                                  numericInput(ns("y_text_size"), "风险表Y轴标签大小", value = 10, min = 6, max = 20, step = 1, width = "100%"),
                                  graphics_legend_controls_ui(ns, title_id = "legend_title", position_id = "legend_position", position_kind = "corners_none", default_position = "top-right"),
                                  conditionalPanel(
                                    condition = paste0("input['", ns("strata_var"), "'] == 'None'"),
                                    textInput(ns("overall_group_label"), "总体分组标签", value = "all", width = "100%"),
                                    helpText("未分层时统一用于主图图例、风险表、数据表与统计报告")
                                  )))
              )
            )
          ),
          tabPanel(
            "输出与导出",
            br(),
            fluidRow(
              column(4,
                     selectInput(ns("size_mode"), "尺寸模式",
                                 choices = c("宽图标准" = "wide_standard", "自定义尺寸" = "custom"),
                                 selected = "wide_standard", width = "100%")),
              column(4,
                     selectInput(ns("export_format"), "导出格式",
                                 choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"),
                                 selected = "pdf", width = "100%")),
              column(4,
                     numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
            ),
            conditionalPanel(
              condition = paste0("input['", ns("size_mode"), "'] == 'custom'"),
              fluidRow(
                column(3, numericInput(ns("static_width_px"), "静态图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                column(3, numericInput(ns("static_height_px"), "静态图高度(px)", value = 760, min = 400, max = 1800, step = 20, width = "100%")),
                column(3, numericInput(ns("interactive_width_px"), "交互图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                column(3, numericInput(ns("interactive_height_px"), "交互图高度(px)", value = 620, min = 350, max = 1600, step = 20, width = "100%"))
              ),
              fluidRow(
                column(3, numericInput(ns("export_width_in"), "导出宽度(英寸)", value = 13, min = 6, max = 30, step = 0.5, width = "100%")),
                column(3, numericInput(ns("export_height_in"), "导出高度(英寸)", value = 9, min = 4, max = 24, step = 0.5, width = "100%"))
              )
            ),
            hr(),
            conditionalPanel(
              condition = paste0("input['", ns("strata_var"), "'] != 'None'"),
              uiOutput(ns("strata_labels_ui"))
            ),
          )
        )
      )
    ),
    
    # 图形显示区域 - 底部
    fluidRow(
      box(
        width = 12,
        title = "生存曲线输出",
        status = "success",
        solidHeader = TRUE,
        fluidRow(
          column(6, div(style = "text-align: left; margin-bottom: 10px;", actionButton(ns("render_km_plot"), "生成图形", class = "btn-primary"))),
          column(6, div(style = "text-align: right; margin-bottom: 10px;", downloadButton(ns("download_plot"), "下载图形", class = "btn-primary")))
        ),
        
        tabsetPanel(
          id = ns("km_output_tabs"),
          tabPanel("静态图", 
            div(style = "height: 10px;"),
            uiOutput(ns("survPlotUI"))
          ),
          tabPanel("交互式图", 
            div(style = "height: 10px;"),
            uiOutput(ns("interactiveSurvPlotUI"))
          ),
          tabPanel("数据表", 
            div(style = "height: 10px;"),
            DTOutput(ns("km_data_table"))
          ),
          tabPanel("统计报告",
            div(style = "height: 10px;"),
            uiOutput(ns("survival_report"))
          )
        )
      )
    ),
    
    # JavaScript 修复 - 增强版，防止滚轮意外修改输入值
    tags$script(HTML('
      $(document).ready(function() {
        // 禁用 selectize 输入框的滚轮事件
        $(document).on("mousewheel DOMMouseScroll", ".selectize-control .selectize-input", function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
        
        // 禁用普通 select 输入框的滚轮事件
        $(document).on("mousewheel DOMMouseScroll", "select", function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
        
        // 禁用数字输入框的滚轮事件
        $(document).on("mousewheel DOMMouseScroll", "input[type=number]", function(e) {
          // 只有当输入框聚焦时才处理
          if ($(this).is(":focus")) {
            e.preventDefault();
            e.stopPropagation();
            $(this).blur(); // 移除焦点，这是最有效的方法
          }
        });
      });
    '))
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
    axis_text_size = 10,
    legend_text_size = 10,
    stats_text_size = 10,
    show_grid = FALSE,
    time_step = NULL,
    show_median = TRUE,
    show_stats = TRUE,
    legend_position = "top-right",
    legend_title = "",
    text_position_preset = "bottom-left",
    median_x = 0.98,
    median_y = 0.95,
    stats_x = 0.02,
    stats_y = 0.95,
    hr_reference = NULL,
    strata_labels = list(),
    overall_group_label = "all"
  )
  view_state <- reactiveValues(
    km_time = NULL,
    km_status = NULL,
    km_strata = "None",
    km_facet = "None",
    km_facet_values = NULL
  )
  committed_params <- reactiveVal(NULL)
  size_config <- reactive({
    resolve_plot_size_config(
      mode = input$size_mode %||% "wide_standard",
      static_width_px = input$static_width_px,
      static_height_px = input$static_height_px,
      interactive_width_px = input$interactive_width_px,
      interactive_height_px = input$interactive_height_px,
      export_width_in = input$export_width_in,
      export_height_in = input$export_height_in
    )
  })
  
  observe({
    req(data())
    categorical_vars <- get_categorical_vars(data(), include_logical = TRUE)
    numeric_vars <- get_numeric_vars(data())
    default_time <- if (length(numeric_vars) >= 1) numeric_vars[1] else NULL
    default_status <- if (length(numeric_vars) >= 2) numeric_vars[2] else default_time
    current_time_choice <- .resolve_survival_choice(input$km_time, view_state$km_time, numeric_vars, default_time)
    current_status_choice <- .resolve_survival_choice(input$km_status, view_state$km_status, numeric_vars, default_status)
    strata_choices <- c("无" = "None", categorical_vars)
    curr_strata <- .resolve_survival_choice(input$strata_var, view_state$km_strata, c("None", categorical_vars), "None")
    facet_choices <- c("无" = "None", categorical_vars)
    curr_facet <- .resolve_survival_choice(input$facet_var, view_state$km_facet, c("None", categorical_vars), "None")
    isolate({
      updateSelectizeInput(session, "km_time", choices = numeric_vars, selected = current_time_choice)
      updateSelectizeInput(session, "km_status", choices = numeric_vars, selected = current_status_choice)
      updateSelectizeInput(session, "strata_var", choices = strata_choices, selected = curr_strata)
      updateSelectizeInput(session, "facet_var", choices = facet_choices, selected = curr_facet)
    })
  })
  
  # 强制初始化默认值（在数据可用时立即设置状态）
  observeEvent(data(), {
    req(data())
    isolate({
      current_data <- data()
      if(!is.null(current_data) && nrow(current_data) > 0) {
        numeric_vars <- get_numeric_vars(current_data)
        if(length(numeric_vars) >= 2) {
          # 只有在当前状态为NULL时才设置默认值
          if(is.null(graphics_state$km_time) || !graphics_state$km_time %in% names(current_data)) {
            graphics_state$km_time <- numeric_vars[1]
          }
          if(is.null(graphics_state$km_status) || !graphics_state$km_status %in% names(current_data)) {
            graphics_state$km_status <- numeric_vars[2]
          }
          if(is.null(view_state$km_time) || !view_state$km_time %in% names(current_data)) {
            view_state$km_time <- numeric_vars[1]
          }
          if(is.null(view_state$km_status) || !view_state$km_status %in% names(current_data)) {
            view_state$km_status <- numeric_vars[2]
          }
        } else if(length(numeric_vars) == 1) {
          if(is.null(graphics_state$km_time) || !graphics_state$km_time %in% names(current_data)) {
            graphics_state$km_time <- numeric_vars[1]
          }
          if(is.null(graphics_state$km_status) || !graphics_state$km_status %in% names(current_data)) {
            graphics_state$km_status <- numeric_vars[1]
          }
          if(is.null(view_state$km_time) || !view_state$km_time %in% names(current_data)) {
            view_state$km_time <- numeric_vars[1]
          }
          if(is.null(view_state$km_status) || !view_state$km_status %in% names(current_data)) {
            view_state$km_status <- numeric_vars[1]
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
      numeric_vars <- get_numeric_vars(current_data)
      if(length(numeric_vars) >= 1) {
        graphics_state$km_time <- numeric_vars[1]
        view_state$km_time <- numeric_vars[1]
      }
      if(length(numeric_vars) >= 2) {
        graphics_state$km_status <- numeric_vars[2]
        view_state$km_status <- numeric_vars[2]
      }
    }
  })
  
  
  # 动态分面值选择器UI
  output$facet_value_ui <- renderUI({
    req(data())
    
    if (!is.null(input$facet_var) && input$facet_var != "None" && input$facet_var %in% names(data())) {
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
        # 注意：这里我们不再依赖 graphics_state$km_facet_values，而是直接看当前是否有有效选项
        # 这是为了避免在不同分面变量切换时，旧的 state 值导致 selectInput 无法选中有效值
        selectInput(ns("facet_value"), "分面值选择", choices = choices)
      } else {
        selectInput(ns("facet_value"), "分面值选择", choices = NULL)
      }
    } else {
      NULL
    }
  })
  
  # 动态HR参考组选择UI
  output$hr_reference_ui <- renderUI({
    req(data())
    
    if (!is.null(input$strata_var) && input$strata_var != "None" && input$strata_var %in% names(data())) {
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
    req(data())
    
    if (!is.null(input$strata_var) && input$strata_var != "None" && input$strata_var %in% names(data())) {
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
  
  observeEvent(input$render_km_plot, {
    progress_id <- graphics_progress_start("生存分析")
    ok <- FALSE
    err <- NULL
    on.exit({
      graphics_progress_end(progress_id)
      if (ok) {
        graphics_notify_success("生存分析")
      } else if (!is.null(err)) {
        graphics_notify_error("生存分析", err)
      }
    }, add = TRUE)
    tryCatch({
      withProgress(message = "Generating survival plot...", value = 0, {
        graphics_progress_update(progress_id, "生存分析", "提交参数", 0.2)
        incProgress(0.2, detail = "Committing UI state")
        req(data())
        current_data <- data()
        numeric_vars <- get_numeric_vars(current_data)
        categorical_vars <- get_categorical_vars(current_data, include_logical = TRUE)
        default_time <- if (length(numeric_vars) >= 1) numeric_vars[1] else NULL
        default_status <- if (length(numeric_vars) >= 2) numeric_vars[2] else default_time
        km_time <- .resolve_survival_choice(input$km_time, view_state$km_time, numeric_vars, default_time)
        km_status <- .resolve_survival_choice(input$km_status, view_state$km_status, numeric_vars, default_status)
        km_strata <- .resolve_survival_choice(input$strata_var, view_state$km_strata, c("None", categorical_vars), "None")
        km_facet <- .resolve_survival_choice(input$facet_var, view_state$km_facet, c("None", categorical_vars), "None")
        if (is.null(km_time) || !km_time %in% names(current_data)) stop("请选择有效的时间变量")
        if (is.null(km_status) || !km_status %in% names(current_data)) stop("请选择有效的状态变量")
        km_facet_values <- NULL
        if (!is.null(km_facet) && km_facet != "None") {
          facet_choices <- unique(as.character(current_data[[km_facet]]))
          facet_choices <- facet_choices[!is.na(facet_choices) & facet_choices != ""]
          km_facet_values <- .resolve_survival_choice(input$facet_value, view_state$km_facet_values, facet_choices, facet_choices[1] %||% NULL)
          if (is.null(km_facet_values) || !km_facet_values %in% facet_choices) stop("请选择有效的分面值")
        }
        overall_group_label <- trimws(input$overall_group_label %||% "all")
        if (!nzchar(overall_group_label)) overall_group_label <- "all"
        strata_labels <- list()
        if (!is.null(km_strata) && km_strata != "None") {
          strata_col <- current_data[[km_strata]]
          strata_values <- unique(strata_col)
          strata_values <- strata_values[!is.na(strata_values)]
          strata_values_char <- as.character(strata_values)
          strata_values_char <- strata_values_char[strata_values_char != ""]
          for (val in strata_values_char) {
            input_name <- paste0("strata_label_", val)
            if (!is.null(input[[input_name]])) {
              strata_labels[[val]] <- input[[input_name]]
            }
          }
        }
        params <- list(
          km_time = km_time,
          km_status = km_status,
          km_strata = km_strata,
          km_facet = km_facet,
          km_facet_values = km_facet_values,
          km_censor_value = input$km_censor_value,
          km_show_risktable = input$km_show_risktable,
          km_line_size = input$line_size,
          km_line_type = input$line_type,
          km_censor_size = input$km_censor_size,
          km_censor_shape = input$km_censor_shape,
          y_text_size = input$y_text_size,
          title_size = input$title_size,
          caption_size = input$caption_size,
          xlab_size = input$xlab_size,
          ylab_size = input$ylab_size,
          axis_text_size = input$axis_text_size,
          legend_text_size = input$legend_text_size,
          stats_text_size = input$stats_text_size,
          show_grid = input$show_grid,
          time_step = input$time_step,
          show_median = input$show_median,
          show_stats = input$show_stats,
          legend_position = input$legend_position,
          legend_title = input$legend_title,
          text_position_preset = input$text_position_preset,
          median_x = input$median_x,
          median_y = input$median_y,
          stats_x = input$stats_x,
          stats_y = input$stats_y,
          hr_reference = input$hr_reference,
          strata_labels = strata_labels,
          overall_group_label = overall_group_label
        )
        graphics_state$km_time <- params$km_time
        graphics_state$km_status <- params$km_status
        graphics_state$km_strata <- params$km_strata
        graphics_state$km_facet <- params$km_facet
        graphics_state$km_facet_values <- params$km_facet_values
        graphics_state$km_censor_value <- params$km_censor_value
        graphics_state$km_show_risktable <- params$km_show_risktable
        graphics_state$km_line_size <- params$km_line_size
        graphics_state$km_line_type <- params$km_line_type
        graphics_state$km_censor_size <- params$km_censor_size
        graphics_state$km_censor_shape <- params$km_censor_shape
        graphics_state$y_text_size <- params$y_text_size
        graphics_state$title_size <- params$title_size
        graphics_state$caption_size <- params$caption_size
        graphics_state$xlab_size <- params$xlab_size
        graphics_state$ylab_size <- params$ylab_size
        graphics_state$axis_text_size <- params$axis_text_size
        graphics_state$legend_text_size <- params$legend_text_size
        graphics_state$stats_text_size <- params$stats_text_size
        graphics_state$show_grid <- params$show_grid
        graphics_state$time_step <- params$time_step
        graphics_state$show_median <- params$show_median
        graphics_state$show_stats <- params$show_stats
        graphics_state$legend_position <- params$legend_position
        graphics_state$legend_title <- params$legend_title
        graphics_state$text_position_preset <- params$text_position_preset
        graphics_state$median_x <- params$median_x
        graphics_state$median_y <- params$median_y
        graphics_state$stats_x <- params$stats_x
        graphics_state$stats_y <- params$stats_y
        graphics_state$hr_reference <- params$hr_reference
        graphics_state$strata_labels <- params$strata_labels
        graphics_state$overall_group_label <- params$overall_group_label
        committed_params(params)
        graphics_progress_update(progress_id, "生存分析", "模型拟合", 0.55)
        incProgress(0.35, detail = "Fitting survival model")
        surv_obj()
        fit()
        graphics_progress_update(progress_id, "生存分析", "统计计算", 0.8)
        incProgress(0.25, detail = "Computing statistics")
        surv_summary_data()
        stats_results()
        mapped_strata()
        base_surv_plot()
        graphics_progress_update(progress_id, "生存分析", "图形完成", 1)
        incProgress(0.2, detail = "Completed")
      })
      ok <- TRUE
    }, error = function(e) {
      err <<- e
    })
  })
  
  # 获取过滤后的数据（不再使用 eventReactive，恢复为 reactive，保证下拉框随时更新）
  filtered_data <- reactive({
    req(data())
    df <- data()
    
    # 如果选择了分面变量，则过滤数据
    facet_var_selected <- .resolve_survival_choice(input$facet_var, view_state$km_facet, c("None", names(df)), "None")
    facet_value_selected <- if (!is.null(input$facet_value)) input$facet_value else view_state$km_facet_values
    if (!is.null(facet_var_selected) && facet_var_selected != "None" && facet_var_selected %in% names(df) && !is.null(facet_value_selected)) {
      facet_col <- df[[facet_var_selected]]
      filtered_df <- df[as.character(facet_col) == as.character(facet_value_selected), ]
      return(filtered_df)
    }
    return(df)
  })
  committed_filtered_data <- reactive({
    req(data(), committed_params())
    df <- data()
    params <- committed_params()
    if (!is.null(params$km_facet) && params$km_facet != "None" && params$km_facet %in% names(df) && !is.null(params$km_facet_values)) {
      facet_col <- df[[params$km_facet]]
      return(df[as.character(facet_col) == as.character(params$km_facet_values), , drop = FALSE])
    }
    df
  })
  
  
  # 动态时间范围滑块UI
  output$time_range_slider <- renderUI({
    req(input$km_time)
    
    # 注意：为了让用户在选择变量后能立刻看到滑块范围，这里直接使用 data()
    # 并且如果存在分面，不影响全局时间轴的最大值计算，保持一致的范围更合理
    df <- data()
    
    if (is.null(df) || nrow(df) == 0) {
      helpText("没有可用的数据")
    } else if (input$km_time %in% names(df)) {
      time_var <- df[[input$km_time]]
      
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
  
  extract_median_ci <- function(fit_obj) {
    tbl <- tryCatch(summary(fit_obj)$table, error = function(e) NULL)
    if (is.null(tbl)) return(NULL)
    if (is.null(dim(tbl))) {
      tbl <- t(as.matrix(tbl))
      rownames(tbl) <- "all"
    } else {
      tbl <- as.matrix(tbl)
    }
    cn <- colnames(tbl)
    med_col <- if ("median" %in% cn) "median" else grep("median", cn, ignore.case = TRUE, value = TRUE)[1]
    low_col <- if ("0.95LCL" %in% cn) "0.95LCL" else grep("LCL|lower", cn, ignore.case = TRUE, value = TRUE)[1]
    up_col <- if ("0.95UCL" %in% cn) "0.95UCL" else grep("UCL|upper", cn, ignore.case = TRUE, value = TRUE)[1]
    if (any(is.na(c(med_col, low_col, up_col)))) return(NULL)
    strata_name <- rownames(tbl)
    if (is.null(strata_name)) strata_name <- rep("all", nrow(tbl))
    data.frame(
      strata = strata_name,
      median = as.numeric(tbl[, med_col]),
      lower = as.numeric(tbl[, low_col]),
      upper = as.numeric(tbl[, up_col]),
      stringsAsFactors = FALSE
    )
  }

  # 创建生存对象（仅在点击“生成图形”后更新）
  surv_obj <- reactive({
    params <- committed_params()
    req(params)
    data <- committed_filtered_data()
    req(data)
    time_var_name <- params$km_time
    status_var_name <- params$km_status
    validate(
      need(time_var_name %in% names(data), "请选择有效的时间变量"),
      need(status_var_name %in% names(data), "请选择有效的状态变量"),
      need(nrow(data) > 0, "选择的分面值没有数据")
    )
    time_var <- data[[time_var_name]]
    status_var <- data[[status_var_name]]
    if (params$km_censor_value == "1") {
      status_var <- ifelse(status_var == 1, 0, ifelse(status_var == 0, 1, status_var))
    }
    unique_status <- unique(status_var)
    valid_status <- unique_status[!is.na(unique_status)]
    if (!all(valid_status %in% c(0, 1))) {
      min_status <- min(valid_status, na.rm = TRUE)
      status_var <- ifelse(status_var == min_status, 0, 1)
    }
    Surv(time_var, status_var)
  })
  
  fit <- reactive({
    params <- committed_params()
    req(params)
    req(surv_obj())
    data <- committed_filtered_data()
    req(data)
    
    if (nrow(data) == 0) {
      stop("没有足够的数据进行生存分析")
    }
    if (any(is.na(surv_obj()))) {
      stop("生存对象包含无效值")
    }
    strata_var <- params$km_strata
    if (is.null(strata_var) || strata_var == "None") {
      surv_fit(surv_obj() ~ 1, data = data, conf.type = "log-log")
    } else {
      validate(
        need(strata_var %in% names(data), "请选择有效的分层变量"),
        need(nrow(data) > 0, "选择的分面值没有数据")
      )
      formula_str <- paste("surv_obj() ~", strata_var)
      surv_fit(as.formula(formula_str), data = data, conf.type = "log-log")
    }
  })
  
  surv_summary_data <- reactive({
    req(fit())
    surv_summary(fit())
  })
  
  stats_results <- reactive({
    params <- committed_params()
    req(params)
    req(fit())
    data <- committed_filtered_data()
    req(data)
    
    res <- list(
      median_surv = extract_median_ci(fit()),
      logrank_p = NA_real_,
      hr_lines = character(0)
    )
    
    strata_var <- params$km_strata
    if (!is.null(strata_var) && strata_var != "None" && strata_var %in% names(data)) {
      try({
        sd <- survdiff(surv_obj() ~ data[[strata_var]], data = data)
        res$logrank_p <- pchisq(sd$chisq, length(sd$n) - 1, lower.tail = FALSE)
      }, silent = TRUE)
      try({
        strata_data <- data[[strata_var]]
        strata_levels <- unique(strata_data)
        reference_level <- if (!is.null(params$hr_reference) && params$hr_reference != "auto") {
          params$hr_reference
        } else {
          as.character(strata_levels[1])
        }
        strata_fac <- factor(strata_data)
        if (reference_level %in% levels(strata_fac)) {
          strata_fac <- relevel(strata_fac, ref = reference_level)
        }
        cox_fit <- coxph(surv_obj() ~ strata_fac, data = data)
        csum <- summary(cox_fit)
        
        if (!is.null(csum$coefficients) && nrow(csum$coefficients) > 0) {
          labels <- params$strata_labels
          map_label <- function(x) {
            if (x %in% names(labels) && labels[[x]] != "") return(labels[[x]])
            if (grepl("=", x)) {
              ext <- sub(".*=", "", x)
              if (ext %in% names(labels) && labels[[ext]] != "") return(labels[[ext]])
            }
            return(x)
          }
          
          for (i in seq_len(nrow(csum$coefficients))) {
            hr <- exp(csum$coefficients[i, 1])
            hr_low <- exp(csum$coefficients[i, 1] - 1.96 * csum$coefficients[i, 3])
            hr_up <- exp(csum$coefficients[i, 1] + 1.96 * csum$coefficients[i, 3])
            p_val <- csum$coefficients[i, 5]
            
            contrast_name <- rownames(csum$coefficients)[i]
            contrast_clean <- gsub("^.*?([^.]+)$", "\\1", contrast_name)
            if (grepl("strata_fac", contrast_name)) contrast_clean <- gsub("strata_fac", "", contrast_name)
            
            contrast_mapped <- map_label(contrast_clean)
            reference_mapped <- map_label(reference_level)
            
            hr_line <- paste0(contrast_mapped, " vs ", reference_mapped,
                              ": HR = ", formatC(hr, format = "f", digits = 2),
                              " (95%CI: ", formatC(hr_low, format = "f", digits = 2), "-",
                              formatC(hr_up, format = "f", digits = 2), ")",
                              ", P = ", formatC(p_val, format = "f", digits = 3))
            res$hr_lines <- c(res$hr_lines, hr_line)
          }
        }
      }, silent = TRUE)
    }
    
    res
  })
  
  observeEvent(input$km_time, {
    if (!is.null(input$km_time) && nzchar(input$km_time)) {
      view_state$km_time <- input$km_time
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$km_status, {
    if (!is.null(input$km_status) && nzchar(input$km_status)) {
      view_state$km_status <- input$km_status
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$strata_var, {
    if (!is.null(input$strata_var) && nzchar(input$strata_var)) {
      view_state$km_strata <- input$strata_var
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$facet_var, {
    if (!is.null(input$facet_var) && nzchar(input$facet_var)) {
      view_state$km_facet <- input$facet_var
    }
  }, ignoreInit = TRUE)
  
  observeEvent(input$facet_value, {
    view_state$km_facet_values <- input$facet_value
  }, ignoreInit = TRUE)
  
  # 获取标签映射后的分层变量值
  mapped_strata <- reactive({
    params <- committed_params()
    req(params)
    data <- committed_filtered_data()
    req(data)
    strata_var <- params$km_strata
    if (is.null(strata_var) || strata_var == "None" || !strata_var %in% names(data)) return(NULL)
    strata_col <- data[[strata_var]]
    strata_values <- as.character(strata_col)
    
    # 应用标签映射
    labels <- params$strata_labels
    if (length(labels) > 0) {
      for (orig in names(labels)) {
        if (labels[[orig]] != "") {
          strata_values[strata_values == orig] <- labels[[orig]]
        }
      }
    }
    return(strata_values)
  })
  
  base_surv_plot <- reactive({
    params <- committed_params()
    req(params, fit())
    data <- committed_filtered_data()
    req(data)
    time_var_name <- params$km_time
    status_var_name <- params$km_status
    strata_var <- params$km_strata
    overall_label <- params$overall_group_label %||% "all"
    time_range <- if (!is.null(input$time_range)) input$time_range else {
      time_max <- max(data[[time_var_name]], na.rm = TRUE)
      c(0, time_max + 30)
    }
    time_step <- if (!is.null(params$time_step) && !is.na(params$time_step) && params$time_step > 0) params$time_step else round((time_range[2] - time_range[1]) / 10)
    plot_data <- data
    if (!is.null(strata_var) && strata_var != "None" && length(params$strata_labels) > 0) {
      strata_col <- plot_data[[strata_var]]
      strata_values <- as.character(strata_col)
      for (orig in names(params$strata_labels)) {
        if (params$strata_labels[[orig]] != "") {
          strata_values[strata_values == orig] <- params$strata_labels[[orig]]
        }
      }
      plot_data[[strata_var]] <- factor(strata_values, levels = unique(strata_values))
    }
    if (!is.null(strata_var) && strata_var != "None" && length(params$strata_labels) > 0) {
      time_var <- plot_data[[time_var_name]]
      status_var <- plot_data[[status_var_name]]
      if (params$km_censor_value == "1") {
        status_var <- ifelse(status_var == 1, 0, ifelse(status_var == 0, 1, status_var))
      }
      unique_status <- unique(status_var)
      valid_status <- unique_status[!is.na(unique_status)]
      if (!all(valid_status %in% c(0, 1))) {
        min_status <- min(valid_status, na.rm = TRUE)
        status_var <- ifelse(status_var == min_status, 0, 1)
      }
      surv_obj_local <- Surv(time_var, status_var)
      fit_local <- surv_fit(as.formula(paste("surv_obj_local ~", strata_var)), data = plot_data, conf.type = "log-log")
    } else {
      fit_local <- fit()
    }
    legend_title_text <- graphics_resolve_legend_title(params$legend_title, "", "")
    legend_labs <- .extract_survival_legend_labs(fit_local, strata_var, params$strata_labels, overall_label)
    p <- suppressWarnings(ggsurvplot(
      fit_local,
      data = plot_data,
      risk.table = params$km_show_risktable,
      conf.int = FALSE,
      pval = FALSE,
      censor = FALSE,
      xlim = time_range,
      break.time.by = time_step,
      ggtheme = theme_bw(),
      palette = "Set1",
      legend.title = legend_title_text,
      legend.labs = legend_labs
    ))
    if (params$show_median) {
      median_surv <- stats_results()$median_surv
      if (!is.null(median_surv) && nrow(median_surv) > 0) {
        median_surv$display_strata <- vapply(
          median_surv$strata,
          function(x) .format_survival_group_label(x, strata_var, params$strata_labels, overall_label),
          character(1)
        )
        median_surv$median_txt <- ifelse(is.finite(median_surv$median), formatC(median_surv$median, format = "f", digits = 2), "NR")
        median_surv$lower_txt <- ifelse(is.finite(median_surv$lower), formatC(median_surv$lower, format = "f", digits = 2), "NA")
        median_surv$upper_txt <- ifelse(is.finite(median_surv$upper), formatC(median_surv$upper, format = "f", digits = 2), "NA")
        median_surv$label <- ifelse(
          median_surv$display_strata == overall_label,
          paste0("Median Survival Time: ", median_surv$median_txt, " (95%CI ", median_surv$lower_txt, "-", median_surv$upper_txt, ")"),
          paste0(median_surv$display_strata, ": Median Survival Time: ", median_surv$median_txt, " (95%CI ", median_surv$lower_txt, "-", median_surv$upper_txt, ")")
        )
        preset <- params$text_position_preset
        n_groups <- nrow(median_surv)
        if (preset == "auto" || preset == "bottom-left") {
          x_pos <- min(time_range) + 0.02 * diff(time_range)
          y_positions <- seq(0.4, max(0.05, 0.4 - (n_groups - 1) * 0.1), length.out = n_groups)
        } else if (preset == "top-left") {
          x_pos <- min(time_range) + 0.02 * diff(time_range)
          y_positions <- seq(0.95, max(0.6, 0.95 - (n_groups - 1) * 0.1), length.out = n_groups)
        } else if (preset == "top-right") {
          x_pos <- max(time_range) * 0.98
          y_positions <- seq(0.95, max(0.6, 0.95 - (n_groups - 1) * 0.1), length.out = n_groups)
        } else if (preset == "bottom-right") {
          x_pos <- max(time_range) * 0.98
          y_positions <- seq(0.4, max(0.05, 0.4 - (n_groups - 1) * 0.1), length.out = n_groups)
        } else {
          x_pos <- min(time_range) + params$median_x * diff(time_range)
          y_positions <- params$median_y - seq(0, n_groups - 1) * 0.05
        }
        median_surv$x <- x_pos
        median_surv$y <- y_positions
        p$plot <- p$plot +
          geom_text(
            data = median_surv,
            aes(x = x, y = y, label = label),
            hjust = ifelse(preset %in% c("top-left", "bottom-left", "auto"), 0, 1),
            vjust = 0.5,
            size = params$stats_text_size / 3.2,
            color = "black",
            fontface = "bold"
          )
      }
    }
    if (params$show_stats) {
      logrank_p <- stats_results()$logrank_p
      stats_text <- ""
      if (!is.na(logrank_p)) stats_text <- paste0("Log-rank P = ", formatC(logrank_p, format = "f", digits = 3))
      if (!is.null(strata_var) && strata_var != "None") {
        hr_lines <- stats_results()$hr_lines
        if (length(hr_lines) > 0) {
          if (stats_text != "") stats_text <- paste0(stats_text, "\n")
          stats_text <- paste0(stats_text, paste(hr_lines, collapse = "\n"))
        }
      }
      preset <- params$text_position_preset
      if (preset == "auto" || preset == "bottom-left") {
        stats_x <- min(time_range) + 0.02 * diff(time_range); stats_y <- 0.05; hjust_val <- 0; vjust_val <- 0
      } else if (preset == "top-left") {
        stats_x <- min(time_range) + 0.02 * diff(time_range); stats_y <- 0.95; hjust_val <- 0; vjust_val <- 1
      } else if (preset == "top-right") {
        stats_x <- max(time_range) * 0.98; stats_y <- 0.95; hjust_val <- 1; vjust_val <- 1
      } else if (preset == "bottom-right") {
        stats_x <- max(time_range) * 0.98; stats_y <- 0.05; hjust_val <- 1; vjust_val <- 0
      } else {
        stats_x <- min(time_range) + params$stats_x * diff(time_range)
        stats_y <- params$stats_y
        hjust_val <- ifelse(params$stats_x < 0.5, 0, 1)
        vjust_val <- ifelse(params$stats_y < 0.5, 0, 1)
      }
      if (stats_text != "") {
        p$plot <- p$plot +
          annotate("text", x = stats_x, y = stats_y, label = stats_text, hjust = hjust_val, vjust = vjust_val, size = params$stats_text_size / 3.2, color = "black", fontface = "bold")
      }
    }
    if (input$km_show_censor) {
      surv_data <- surv_summary_data()
      censored_points <- surv_data[surv_data$n.censor > 0, ]
      if (nrow(censored_points) > 0) {
        if ("strata" %in% names(censored_points) && !is.null(strata_var) && strata_var != "None") {
          p$plot <- p$plot + geom_point(data = censored_points, aes(x = time, y = surv, color = strata, shape = "Censor"), size = params$km_censor_size, alpha = 1)
        } else {
          p$plot <- p$plot + geom_point(data = censored_points, aes(x = time, y = surv, shape = "Censor"), size = params$km_censor_size, color = "black", alpha = 1)
        }
        p$plot <- p$plot +
          scale_shape_manual(name = "", values = c("Censor" = as.numeric(params$km_censor_shape))) +
          guides(shape = guide_legend(position = "inside", override.aes = list(color = "black"))) +
          theme(legend.position.inside = c(0.9, 0.9))
      }
    }
    p$plot <- p$plot + guides(shape = guide_legend(title = ""), alpha = "none", size = "none", linewidth = "none")
    p$plot <- .apply_survival_line_style(p$plot, params$km_line_size, params$km_line_type)
    if (!params$show_grid) {
      p$plot <- p$plot + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
    }
    p$plot <- p$plot +
      theme(
        text = element_text(family = "sans"),
        panel.border = element_blank(),
        axis.line = element_line(colour = "black", arrow = arrow(length = unit(0.2, "cm"), type = "closed")),
        axis.text = element_text(size = params$axis_text_size),
        legend.text = element_text(size = params$legend_text_size)
      )
    p$plot <- graphics_apply_legend_theme(
      p$plot,
      show_legend = !identical(params$legend_position, "none"),
      position = params$legend_position
    )
    if (!is.null(input$plot_title) && input$plot_title != "") {
      p$plot <- p$plot + labs(title = gsub("\\\\n", "\n", input$plot_title))
    }
    if (!is.null(input$plot_xlab) && input$plot_xlab != "") {
      p$plot <- p$plot + labs(x = gsub("\\\\n", "\n", input$plot_xlab))
    } else {
      p$plot <- p$plot + labs(x = time_var_name)
    }
    if (!is.null(input$plot_ylab) && input$plot_ylab != "") {
      p$plot <- p$plot + labs(y = gsub("\\\\n", "\n", input$plot_ylab))
    } else {
      p$plot <- p$plot + labs(y = "Survival Probability")
    }
    if (params$km_show_risktable && !is.null(p$table)) {
      p$table <- p$table +
        theme_minimal() +
        theme(
          text = element_text(family = "sans"),
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          plot.margin = margin(0, 0, 0, 0, "pt"),
          axis.text.y = element_text(size = params$y_text_size)
        )
      if (is.null(strata_var) || strata_var == "None") {
        p$table <- p$table + scale_y_discrete(labels = function(x) rep(overall_label, length(x)))
      }
    }
    p
  })
  
  # 创建组合的静态生存曲线图
  create_surv_plot <- function() {
    params <- committed_params()
    req(params)
    p <- base_surv_plot()
    
    if (params$km_show_risktable && !is.null(p$table)) {
      plot_list <- list(p$plot, p$table)
      
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
      
      combined_plot <- plot_grid(
        plotlist = plot_list,
        ncol = 1,
        align = "v",
        axis = "lr",
        rel_heights = rel_heights
      )
      
      combined_plot
    } else {
      if (!is.null(input$plot_caption) && input$plot_caption != "") {
        formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
        p$plot <- p$plot + labs(caption = formatted_caption) +
          theme(plot.caption = element_text(hjust = 0, vjust = 1, size = input$caption_size))
      }
      p$plot
    }
  }
  
  output$survPlotUI <- renderUI({
    cfg <- size_config()
    tags$div(
      style = paste0("width:", cfg$static_width, "px; max-width: 100%; overflow-x: auto;"),
      plotOutput(ns("survPlot"), height = paste0(cfg$static_height, "px"), width = "100%")
    )
  })
  
  output$interactiveSurvPlotUI <- renderUI({
    cfg <- size_config()
    tags$div(
      style = paste0("width:", cfg$interactive_width, "px; max-width: 100%; overflow-x: auto;"),
      plotly::plotlyOutput(ns("interactiveSurvPlot"), height = paste0(cfg$interactive_height, "px"), width = "100%")
    )
  })
  
  output$survPlot <- renderPlot({
    req(input$render_km_plot) # 确保有点击过生成按钮
    validate(need(!is.null(fit()), "请先完成变量设置并点击“生成图形”。"))
    create_surv_plot()
  }, height = function() size_config()$static_height, width = function() size_config()$static_width)
  
  # 创建专门的交互式生存曲线图
  create_interactive_surv_plot <- function() {
    params <- committed_params()
    req(params)
    p <- base_surv_plot()$plot
    
    # 交互式图不需要网格和复杂的自定义主题边框，但这里我们保留大部分原有设置
    # 处理标题（如果之前未自定义，添加默认交互式标题）
    if (is.null(input$plot_title) || input$plot_title == "") {
      if (params$km_facet != "None" && !is.null(params$km_facet_values)) {
        p <- p + labs(title = paste("Interactive Survival Plot -", params$km_facet, "=", params$km_facet_values))
      } else {
        p <- p + labs(title = "Interactive Survival Plot")
      }
    }
    
    # 处理脚注（直接加到主图）
    if (!is.null(input$plot_caption) && input$plot_caption != "") {
      formatted_caption <- gsub("\\\\n", "\n", input$plot_caption)
      p <- p + labs(caption = formatted_caption) +
        theme(plot.caption = element_text(hjust = 0, vjust = 1, size = 10))
    }
    
    return(p)
  }
  
    # 交互式生存曲线图
  output$interactiveSurvPlot <- renderPlotly({
    req(input$render_km_plot)
    validate(need(!is.null(fit()), "请先生成生存曲线后查看交互式图。"))
    
    # 创建专门的交互式图形
    interactive_plot <- create_interactive_surv_plot()
    
    # 转换为plotly，避免layout()的width/height弃用警告
    # 移除height参数，因为Shiny的renderPlotly会自动处理容器大小
    # 同时可以尝试手动调整布局以移除已有的width/height属性
    plotly_obj <- ggplotly(interactive_plot, tooltip = c("x", "y", "colour"))
    
    # 手动清理layout中的width和height (如果有)
    plotly_obj$x$layout$width <- size_config()$interactive_width
    plotly_obj$x$layout$height <- size_config()$interactive_height
    
    return(plotly_obj)
  })

  build_km_summary_df <- function(fit_obj, time_range = NULL, strata_var = NULL, strata_labels = list(), overall_label = "all") {
    surv_summary <- summary(fit_obj, censored = TRUE)
    if (is.null(surv_summary$time) || length(surv_summary$time) == 0) return(NULL)
    surv_df <- data.frame(
      时间 = surv_summary$time,
      组别 = if (!is.null(surv_summary$strata)) as.character(surv_summary$strata) else overall_label,
      风险人数 = surv_summary$n.risk,
      事件数 = surv_summary$n.event,
      删失数 = surv_summary$n.censor,
      生存概率 = round(surv_summary$surv, 4),
      置信区间下限 = round(surv_summary$lower, 4),
      置信区间上限 = round(surv_summary$upper, 4),
      check.names = FALSE
    )
    surv_df$组别 <- vapply(
      surv_df$组别,
      function(x) .format_survival_group_label(x, strata_var, strata_labels, overall_label),
      character(1)
    )
    if (!is.null(time_range) && length(time_range) == 2) {
      surv_df <- surv_df[surv_df$时间 >= min(time_range) & surv_df$时间 <= max(time_range), , drop = FALSE]
    }
    surv_df
  }

  # 生存分析数据表
  output$km_data_table <- renderDT({
    req(input$render_km_plot)
    validate(need(!is.null(fit()), "请先生成生存曲线后查看数据表。"))
    
    # 获取生存分析结果数据
    tryCatch({
      params <- committed_params()
      surv_df <- build_km_summary_df(fit(), strata_var = params$km_strata, strata_labels = params$strata_labels, overall_label = params$overall_group_label)
      if (!is.null(surv_df)) {
        
        DT::datatable(surv_df, options = list(
          pageLength = 10,
          scrollX = TRUE,
          columnDefs = list(
            list(className = 'dt-center', targets = 0:7)
          )
        )) %>%
          formatRound(columns = c("生存概率", "置信区间下限", "置信区间上限"), digits = 4)
      } else {
        data.frame(错误 = "无法生成生存分析数据表", 信息 = "请检查输入数据")
      }
    }, error = function(e) {
      data.frame(错误 = "生成数据表时出错", 信息 = e$message)
    })
  })
  
  output$survival_report <- renderUI({
    req(input$render_km_plot)
    data_local <- committed_filtered_data()
    validate(need(!is.null(fit()) && !is.null(data_local) && nrow(data_local) > 0, "请先生成生存曲线后查看统计报告。"))
    validate(need(!is.null(graphics_state$km_time) && !is.null(graphics_state$km_status), "请先选择时间与状态变量。"))
    
    fit_local <- fit()
    
    method_desc <- paste0(
      "当前采用 Kaplan-Meier 方法估计生存函数；删失定义为 ",
      ifelse(graphics_state$km_censor_value == "0", "0=删失, 1=事件", "1=删失, 0=事件"),
      "。"
    )
    
    if (!is.null(graphics_state$km_strata) && graphics_state$km_strata != "None") {
      method_desc <- paste0(
        method_desc,
        " 分层变量为 ",
        graphics_state$km_strata,
        "，比较各组生存曲线差异。"
      )
    } else {
      method_desc <- paste0(method_desc, " 未设置分层变量，输出总体生存曲线。")
    }
    
    if (!is.null(graphics_state$km_facet) && graphics_state$km_facet != "None" && !is.null(graphics_state$km_facet_values) && graphics_state$km_facet_values != "") {
      method_desc <- paste0(
        method_desc,
        " 当前分面筛选：",
        graphics_state$km_facet,
        " = ",
        graphics_state$km_facet_values,
        "。"
      )
    }
    
    logrank_p <- stats_results()$logrank_p
    
    med <- stats_results()$median_surv
    median_lines <- character(0)
    if (!is.null(med) && nrow(med) > 0) {
      for (i in seq_len(nrow(med))) {
        display_label <- .format_survival_group_label(med$strata[i], graphics_state$km_strata, graphics_state$strata_labels, graphics_state$overall_group_label)
        strata_prefix <- ifelse(display_label == graphics_state$overall_group_label, "", paste0(display_label, "："))
        median_lines <- c(
          median_lines,
          paste0(
            strata_prefix, "Median Survival Time: ",
            ifelse(is.finite(med$median[i]), formatC(med$median[i], format = "f", digits = 2), "NR"),
            " (95%CI ",
            ifelse(is.finite(med$lower[i]), formatC(med$lower[i], format = "f", digits = 2), "NA"), " - ",
            ifelse(is.finite(med$upper[i]), formatC(med$upper[i], format = "f", digits = 2), "NA"), ")"
          )
        )
      }
    }
    
    hr_lines <- stats_results()$hr_lines
    
    interpretation <- character(0)
    interpretation <- c(
      interpretation,
      paste0(
        "纳入样本量：", nrow(data_local),
        "；时间变量：", graphics_state$km_time,
        "；状态变量：", graphics_state$km_status, "。"
      )
    )
    
    if (!is.na(logrank_p)) {
      if (logrank_p < 0.05) {
        interpretation <- c(interpretation, paste0("Log-rank 检验 P值=", formatC(logrank_p, format = "f", digits = 3), "，提示组间生存曲线差异具有统计学意义。"))
      } else {
        interpretation <- c(interpretation, paste0("Log-rank 检验 P值=", formatC(logrank_p, format = "f", digits = 3), "，未见组间生存曲线显著差异。"))
      }
    }
    
    if (length(hr_lines) > 0) {
      interpretation <- c(interpretation, "Cox 回归结果显示不同分层水平相对风险的方向和强度可由 HR 与其95%CI 综合判断：95%CI 不跨 1 通常提示统计学差异。")
    }
    
    tagList(
      tags$div(
        style = "padding: 16px; background: #f8f9fa; border: 1px solid #e5e7eb; border-radius: 6px;",
        tags$h4(style = "margin-top: 0;", "方法解释"),
        tags$p(method_desc),
        tags$hr(),
        tags$h4("结果摘要"),
        tags$ul(lapply(median_lines, tags$li)),
        if (length(hr_lines) > 0) {
          tagList(
            tags$p(tags$b("Cox 风险比结果：")),
            tags$ul(lapply(hr_lines, tags$li))
          )
        },
        tags$hr(),
        tags$h4("智能统计解释"),
        tags$ul(lapply(interpretation, tags$li))
      )
    )
  })
  
  # 下载静态图
  output$download_plot <- downloadHandler(
    filename = function() {
      build_plot_export_filename("survival_plot", input$export_format)
    },
    content = function(file) {
      save_plot_export(
        file = file,
        plot_obj = create_surv_plot(),
        format = input$export_format,
        width = size_config()$export_width,
        height = size_config()$export_height,
                dpi = input$export_dpi %||% 600,
        bg = "white"
      )
    }
  )
  
  # 返回模块状态
  return(reactive({
    list(
      time_var = graphics_state$km_time %||% input$km_time,
      status_var = graphics_state$km_status %||% input$km_status,
      km_censor_value = graphics_state$km_censor_value %||% input$km_censor_value,
      strata_var = graphics_state$km_strata %||% input$strata_var,
      facet_var = graphics_state$km_facet %||% input$facet_var,
      facet_value = graphics_state$km_facet_values %||% input$facet_value,
      overall_group_label = graphics_state$overall_group_label %||% input$overall_group_label
    )
  }))
}
