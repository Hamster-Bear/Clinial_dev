# 森林图子模块
# 提供列映射、表格配置、图形设置和文本自定义
# 数据由父模块传入

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

if (!exists("app_card_box", mode = "function") ||
    !exists("app_card_note", mode = "function") ||
    !exists("app_result_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}
if (file.exists("modules/common/graphics/graphics_result_copy.R")) {
  source("modules/common/graphics/graphics_result_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics", "graphics_result_copy.R"))
}
if (file.exists("modules/common/graphics/graphics_export_copy.R")) {
  source("modules/common/graphics/graphics_export_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics", "graphics_export_copy.R"))
}

forest_plot_ui <- function(id) {
  ns <- NS(id)
  copy <- GRAPHICS_RESULT_COPY$forest
  export_copy <- GRAPHICS_EXPORT_COPY$forest

  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "选择分析模式并配置列映射",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("在预处理数据和原始数据两种模式之间切换，并配置列映射和表格列。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "核心映射",
                  br(),
                  graphics_card_panel_ui(
                    "数据模式与核心映射",
                    tagList(
                      radioButtons(
                        ns("data_mode"), "数据模式",
                        choices = c("预处理数据 (Pre-calculated)" = "precalculated",
                                    "原始数据分析 (Raw Data Analysis)" = "raw_data"),
                        selected = "precalculated", inline = TRUE
                      ),
                      hr(),
                      conditionalPanel(
                        condition = paste0("input['", ns("data_mode"), "'] == 'precalculated'"),
                        graphics_column_mapping_panel_ui(
                          ns,
                          title = "预处理数据列映射",
                          fields = list(
                            list(
                              list(id = "subgroup_col", label = "变量名称列 (如: 性别)", type = "select", column = 4),
                              list(id = "study_col", label = "分组值列 (如: 男/女)", type = "select", column = 4),
                              list(id = "estimate_col", label = "估计值列 (HR/OR)", type = "select", column = 4)
                            ),
                            list(
                              list(id = "lower_col", label = "下限列", type = "select", column = 4),
                              list(id = "upper_col", label = "上限列", type = "select", column = 4)
                            )
                          ),
                          help_text = "当前预处理模式总计需要 5 个必需列。"
                        )
                      ),
                      conditionalPanel(
                        condition = paste0("input['", ns("data_mode"), "'] == 'raw_data'"),
                        graphics_card_panel_ui(
                          "回归分析配置 (Cox / Logistic)",
                          tagList(
                            radioButtons(
                              ns("regression_type"), "回归模型类型",
                              choices = c("Cox 比例风险回归 (生存数据)" = "cox",
                                          "Logistic 回归 (二分类结局)" = "logistic"),
                              selected = "cox", inline = TRUE
                            ),
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
                            radioButtons(
                              ns("analysis_method"), "分析方法",
                              choices = c("单因素分析 (Univariable)" = "univariate",
                                          "多因素分析 (Multivariable)" = "multivariate"),
                              selected = "univariate", inline = TRUE
                            ),
                            actionButton(ns("run_analysis"), "运行分析", class = "btn-info btn-block", icon = icon("calculator"))
                          ),
                          status_class = "primary"
                        )
                      )
                    )
                  )
                ),
                tabPanel(
                  "分组/分面/轨道/附加变量",
                  br(),
                  graphics_table_panel_ui(
                    ns,
                    title = "表格显示设置",
                    selection_id = "selected_table_cols",
                    selection_label = "表格列选择",
                    config_title = "列显示配置（点击展开后编辑）",
                    config_ui = uiOutput(ns("column_config_ui")),
                    help_text = "森林图不单独提供分面或轨道变量；表格列选择与列显示配置在此页签中设置。"
                  )
                )
              )
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "图形与样式",
          subtitle = "设置标题、坐标、配色与参考线",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置标题脚注、配色模式、坐标范围、表格宽度比例和参考线。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "标题与说明",
                  br(),
                  graphics_text_label_panel_ui(
                    ns,
                    title = "标题与说明",
                    fields = list(
                      list(
                        list(id = "plot_title", label = "图形标题", type = "text", selected = "交互式森林图", placeholder = "输入图形标题", column = 6),
                        list(id = "x_axis_label", label = "X轴标签", type = "text", selected = "风险比", placeholder = "输入X轴标签", column = 6)
                      ),
                      list(
                        list(id = "title_size", label = "标题字体大小", type = "numeric", value = 16, min = 10, max = 24, step = 1, column = 6),
                        list(id = "axis_label_size", label = "轴标签字体大小", type = "numeric", value = 12, min = 8, max = 16, step = 1, column = 6)
                      ),
                      list(list(id = "plot_footer", label = "图形脚注", type = "textarea", selected = "注: 点大小反映研究权重, 区间线表示95%置信区间. | 参考线位于HR=1.0处.", rows = 3)),
                      list(
                        list(id = "footer_size", label = "脚注字体大小", type = "numeric", value = 10, min = 6, max = 14, step = 1, column = 4),
                        list(id = "footer_color", label = "脚注颜色", type = "color", value = "gray40", column = 4),
                        list(id = "show_footer", label = "显示脚注", type = "checkbox", value = TRUE, column = 4)
                      )
                    ),
                    extra_ui = graphics_font_family_pair_ui(ns, latin_id = "base_family", cjk_id = "cjk_family"),
                    help_text = "提示：使用\"|\"符号表示换行，例如：\"主标题|副标题\"。"
                  )
                ),
                tabPanel(
                  "显示与坐标",
                  br(),
                  graphics_axis_proportion_panel_ui(
                    ns,
                    title = "显示与坐标",
                    prepend_ui = tagList(
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
                      graphics_axis_tick_format_controls_ui(
                        ns,
                        decimals_id = "x_axis_decimals",
                        decimals_label = "X轴小数位数",
                        decimals_value = 1,
                        percent_id = "percentage_format",
                        percent_label = "显示百分号(%)",
                        percent_value = FALSE
                      )
                    ),
                    fields = list(
                      list(
                        list(id = "display_height", label = "显示高度(像素)", type = "slider", value = 800, min = 400, max = 1200, step = 50, column = 12)
                      )
                    ),
                    help_text = "这里主要控制前端显示高度与 X 轴显示格式，不改变统计结果。"
                  )
                ),
                tabPanel(
                  "图层样式",
                  br(),
                  graphics_palette_layout_panel_ui(
                    ns,
                    title = "表格与配色",
                    fields = list(
                      list(
                        list(id = "table_font_size", label = "表格字体大小", type = "slider", value = 3.0, min = 2, max = 5, step = 0.1, column = 6),
                        list(id = "header_font_size", label = "表头字体大小", type = "slider", value = 3.5, min = 2.5, max = 6, step = 0.1, column = 6)
                      ),
                      list(
                        list(id = "first_col_width", label = "第一列宽度比例", type = "numeric", value = 0.45, min = 0.1, max = 0.5, step = 0.05, column = 6),
                        list(id = "max_chars_per_line", label = "第一列每行最大字符数", type = "numeric", value = 45, min = 5, max = 30, step = 1, column = 6)
                      ),
                      list(
                        list(id = "color_mode", label = "颜色模式", type = "radio", choices = c("交替颜色" = "alternating", "随机亚组颜色" = "random_subgroup"), selected = "alternating", inline = TRUE)
                      )
                    ),
                    extra_ui = tagList(
                      fluidRow(
                        column(6, sliderInput(ns("line_width"), "置信区间线宽", min = 0.5, max = 3, value = 1.2, step = 0.1, width = "100%")),
                        column(6, sliderInput(ns("line_height"), "端帽长度", min = 0.05, max = 0.3, value = 0.15, step = 0.01, width = "100%"))
                      ),
                      conditionalPanel(
                        condition = paste0("input['", ns("color_mode"), "'] == 'alternating'"),
                        colourInput(ns("color_picker"), "选择交替颜色", value = "#E6F3FF", width = "100%"),
                        sliderInput(ns("alpha"), "颜色透明度", min = 0.1, max = 1, value = 0.4, step = 0.1, width = "100%")
                      ),
                      conditionalPanel(
                        condition = paste0("input['", ns("color_mode"), "'] == 'random_subgroup'"),
                        selectInput(ns("color_palette"), "颜色调色板", choices = c("Set1", "Set2", "Set3", "Pastel1", "Pastel2", "Dark2", "Accent", "Paired", "Spectral"), selected = "Set1", width = "100%"),
                        sliderInput(ns("subgroup_alpha"), "颜色透明度", min = 0.1, max = 1, value = 0.7, step = 0.1, width = "100%")
                      )
                    ),
                    help_text = "交替颜色模式：奇数亚组使用选择的颜色，偶数亚组使用白色；随机亚组颜色模式：每个亚组使用不同的随机颜色。"
                  )
                ),
                tabPanel(
                  "参考线",
                  br(),
                  graphics_reference_threshold_panel_ui(
                    ns,
                    title = "参考线",
                    toggle_id = "show_ref_line",
                    toggle_label = "显示参考线",
                    toggle_value = TRUE,
                    conditional_ui = tagList(
                      graphics_reference_line_ui(
                        ns,
                        "ref_line",
                        label = "参考线",
                        default_value = 1.0,
                        default_color = "#1A1A1A",
                        default_linetype = "solid",
                        default_linewidth = 0.8
                      )
                    ),
                    help_text = "森林图当前仅提供 X 轴参考线；位置、颜色、线型和线宽由公共参考线控件统一管理。"
                  )
                )
              )
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "输出与导出",
          subtitle = export_copy$subtitle,
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          app_card_note(export_copy$note),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "尺寸与画布",
                  br(),
                  graphics_card_panel_ui(
                    "尺寸与画布",
                    tagList(
                      fluidRow(
                        column(6, numericInput(ns("plot_width"), "宽度(英寸)", value = 14, min = 8, max = 20, step = 1, width = "100%")),
                        column(6, numericInput(ns("plot_height"), "高度(英寸)", value = 10, min = 6, max = 16, step = 1, width = "100%"))
                      ),
                      sliderInput(ns("plot_ratio"), "表格/图形宽度比", min = 0.3, max = 0.7, value = 0.55, step = 0.05, width = "100%"),
                      helpText("森林图导出中，宽高控制输出尺寸，表格/图形宽度比控制左右布局。")
                    )
                  )
                ),
                tabPanel(
                  "导出参数",
                  br(),
                  graphics_export_panel_ui(
                    ns,
                    title = "导出参数",
                    include_render_button = FALSE,
                    include_size_mode = FALSE,
                    include_download_button = FALSE
                  )
                )
              )
          )
        )
      )
    ),
    fluidRow(
      column(
        12,
        app_card_box(
          width = 12,
          title = "结果区",
          subtitle = copy$result_card$subtitle,
          tone = "success",
          status = "success",
          solidHeader = FALSE,
          app_card_note(copy$result_card$note),
          graphics_output_action_bar_ui(ns, render_button_id = "generate", download_id = "download_plot"),
          tabsetPanel(
            id = ns("output_tabs"),
            tabPanel(
              "静态图",
              app_result_panel(
                title = "静态图结果",
                note = copy$static_plot$note,
                tone = "success",
                uiOutput(ns("plot_ui"))
              )
            ),
            tabPanel(
              "交互图",
              app_result_panel(
                title = "交互图",
                note = "森林图当前未提供独立交互图结果。",
                tone = "info",
                graphics_card_panel_ui(
                  "交互图",
                  helpText("森林图当前未提供独立交互图结果。")
                )
              )
            ),
            tabPanel(
              "数据",
              app_result_panel(
                title = "数据预览与统计报告",
                note = copy$data_tab$note,
                tone = "warning",
                tabsetPanel(
                  tabPanel("数据预览", DTOutput(ns("data_preview"))),
                  tabPanel("统计报告", uiOutput(ns("analysis_report_ui")))
                )
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
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
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
  pending_mapping_restore <- reactiveVal(NULL)
  
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

  forest_task_state_exclude_patterns <- c(
    graphics_task_input_exclude_patterns(),
    "^name_",
    "^align_"
  )

  apply_forest_mapping_inputs <- function(cols, restore_state = NULL) {
    cols <- forest_normalize_selected_columns(cols)
    if (length(cols) == 0) {
      return(invisible(NULL))
    }

    restore_mode <- if (is.list(restore_state) && !is.null(restore_state$mode)) {
      restore_state$mode
    } else {
      isolate(input$data_mode) %||% "precalculated"
    }
    restore_extra_state <- if (is.list(restore_state) && is.list(restore_state$extra_state)) {
      restore_state$extra_state
    } else {
      list()
    }

    mapping_plan <- forest_build_mapping_restore_plan(
      available_cols = cols,
      current_state = list(
        subgroup_col = isolate(input$subgroup_col),
        study_col = isolate(input$study_col),
        estimate_col = isolate(input$estimate_col),
        lower_col = isolate(input$lower_col),
        upper_col = isolate(input$upper_col),
        time_col = isolate(input$time_col),
        status_col = isolate(input$status_col),
        outcome_col = isolate(input$outcome_col),
        covariates = isolate(input$covariates)
      ),
      extra_state = restore_extra_state,
      mode = restore_mode
    )

    updateSelectInput(session, "subgroup_col", choices = cols, selected = mapping_plan$subgroup_col)
    updateSelectInput(session, "study_col", choices = cols, selected = mapping_plan$study_col)
    updateSelectInput(session, "estimate_col", choices = cols, selected = mapping_plan$estimate_col)
    updateSelectInput(session, "lower_col", choices = cols, selected = mapping_plan$lower_col)
    updateSelectInput(session, "upper_col", choices = cols, selected = mapping_plan$upper_col)
    updateSelectInput(session, "time_col", choices = cols, selected = mapping_plan$time_col)
    updateSelectInput(session, "status_col", choices = cols, selected = mapping_plan$status_col)
    updateSelectInput(session, "outcome_col", choices = cols, selected = mapping_plan$outcome_col)
    updateSelectizeInput(session, "covariates", choices = cols, selected = mapping_plan$covariates, server = TRUE)

    if (is.list(restore_state) && isTRUE(mapping_plan$ready)) {
      pending_mapping_restore(NULL)
    }

    invisible(mapping_plan)
  }

  # 观察数据变化，更新列选择
  observe({
    req(data())
    
    cols <- names(data())
    if (length(cols) == 0) return()

    apply_forest_mapping_inputs(cols, pending_mapping_restore())

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
        user_selections$alignments[[col]] <- forest_default_column_alignment(col)
      }
    }
  })
  
  # 当数据变化时更新selectizeInput的选项（不自动选择任何列）
  observe({
    req(data())
    cols <- names(data())
    if (length(cols) == 0) return()
    
    # 获取当前选择
    current_selected <- forest_normalize_selected_columns(isolate(user_selections$selected_cols))
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
    selected_cols <- forest_normalize_selected_columns(input$selected_table_cols)
    
    # 防止循环：只有当选择实际发生变化时才更新reactiveValues
    current <- forest_normalize_selected_columns(isolate(user_selections$selected_cols))
    if (!identical(sort(selected_cols), sort(current))) {
      persisted <- forest_persist_selected_column_inputs(
        input = input,
        selected_cols = current,
        display_names = isolate(user_selections$display_names),
        alignments = isolate(user_selections$alignments)
      )
      user_selections$display_names <- persisted$display_names
      user_selections$alignments <- persisted$alignments
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
                                        forest_default_column_alignment(col))
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
    persisted <- forest_persist_selected_column_inputs(
      input = input,
      selected_cols = selected_cols,
      display_names = isolate(user_selections$display_names),
      alignments = isolate(user_selections$alignments)
    )
    user_selections$display_names <- persisted$display_names
    user_selections$alignments <- persisted$alignments
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

  forest_result_data <- reactive({
    if (input$data_mode == "precalculated") {
      req(data(), input$subgroup_col, input$study_col, input$estimate_col, input$lower_col, input$upper_col)
      forest_normalize_result_schema(
        df = data(),
        mode = "precalculated",
        cols_map = list(
          subgroup = input$subgroup_col,
          study = input$study_col,
          estimate = input$estimate_col,
          lower = input$lower_col,
          upper = input$upper_col
        ),
        on_missing = function(missing_cols) {
          showNotification(paste("缺少必要列:", paste(missing_cols, collapse = ", ")), type = "error")
        }
      )
    } else {
      req(analysis_results())
      forest_normalize_result_schema(
        df = analysis_results(),
        mode = "raw_data",
        cols_map = list(
          subgroup = "Variable",
          study = "Level",
          estimate = "Estimate",
          lower = "Lower",
          upper = "Upper"
        )
      )
    }
  })
  
  # 数据预览
  output$data_preview <- renderDT({
    if (input$data_mode == "raw_data" && input$run_analysis == 0) {
      req(data())
      return(datatable(data(), options = list(pageLength = 10, scrollX = TRUE)))
    }

    preview_df <- forest_result_data()
    req(preview_df)
    preview_df <- preview_df[, setdiff(names(preview_df), c(
      "forest_subgroup", "forest_label", "forest_estimate", "forest_lower",
      "forest_upper", "forest_source_mode"
    )), drop = FALSE]

    if (input$data_mode == "precalculated") {
      datatable(preview_df,
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
    } else {
      datatable(preview_df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
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
    } else {
      req(input$outcome_col)
      outcome_var <- input$outcome_col
    }
    
    out <- forest_run_analysis_pipeline(
      df = df,
      reg_type = reg_type,
      method = method,
      covariates = covariates,
      time_var = time_var %||% NULL,
      status_var = status_var %||% NULL,
      outcome_var = outcome_var %||% NULL
    )

    if (!is.null(out)) {
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
    df <- forest_result_data()
    req(df)
    
    # 添加原始行ID以保持顺序
    df$original_row_id <- seq_len(nrow(df))
    
    # 计算y位置（从顶部到底部）
    df <- df %>% arrange(desc(original_row_id))
    df$y_pos <- 1:nrow(df)
    
    # 处理亚组
    df$subgroup_mapped <- df$forest_subgroup
    
    # 处理超出范围的值
    x_min_val <- ifelse(is.numeric(input$x_min), input$x_min, 0)
    x_max_val <- ifelse(is.numeric(input$x_max), input$x_max, 100)
    
    df$estimate_adj <- df$forest_estimate
    df$lower_adj <- df$forest_lower
    df$upper_adj <- df$forest_upper
    
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
    plotOutput(ns("forest_plot"), height = paste0(input$display_height, "px"))
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
    font_spec <- graphics_resolve_font_spec(
      base_family = input$base_family %||% "sans",
      cjk_family = input$cjk_family %||% "Noto Sans SC"
    )
    plot_family <- font_spec$unified
    layout_family <- font_spec$layout
    
    column_state <- forest_collect_selected_column_state(
      selected_cols = user_selections$selected_cols,
      display_names = isolate(user_selections$display_names),
      alignments = isolate(user_selections$alignments)
    )
    column_alignments <- column_state$alignments
    custom_column_names <- column_state$display_names
    table_cols <- column_state$selected_cols
    
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

    ref_line_spec <- if (isTRUE(input$show_ref_line %||% TRUE)) {
      graphics_collect_reference_line_spec(
        input = input,
        id_prefix = "ref_line",
        orientation = "v",
        fallback_value = 1.0,
        fallback_color = "#1A1A1A",
        fallback_linetype = "solid",
        fallback_linewidth = 0.8
      )
    } else {
      NULL
    }
    
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
      theme_minimal(base_size = 12, base_family = layout_family) +
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
                                  alignments, custom_names, first_col_width, max_chars_per_line,
                                  font_family) {
      subgroup_col_name <- if ("forest_source_mode" %in% names(data) && identical(data$forest_source_mode[[1]], "raw_data")) {
        "Variable"
      } else {
        input$subgroup_col
      }
      estimate_col_names <- if ("forest_source_mode" %in% names(data) && identical(data$forest_source_mode[[1]], "raw_data")) {
        c("Estimate", "Lower", "Upper")
      } else {
        c(input$estimate_col, input$lower_col, input$upper_col)
      }
      
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
          if (!is.null(subgroup_col_name) && identical(col_name, subgroup_col_name)) {
            # 标记每个亚组的第一行
            subgroup_first <- !duplicated(table_data$subgroup_mapped)
            # 只保留亚组第一行的值，其他行设为空字符串
            col_values[!subgroup_first] <- ""
          }
          
          # 对数值列应用智能格式化
          # raw_data 模式下，P_Value_Str 已经是格式化后的字符串
          # 这里主要处理 Estimate、Lower、Upper 或用户传入的原始数值
          
          is_numeric_col <- col_name %in% estimate_col_names
          
          if (is_numeric_col) {
             # 尝试转换为数值并格式化
             # 保留 NA 和空字符串
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
                    fontface = "bold", size = header_font_size, family = font_family)
        
        # 添加列内容
        table_plot <- table_plot +
          geom_text(aes_string(x = adjusted_x_pos, y = "y_pos",
                               label = paste0("table_col_", i)),
                    hjust = hjust_val, vjust = 0.5, size = table_font_size, family = font_family,
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
        theme_void(base_family = font_family) +
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
                                    column_alignments, custom_column_names, first_col_width, max_chars_per_line,
                                    layout_family)
    
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
                 fontface = 'bold', size = title_size, hjust = 0.5,
                 fontfamily = layout_family)
    
    # 动态生成脚注
    footer_text <- plot_footer
    if (any(data$out_of_range_low | data$out_of_range_high, na.rm = TRUE)) {
      footer_text <- paste0(footer_text, " ")
    }
    
    footer_gg <- ggdraw() +
      draw_label(footer_text,
                 size = footer_size, hjust = 0, x = 0.02,
                 color = footer_color,
                 fontfamily = layout_family)
    
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
      export_fmt <- if (is.null(input$export_format) || !nzchar(input$export_format)) "png" else input$export_format
      build_plot_export_filename("forest_plot", export_fmt, include_time = TRUE)
    },
    content = function(file) {
      export_fmt <- if (is.null(input$export_format) || !nzchar(input$export_format)) "png" else input$export_format
      export_dpi <- suppressWarnings(as.numeric(input$export_dpi))
      if (is.na(export_dpi) || !is.finite(export_dpi)) export_dpi <- 600
      save_plot_export(
        file = file,
        plot_obj = forest_plot_reactive(),
        format = export_fmt,
        width = input$plot_width,
        height = input$plot_height,
        dpi = export_dpi,
        bg = "white"
      )
    }
  )

  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    input_state <- graphics_task_payload_input_state(state)
    extra_state <- graphics_task_payload_extra_state(state)
    pending_mapping_restore(list(
      mode = input_state$data_mode %||% input$data_mode %||% "precalculated",
      extra_state = extra_state
    ))

    graphics_restore_task_input_state(
      session,
      list(input_state = input_state, extra_state = list()),
      exclude_ids = c(
        "generate", "run_analysis", "selected_table_cols",
        "subgroup_col", "study_col", "estimate_col", "lower_col", "upper_col",
        "time_col", "status_col", "outcome_col", "covariates"
      ),
      exclude_patterns = forest_task_state_exclude_patterns,
      defer = FALSE
    )

    df_current <- data()
    if (!is.null(df_current)) {
      cols <- names(df_current)
      apply_forest_mapping_inputs(cols, pending_mapping_restore())
      restored <- forest_restore_selected_column_state(
        session = session,
        extra_state = extra_state,
        selection_input_id = "selected_table_cols",
        current_display_names = isolate(user_selections$display_names),
        current_alignments = isolate(user_selections$alignments),
        available_cols = cols
      )
      user_selections$display_names <- restored$display_names
      user_selections$alignments <- restored$alignments
      user_selections$selected_cols <- restored$selected_cols
    } else {
      restored <- forest_restore_selected_column_state(
        session = session,
        extra_state = extra_state,
        selection_input_id = "selected_table_cols",
        current_display_names = isolate(user_selections$display_names),
        current_alignments = isolate(user_selections$alignments)
      )
      user_selections$display_names <- restored$display_names
      user_selections$alignments <- restored$alignments
      user_selections$selected_cols <- restored$selected_cols
    }

    invisible(TRUE)
  }

  list(
    state = reactive({
      column_state <- forest_collect_selected_column_state(
        selected_cols = user_selections$selected_cols,
        display_names = isolate(user_selections$display_names),
        alignments = isolate(user_selections$alignments)
      )
      graphics_build_task_state(
        input,
        extra_state = list(
          subgroup_col = input$subgroup_col,
          study_col = input$study_col,
          estimate_col = input$estimate_col,
          lower_col = input$lower_col,
          upper_col = input$upper_col,
          time_col = input$time_col,
          status_col = input$status_col,
          outcome_col = input$outcome_col,
          covariates = input$covariates,
          selected_table_cols = column_state$selected_cols,
          display_names = column_state$display_names,
          alignments = column_state$alignments
        ),
        exclude_ids = c("generate", "run_analysis", "selected_table_cols"),
        exclude_patterns = forest_task_state_exclude_patterns
      )
    }),
    apply_state = apply_state
  )
}
