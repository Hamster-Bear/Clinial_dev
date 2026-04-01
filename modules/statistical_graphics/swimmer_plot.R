library(ggplot2)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(cowplot)
library(scales)

swimmer_plot_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      graphics_config_tabs_box(
        id = id,
        title = "泳道图参数配置",
        collapsed = TRUE,
        tabs = list(
          tabPanel(
            "数据映射",
            br(),
            fluidRow(
              column(
                4,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "泳道核心映射"),
                  tags$div(
                    class = "panel-body",
                    selectizeInput(ns("subject_id"), "受试者ID变量", choices = NULL, width = "100%"),
                    selectInput(ns("lane_time_mode"), "泳道时间模式", choices = c("起始+结束时间" = "start_end", "ADY/时长变量" = "duration"), selected = "start_end", width = "100%"),
                    conditionalPanel(
                      condition = sprintf("input['%s'] === 'start_end'", ns("lane_time_mode")),
                      fluidRow(
                        column(6, selectizeInput(ns("start_time"), "起始时间变量", choices = NULL, width = "100%")),
                        column(6, selectizeInput(ns("end_time"), "结束时间变量", choices = NULL, width = "100%"))
                      )
                    ),
                    conditionalPanel(
                      condition = sprintf("input['%s'] === 'duration'", ns("lane_time_mode")),
                      selectizeInput(ns("duration_var"), "ADY/时长变量", choices = NULL, width = "100%")
                    ),
                    selectizeInput(ns("lane_color_by"), "泳道颜色分组", choices = NULL, width = "100%"),
                    selectizeInput(ns("ongoing_var"), "持续中标记变量", choices = NULL, width = "100%")
                  )
                )
              ),
              column(
                4,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "事件映射"),
                  tags$div(
                    class = "panel-body",
                    fluidRow(
                      column(6, actionButton(ns("add_event_map"), "添加事件变量组", class = "btn-primary btn-sm")),
                      column(6, actionButton(ns("remove_event_map"), "减少事件变量组", class = "btn-default btn-sm"))
                    ),
                    br(),
                    uiOutput(ns("event_mapping_ui"))
                  )
                )
              ),
              column(
                4,
                tags$div(
                  class = "panel panel-default",
                  tags$div(class = "panel-heading", "轨道与排序"),
                  tags$div(
                    class = "panel-body",
                    selectizeInput(ns("tracks"), "下方分组轨道(可多选)", choices = NULL, multiple = TRUE, width = "100%"),
                    selectInput(
                      ns("sort_mode"),
                      "受试者排序方式",
                      choices = c(
                        "随访时长-降序" = "duration_desc",
                        "随访时长-升序" = "duration_asc",
                        "结束时间-降序" = "end_desc",
                        "结束时间-升序" = "end_asc",
                        "受试者ID" = "subject"
                      ),
                      selected = "duration_desc",
                      width = "100%"
                    ),
                    selectInput(ns("track_mode"), "轨道默认展示方式", choices = c("颜色填充" = "color", "文本填充" = "text"), selected = "color", width = "100%"),
                    checkboxInput(ns("show_tracks"), "显示下方分组轨道", TRUE),
                    uiOutput(ns("track_mode_controls"))
                  )
                )
              )
            )
          ),
          tabPanel(
            "样式主题",
            br(),
            tabsetPanel(
              tabPanel(
                "文本与标题",
                textInput(ns("plot_title"), "主标题", value = "泳道图", width = "100%"),
                textInput(ns("plot_subtitle"), "副标题", value = "", width = "100%"),
                textAreaInput(ns("plot_caption"), "脚注", value = "", rows = 2, width = "100%"),
                fluidRow(
                  column(6, textInput(ns("plot_xlab"), "X轴标签", value = "时间", width = "100%")),
                  column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "受试者", width = "100%"))
                ),
                textInput(ns("lane_legend_title"), "泳道图例标题", value = "", width = "100%")
              ),
              tabPanel(
                "坐标与显示",
                fluidRow(
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "显示与图例"),
                      tags$div(
                        class = "panel-body",
                        checkboxInput(ns("show_legend"), "显示图例", TRUE),
                        fluidRow(
                          column(6, selectInput(ns("main_legend_position"), "主图图例位置", choices = c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom"), selected = "right", width = "100%")),
                          column(6, selectInput(ns("track_legend_position"), "轨道图例位置", choices = c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom"), selected = "right", width = "100%"))
                        ),
                        checkboxInput(ns("show_grid_lines"), "显示网格线", TRUE),
                        checkboxInput(ns("show_subject_labels"), "显示受试者标签", TRUE),
                        checkboxInput(ns("show_ongoing_arrow"), "持续中显示箭头", TRUE)
                      )
                    )
                  ),
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "坐标与尺寸"),
                      tags$div(
                        class = "panel-body",
                        selectInput(ns("axis_style"), "坐标轴样式", choices = c("默认" = "default", "经典XY轴(箭头)" = "classic_arrow"), selected = "default", width = "100%"),
                        selectInput(
                          ns("x_unit"),
                          "X轴单位换算",
                          choices = c("天" = "day", "周" = "week", "月(30.44天)" = "month", "年(365.25天)" = "year"),
                          selected = "day",
                          width = "100%"
                        ),
                        numericInput(ns("x_break_step"), "X轴刻度步长(0为自动)", value = 0, min = 0, step = 0.1, width = "100%"),
                        fluidRow(
                          column(6, sliderInput(ns("lane_size"), "泳道线宽", min = 0.8, max = 8, value = 4, step = 0.2, width = "100%")),
                          column(6, sliderInput(ns("event_size"), "事件点大小", min = 1, max = 8, value = 3.2, step = 0.2, width = "100%"))
                        )
                      )
                    )
                  )
                )
              ),
              tabPanel(
                "事件样式",
                fluidRow(
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "事件基础"),
                      tags$div(
                        class = "panel-body",
                        checkboxInput(ns("show_event_labels"), "显示事件文本标签", FALSE),
                        checkboxInput(ns("lock_event_style_refresh"), "锁定事件样式（变量刷新不重置）", TRUE),
                        selectInput(
                          ns("event_palette"),
                          "事件调色板",
                          choices = c("默认Hue" = "hue", "Set1" = "Set1", "Set2" = "Set2", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
                          selected = "Set1",
                          width = "100%"
                        ),
                        textInput(ns("event_legend_title"), "事件图例层标题(可选)", value = "", width = "100%"),
                        selectInput(ns("event_legend_position"), "事件图例位置", choices = c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom"), selected = "right", width = "100%")
                      )
                    )
                  ),
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "事件分组样式"),
                      tags$div(class = "panel-body", uiOutput(ns("event_group_style_controls")))
                    )
                  )
                )
              ),
              tabPanel(
                "泳道配色",
                fluidRow(
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "泳道主色"),
                      tags$div(
                        class = "panel-body",
                        sliderInput(ns("lane_alpha"), "泳道透明度", min = 0.3, max = 1, value = 0.9, step = 0.05, width = "100%"),
                        selectInput(
                          ns("lane_palette"),
                          "泳道调色板",
                          choices = c("默认Hue" = "hue", "Set2" = "Set2", "Set3" = "Set3", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
                          selected = "Set2",
                          width = "100%"
                        )
                      )
                    )
                  ),
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "分组颜色映射"),
                      tags$div(class = "panel-body", uiOutput(ns("lane_color_controls")))
                    )
                  )
                )
              ),
              tabPanel(
                "轨道与比例",
                fluidRow(
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "轨道显示"),
                      tags$div(
                        class = "panel-body",
                        colourpicker::colourInput(ns("track_text_bg_color"), "轨道文本底色", value = "#F7F7F7", width = "100%"),
                        textInput(ns("track_legend_title"), "轨道图例标题", value = "轨道分组", width = "100%"),
                        checkboxInput(ns("track_compact_mode"), "轨道紧凑模式", TRUE),
                        fluidRow(
                          column(6, sliderInput(ns("track_tile_height"), "轨道方框高度", min = 0.1, max = 1.4, value = 0.65, step = 0.05, width = "100%")),
                          column(6, sliderInput(ns("track_row_spacing"), "轨道行间距", min = 0, max = 0.8, value = 0.08, step = 0.02, width = "100%"))
                        )
                      )
                    )
                  ),
                  column(
                    6,
                    tags$div(
                      class = "panel panel-default",
                      tags$div(class = "panel-heading", "缺失值与版式"),
                      tags$div(
                        class = "panel-body",
                        selectInput(ns("missing_display_mode"), "空值显示方式", choices = c("空白" = "blank", "无" = "none", "NA" = "na", "破折号" = "dash", "自定义" = "custom"), selected = "na", width = "100%"),
                        conditionalPanel(
                          condition = sprintf("input['%s'] === 'custom'", ns("missing_display_mode")),
                          textInput(ns("missing_display_custom"), "自定义空值文本", value = "NA", width = "100%")
                        ),
                        sliderInput(ns("track_rel_height"), "下方表格占比", min = 0.5, max = 4, value = 0.5, step = 0.1, width = "100%"),
                        numericInput(ns("base_font_size"), "全局字号", value = 12, min = 8, max = 22, step = 1, width = "100%")
                      )
                    )
                  )
                )
              )
            )
          ),
          tabPanel(
            "输出与导出",
            br(),
            fluidRow(
              column(4, selectInput(ns("size_mode"), "尺寸模式", choices = c("宽图标准" = "wide_standard", "自定义尺寸" = "custom"), selected = "wide_standard", width = "100%")),
              column(4, selectInput(ns("export_format"), "导出格式", choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")),
              column(4, numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
            ),
            conditionalPanel(
              condition = sprintf("input['%s'] === 'custom'", ns("size_mode")),
              fluidRow(
                column(3, numericInput(ns("static_width_px"), "静态图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                column(3, numericInput(ns("static_height_px"), "静态图基础高度(px)", value = 760, min = 400, max = 1800, step = 20, width = "100%")),
                column(3, numericInput(ns("interactive_width_px"), "交互图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                column(3, numericInput(ns("interactive_height_px"), "交互图高度(px)", value = 620, min = 350, max = 1600, step = 20, width = "100%"))
              ),
              fluidRow(
                column(3, numericInput(ns("export_width_in"), "导出宽度(英寸)", value = 13, min = 6, max = 30, step = 0.5, width = "100%")),
                column(3, numericInput(ns("export_height_in"), "导出高度(英寸)", value = 9, min = 4, max = 24, step = 0.5, width = "100%"))
              )
            )
          )
        )
      )
    ),
    fluidRow(
      box(
        width = 12,
        title = "泳道图输出",
        status = "success",
        solidHeader = TRUE,
        fluidRow(
          column(6, div(style = "text-align: left; margin-bottom: 10px;", actionButton(ns("render_plot"), "生成图形", class = "btn-primary"))),
          column(6, div(style = "text-align: right; margin-bottom: 10px;", downloadButton(ns("dl_plot"), "下载图形", class = "btn-primary")))
        ),
        tabsetPanel(
          id = ns("output_tabs"),
          tabPanel("静态图", plotOutput(ns("static_plot"), height = "760px")),
          tabPanel("交互式图", plotly::plotlyOutput(ns("interactive_plot"), height = "620px")),
          tabPanel("泳道数据", DTOutput(ns("lane_table"))),
          tabPanel("事件数据", DTOutput(ns("event_table"))),
          tabPanel("分组轨道数据", DTOutput(ns("track_table")))
        )
      )
    )
  )
}

swimmer_plot_server <- function(input, output, session, data) {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  palette_values <- function(n, palette_name = "hue") {
    if (n <= 0) return(character(0))
    if (palette_name == "hue") return(scales::hue_pal()(n))
    if (palette_name == "viridis") return(grDevices::hcl.colors(n, "Viridis"))
    max_n <- min(max(n, 3), 12)
    base_vals <- RColorBrewer::brewer.pal(max_n, palette_name)
    if (n <= length(base_vals)) return(base_vals[seq_len(n)])
    grDevices::colorRampPalette(base_vals)(n)
  }
  shape_choice_values <- c("X" = 4, "实心圆" = 16, "空心圆" = 1, "实心方块" = 15, "空心方块" = 0, "实心三角" = 17, "空心三角" = 2, "菱形" = 18, "加号" = 3, "星号" = 8)

  pick_first <- function(candidates, choices) {
    m <- candidates[candidates %in% choices]
    if (length(m) == 0) NULL else m[[1]]
  }

  to_logical_flag <- function(x) {
    v <- tolower(as.character(x))
    v %in% c("1", "true", "t", "yes", "y", "ongoing", "continued")
  }

  first_non_missing <- function(x, default = "") {
    y <- x[!is.na(x) & nzchar(as.character(x))]
    if (length(y) == 0) default else as.character(y[[1]])
  }

  get_missing_text <- function() {
    mode <- input$missing_display_mode %||% "na"
    if (mode == "blank") return("")
    if (mode == "none") return("无")
    if (mode == "dash") return("-")
    if (mode == "custom") return(input$missing_display_custom %||% "NA")
    "NA"
  }

  format_missing_vec <- function(x) {
    x_chr <- as.character(x)
    miss_idx <- is.na(x) | is.na(x_chr) | !nzchar(trimws(x_chr))
    x_chr[miss_idx] <- get_missing_text()
    x_chr
  }

  get_var_label <- function(df, var_name) {
    if (is.null(var_name) || !nzchar(var_name) || !(var_name %in% names(df))) return(var_name)
    lbl <- attr(df[[var_name]], "label")
    if (!is.null(lbl) && nzchar(as.character(lbl))) as.character(lbl) else var_name
  }

  is_time_var <- function(x) {
    is.numeric(x) || inherits(x, "Date") || inherits(x, "POSIXt")
  }

  graphics_state <- reactiveValues(
    subject_id = NULL,
    lane_time_mode = "start_end",
    start_time = NULL,
    end_time = NULL,
    duration_var = NULL,
    lane_color_by = "",
    ongoing_var = "",
    tracks = character(0),
    columns_signature = NULL
  )
  event_map_count <- reactiveVal(1)
  event_ui_state <- reactiveVal(list())

  state_get <- function(i, key, default = NULL) {
    st <- event_ui_state()
    if (length(st) >= i && !is.null(st[[i]]) && !is.null(st[[i]][[key]])) {
      st[[i]][[key]]
    } else {
      default
    }
  }

  snapshot_event_ui_state <- function() {
    n_maps <- event_map_count()
    st_old <- event_ui_state()
    st_new <- vector("list", n_maps)
    for (i in seq_len(n_maps)) {
      st_new[[i]] <- list(
        event_time = input[[paste0("event_time_", i)]] %||% state_get(i, "event_time", ""),
        event_type = input[[paste0("event_type_", i)]] %||% state_get(i, "event_type", ""),
        event_label = input[[paste0("event_label_", i)]] %||% state_get(i, "event_label", ""),
        event_legend_title = input[[paste0("event_legend_title_", i)]] %||% state_get(i, "event_legend_title", ""),
        event_grp_col = input[[paste0("event_grp_col_", i)]] %||% state_get(i, "event_grp_col", NULL),
        event_grp_shape = input[[paste0("event_grp_shape_", i)]] %||% state_get(i, "event_grp_shape", NULL),
        event_grp_symbol_mode = input[[paste0("event_grp_symbol_mode_", i)]] %||% state_get(i, "event_grp_symbol_mode", "random_unique")
      )
    }
    if (length(st_old) > n_maps) {
      st_old <- st_old[seq_len(n_maps)]
    }
    event_ui_state(st_new)
  }

  refresh_event_mapping_choices <- function(all_vars, time_vars, event_time_candidates, event_type_candidates, event_label_candidates) {
    n_maps <- event_map_count()
    for (i in seq_len(n_maps)) {
      id_time <- paste0("event_time_", i)
      id_type <- paste0("event_type_", i)
      id_label <- paste0("event_label_", i)
      current_time <- isolate(input[[id_time]])
      current_type <- isolate(input[[id_type]])
      current_label <- isolate(input[[id_label]])
      if (is.null(current_time)) current_time <- state_get(i, "event_time", NULL)
      if (is.null(current_type)) current_type <- state_get(i, "event_type", NULL)
      if (is.null(current_label)) current_label <- state_get(i, "event_label", NULL)
      if (is.null(current_time)) current_time <- pick_first(event_time_candidates, time_vars) %||% ""
      if (is.null(current_type)) current_type <- pick_first(event_type_candidates, all_vars) %||% ""
      if (is.null(current_label)) current_label <- pick_first(event_label_candidates, all_vars) %||% ""
      updateSelectizeInput(session, id_time, choices = c("无" = "", time_vars), selected = ifelse(is.null(current_time), "", current_time), server = TRUE)
      updateSelectizeInput(session, id_type, choices = c("无" = "", all_vars), selected = ifelse(is.null(current_type), "", current_type), server = TRUE)
      updateSelectizeInput(session, id_label, choices = c("无" = "", all_vars), selected = ifelse(is.null(current_label), "", current_label), server = TRUE)
    }
  }

  observeEvent(data(), {
    req(data())
    snapshot_event_ui_state()
    all_vars <- names(data())
    time_vars <- get_time_vars(data())
    current_signature <- paste(all_vars, collapse = "|")
    if (!is.null(graphics_state$columns_signature) && identical(graphics_state$columns_signature, current_signature)) return()
    graphics_state$columns_signature <- current_signature

    subject_candidates <- c("USUBJID", "SUBJID", "SUBJECT", "PATIENT", "subject_id", "ID")
    start_candidates <- c("START", "START_TIME", "ASTDY", "TRTSTDY", "start_time", "START_DAY")
    end_candidates <- c("END", "END_TIME", "AENDY", "TRTEDY", "end_time", "END_DAY")
    duration_candidates <- c("ADY", "AVALDY", "DY", "DAY", "DURATION", "duration")
    color_candidates <- c("TRT", "TRTA", "ARM", "GROUP", "COHORT", "BOR")
    ongoing_candidates <- c("ONGOING", "CNSR", "CENSOR", "IS_ONGOING", "continued")
    event_time_candidates <- c("EVENT_TIME", "EVT_TIME", "ADT", "AVISITN", "event_time")
    event_type_candidates <- c("EVENT", "EVENT_TYPE", "BOR", "STATUS", "RESPONSE", "event_type")
    event_label_candidates <- c("EVENT_LABEL", "LABEL", "EVENT_TEXT", "AVALC", "event_label")

    selected_subject <- isolate(input$subject_id)
    if (is.null(selected_subject) || !nzchar(selected_subject) || !(selected_subject %in% all_vars)) {
      selected_subject <- graphics_state$subject_id
      if (is.null(selected_subject) || !(selected_subject %in% all_vars)) selected_subject <- pick_first(subject_candidates, all_vars)
    }

    selected_lane_mode <- isolate(input$lane_time_mode)
    if (is.null(selected_lane_mode) || !(selected_lane_mode %in% c("start_end", "duration"))) {
      selected_lane_mode <- graphics_state$lane_time_mode %||% "start_end"
    }

    selected_start <- isolate(input$start_time)
    if (is.null(selected_start) || !nzchar(selected_start) || !(selected_start %in% time_vars)) {
      selected_start <- graphics_state$start_time
      if (is.null(selected_start) || !(selected_start %in% time_vars)) selected_start <- pick_first(start_candidates, time_vars)
      if (is.null(selected_start) && length(time_vars) > 0) selected_start <- time_vars[[1]]
    }

    selected_end <- isolate(input$end_time)
    if (is.null(selected_end) || !nzchar(selected_end) || !(selected_end %in% time_vars)) {
      selected_end <- graphics_state$end_time
      if (is.null(selected_end) || !(selected_end %in% time_vars)) selected_end <- pick_first(end_candidates, time_vars)
      if (is.null(selected_end) && length(time_vars) > 1) selected_end <- time_vars[[2]]
    }

    selected_duration <- isolate(input$duration_var)
    if (is.null(selected_duration) || !nzchar(selected_duration) || !(selected_duration %in% time_vars)) {
      selected_duration <- graphics_state$duration_var
      if (is.null(selected_duration) || !(selected_duration %in% time_vars)) {
        selected_duration <- pick_first(duration_candidates, time_vars)
      }
    }
    if (!nzchar(selected_duration %||% "") && selected_lane_mode == "duration") {
      selected_lane_mode <- "start_end"
    }
    if ((is.null(input$lane_time_mode) || !nzchar(input$lane_time_mode %||% "")) && nzchar(selected_duration %||% "")) {
      selected_lane_mode <- "duration"
    }

    selected_color <- isolate(input$lane_color_by)
    if (is.null(selected_color) || !(selected_color %in% c("", all_vars))) {
      selected_color <- graphics_state$lane_color_by
      if (is.null(selected_color) || !(selected_color %in% c("", all_vars))) {
        selected_color <- pick_first(color_candidates, setdiff(all_vars, c(selected_subject, selected_start, selected_end)))
        if (is.null(selected_color)) selected_color <- ""
      }
    }

    selected_ongoing <- isolate(input$ongoing_var)
    if (is.null(selected_ongoing) || !(selected_ongoing %in% c("", all_vars))) {
      selected_ongoing <- graphics_state$ongoing_var
      if (is.null(selected_ongoing) || !(selected_ongoing %in% c("", all_vars))) {
        selected_ongoing <- pick_first(ongoing_candidates, all_vars)
        if (is.null(selected_ongoing)) selected_ongoing <- ""
      }
    }

    selected_tracks <- isolate(input$tracks)
    if (is.null(selected_tracks) || length(selected_tracks) == 0) selected_tracks <- graphics_state$tracks
    selected_tracks <- intersect(selected_tracks, all_vars)
    if (length(selected_tracks) == 0) {
      suggested_tracks <- c("TRT", "TRTA", "ARM", "COHORT", "BOR", "SEX", "RACE", "SITEID")
      selected_tracks <- head(setdiff(suggested_tracks[suggested_tracks %in% all_vars], c(selected_subject, selected_start, selected_end, selected_duration)), 3)
    }

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = selected_subject, server = TRUE)
    updateSelectInput(session, "lane_time_mode", selected = selected_lane_mode)
    updateSelectizeInput(session, "start_time", choices = time_vars, selected = selected_start, server = TRUE)
    updateSelectizeInput(session, "end_time", choices = time_vars, selected = selected_end, server = TRUE)
    updateSelectizeInput(session, "duration_var", choices = time_vars, selected = selected_duration, server = TRUE)
    updateSelectizeInput(session, "lane_color_by", choices = c("无" = "", all_vars), selected = selected_color, server = TRUE)
    updateSelectizeInput(session, "ongoing_var", choices = c("无" = "", all_vars), selected = selected_ongoing, server = TRUE)
    updateSelectizeInput(session, "tracks", choices = all_vars, selected = selected_tracks, server = TRUE)

    refresh_event_mapping_choices(all_vars, time_vars, event_time_candidates, event_type_candidates, event_label_candidates)
  }, ignoreInit = FALSE)

  observeEvent(input$add_event_map, {
    snapshot_event_ui_state()
    event_map_count(event_map_count() + 1)
    session$onFlushed(function() {
      if (is.null(data())) return()
      all_vars <- names(data())
      time_vars <- get_time_vars(data())
      event_time_candidates <- c("EVENT_TIME", "EVT_TIME", "ADT", "AVISITN", "event_time")
      event_type_candidates <- c("EVENT", "EVENT_TYPE", "BOR", "STATUS", "RESPONSE", "event_type")
      event_label_candidates <- c("EVENT_LABEL", "LABEL", "EVENT_TEXT", "AVALC", "event_label")
      refresh_event_mapping_choices(all_vars, time_vars, event_time_candidates, event_type_candidates, event_label_candidates)
    }, once = TRUE)
  })

  observeEvent(input$remove_event_map, {
    snapshot_event_ui_state()
    event_map_count(max(1, event_map_count() - 1))
  })

  observeEvent(event_map_count(), {
    st <- event_ui_state()
    n_maps <- event_map_count()
    if (length(st) > n_maps) event_ui_state(st[seq_len(n_maps)])
    req(data())
    all_vars <- names(data())
    time_vars <- get_time_vars(data())
    event_time_candidates <- c("EVENT_TIME", "EVT_TIME", "ADT", "AVISITN", "event_time")
    event_type_candidates <- c("EVENT", "EVENT_TYPE", "BOR", "STATUS", "RESPONSE", "event_type")
    event_label_candidates <- c("EVENT_LABEL", "LABEL", "EVENT_TEXT", "AVALC", "event_label")
    refresh_event_mapping_choices(all_vars, time_vars, event_time_candidates, event_type_candidates, event_label_candidates)
  }, ignoreInit = TRUE)

  output$event_mapping_ui <- renderUI({
    n_maps <- event_map_count()
    tagList(
      lapply(seq_len(n_maps), function(i) {
        tags$div(
          class = "panel panel-default",
          tags$div(class = "panel-heading", paste0("事件变量组 ", i)),
          tags$div(
            class = "panel-body",
            fluidRow(
              column(6, selectizeInput(session$ns(paste0("event_time_", i)), tags$span("事件时间变量 [数值/日期]", title = "该事件组的发生时间"), choices = NULL, width = "100%")),
              column(6, selectizeInput(session$ns(paste0("event_type_", i)), tags$span("事件类型变量 [字符/因子]", title = "该事件组的类别变量"), choices = NULL, width = "100%"))
            ),
            selectizeInput(session$ns(paste0("event_label_", i)), tags$span("事件标签变量 [字符，可选]", title = "事件点旁展示的文本"), choices = NULL, width = "100%"),
            textInput(session$ns(paste0("event_legend_title_", i)), paste0("事件图例主标题(组", i, ")"), value = state_get(i, "event_legend_title", ""), width = "100%")
          )
        )
      })
    )
  })

  observe({
    graphics_state$subject_id <- input$subject_id
    graphics_state$lane_time_mode <- input$lane_time_mode
    graphics_state$start_time <- input$start_time
    graphics_state$end_time <- input$end_time
    graphics_state$duration_var <- input$duration_var
    graphics_state$lane_color_by <- input$lane_color_by
    graphics_state$ongoing_var <- input$ongoing_var
    graphics_state$tracks <- input$tracks %||% character(0)
  })

  output$lane_color_controls <- renderUI({
    req(data())
    if (is.null(input$lane_color_by) || !nzchar(input$lane_color_by) || !(input$lane_color_by %in% names(data()))) {
      return(helpText("选择泳道颜色分组后，可在此为每个分组自定义颜色。"))
    }
    levels <- unique(as.character(data()[[input$lane_color_by]]))
    levels <- levels[!is.na(levels) & nzchar(levels)]
    levels <- head(levels, 12)
    if (length(levels) == 0) return(helpText("当前分组变量没有可用水平。"))
    defaults <- palette_values(length(levels), input$lane_palette %||% "hue")
    tagList(
      h5("泳道分组颜色"),
      lapply(seq_along(levels), function(i) {
        lv <- levels[[i]]
        colourpicker::colourInput(
          session$ns(paste0("lane_col_", digest::digest(lv, algo = "crc32"))),
          label = lv,
          value = defaults[[i]],
          width = "100%"
        )
      })
    )
  })

  output$event_group_style_controls <- renderUI({
    n_maps <- event_map_count()
    if (n_maps <= 0) return(NULL)
    defaults <- palette_values(n_maps, input$event_palette %||% "hue")
    default_shapes <- as.numeric(rep(unname(shape_choice_values), length.out = n_maps))
    lock_style <- isTRUE(input$lock_event_style_refresh)
    tagList(
      h5("事件组样式(每组独立图例)"),
      lapply(seq_len(n_maps), function(i) {
        legend_title <- trimws(input[[paste0("event_legend_title_", i)]] %||% state_get(i, "event_legend_title", ""))
        if (!nzchar(legend_title)) legend_title <- paste0("事件组", i)
        color_default <- if (lock_style) state_get(i, "event_grp_col", defaults[[i]]) else defaults[[i]]
        symbol_mode_default <- state_get(i, "event_grp_symbol_mode", "random_unique")
        shape_default <- state_get(i, "event_grp_shape", default_shapes[[i]])
        fluidRow(
          column(4, colourpicker::colourInput(session$ns(paste0("event_grp_col_", i)), label = paste0(legend_title, " 颜色"), value = color_default, width = "100%")),
          column(4, selectInput(session$ns(paste0("event_grp_symbol_mode_", i)), label = paste0(legend_title, " 符号分配"), choices = c("随机且不重复" = "random_unique", "单一指定" = "single"), selected = symbol_mode_default, width = "100%")),
          column(
            4,
            conditionalPanel(
              condition = sprintf("input['%s'] === 'single'", session$ns(paste0("event_grp_symbol_mode_", i))),
              selectInput(session$ns(paste0("event_grp_shape_", i)), label = paste0(legend_title, " 指定符号"), choices = shape_choice_values, selected = shape_default, width = "100%")
            )
          )
        )
      })
    )
  })

  output$track_mode_controls <- renderUI({
    req(input$tracks, data())
    selected_tracks <- input$tracks
    if (length(selected_tracks) == 0) {
      return(NULL)
    }
    track_label_map <- setNames(make.unique(vapply(selected_tracks, function(tr) get_var_label(data(), tr), character(1))), selected_tracks)
    tagList(
      h5("分组轨道展示方式"),
      lapply(selected_tracks, function(tr) {
        selectInput(
          session$ns(paste0("track_mode_", digest::digest(tr, algo = "crc32"))),
          label = track_label_map[[tr]],
          choices = c("颜色填充" = "color", "文本填充" = "text"),
          selected = input$track_mode %||% "color",
          width = "100%"
        )
      })
    )
  })

  final_plot <- reactiveVal(NULL)
  main_plot_obj <- reactiveVal(NULL)
  lane_data <- reactiveVal(NULL)
  event_data <- reactiveVal(NULL)
  track_data <- reactiveVal(NULL)
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

  observeEvent(input$render_plot, {
    req(data(), input$subject_id)

    tryCatch({
      df <- data()
      lane_has_group <- nzchar(input$lane_color_by %||% "") && input$lane_color_by %in% names(df)
      use_duration_mode <- identical(input$lane_time_mode %||% "start_end", "duration")
      if (use_duration_mode) {
        req(input$duration_var)
      } else {
        req(input$start_time, input$end_time)
      }
      unit_divisor <- switch(input$x_unit %||% "day", day = 1, week = 7, month = 30.4375, year = 365.25, 1)
      unit_label <- switch(input$x_unit %||% "day", day = "天", week = "周", month = "月", year = "年", "天")

      selected_tracks <- input$tracks %||% character(0)
      selected_tracks <- selected_tracks[selected_tracks %in% names(df)]
      track_label_map <- setNames(make.unique(vapply(selected_tracks, function(tr) get_var_label(df, tr), character(1))), selected_tracks)

      lane_time_cols <- if (use_duration_mode) c(input$duration_var) else c(input$start_time, input$end_time)
      lane_cols <- unique(c(input$subject_id, lane_time_cols, input$lane_color_by, input$ongoing_var, selected_tracks))
      lane_cols <- lane_cols[nzchar(lane_cols)]
      lane_cols <- lane_cols[lane_cols %in% names(df)]
      lane_df <- df[, lane_cols, drop = FALSE]

      names(lane_df)[names(lane_df) == input$subject_id] <- ".subject_id"
      if (use_duration_mode) {
        names(lane_df)[names(lane_df) == input$duration_var] <- ".duration_input"
      } else {
        names(lane_df)[names(lane_df) == input$start_time] <- ".start"
        names(lane_df)[names(lane_df) == input$end_time] <- ".end"
      }
      if (nzchar(input$lane_color_by %||% "") && input$lane_color_by %in% names(df)) {
        names(lane_df)[names(lane_df) == input$lane_color_by] <- ".lane_group"
      } else {
        lane_df$.lane_group <- "全部受试者"
      }
      if (nzchar(input$ongoing_var %||% "") && input$ongoing_var %in% names(df)) {
        names(lane_df)[names(lane_df) == input$ongoing_var] <- ".ongoing"
      } else {
        lane_df$.ongoing <- FALSE
      }
      for (tr in selected_tracks) {
        names(lane_df)[names(lane_df) == tr] <- paste0(".track__", tr)
      }
      track_cols_all <- grep("^\\.track__", names(lane_df), value = TRUE)

      lane_df <- lane_df %>%
        mutate(
          .subject_id = as.character(.subject_id),
          .lane_group = as.character(.lane_group),
          .ongoing = to_logical_flag(.ongoing)
        )

      date_mode <- FALSE
      if (use_duration_mode) {
        duration_is_date <- inherits(df[[input$duration_var]], "Date") || inherits(df[[input$duration_var]], "POSIXt")
        if (isTRUE(duration_is_date)) {
          lane_df <- lane_df %>%
            mutate(.duration_date = as.Date(.duration_input)) %>%
            filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.duration_date)) %>%
            group_by(.subject_id) %>%
            mutate(.duration_input = as.numeric(difftime(.duration_date, min(.duration_date, na.rm = TRUE), units = "days"))) %>%
            summarise(
              .start = 0,
              .end = max(.duration_input, na.rm = TRUE),
              .lane_group = first_non_missing(.lane_group, "全部受试者"),
              .ongoing = any(.ongoing, na.rm = TRUE),
              across(all_of(track_cols_all), ~ first_non_missing(as.character(.x), "NA")),
              .groups = "drop"
            )
        } else {
          lane_df$.duration_input <- as.numeric(lane_df$.duration_input)
          lane_df <- lane_df %>%
            filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.duration_input)) %>%
            group_by(.subject_id) %>%
            summarise(
              .start = 0,
              .end = max(.duration_input, na.rm = TRUE),
              .lane_group = first_non_missing(.lane_group, "全部受试者"),
              .ongoing = any(.ongoing, na.rm = TRUE),
              across(all_of(track_cols_all), ~ first_non_missing(as.character(.x), "NA")),
              .groups = "drop"
            )
        }
      } else {
        start_is_date <- inherits(df[[input$start_time]], "Date") || inherits(df[[input$start_time]], "POSIXt")
        end_is_date <- inherits(df[[input$end_time]], "Date") || inherits(df[[input$end_time]], "POSIXt")
        date_mode <- isTRUE(start_is_date && end_is_date)
      }

      if (!use_duration_mode && isTRUE(date_mode)) {
        start_dates <- as.Date(lane_df$.start)
        end_dates <- as.Date(lane_df$.end)
        swap_idx <- which(!is.na(start_dates) & !is.na(end_dates) & end_dates < start_dates)
        if (length(swap_idx) > 0) {
          tmp <- start_dates[swap_idx]
          start_dates[swap_idx] <- end_dates[swap_idx]
          end_dates[swap_idx] <- tmp
          showNotification("检测到结束日期早于起始日期，已自动交换。", type = "warning")
        }
        lane_df$.start_date <- start_dates
        lane_df$.end_date <- end_dates
        lane_df <- lane_df %>%
          filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.start_date), !is.na(.end_date)) %>%
          group_by(.subject_id) %>%
          summarise(
            .start_date = min(.start_date, na.rm = TRUE),
            .end_date = max(.end_date, na.rm = TRUE),
            .lane_group = first_non_missing(.lane_group, "全部受试者"),
            .ongoing = any(.ongoing, na.rm = TRUE),
            across(all_of(track_cols_all), ~ first_non_missing(as.character(.x), "NA")),
            .groups = "drop"
          ) %>%
          mutate(
            .start = 0,
            .end = as.numeric(difftime(.end_date, .start_date, units = "days"))
          )
      } else if (!use_duration_mode) {
        lane_df$.start <- as.numeric(lane_df$.start)
        lane_df$.end <- as.numeric(lane_df$.end)
        if (any(lane_df$.end < lane_df$.start, na.rm = TRUE)) {
          idx <- which(lane_df$.end < lane_df$.start)
          tmp <- lane_df$.start[idx]
          lane_df$.start[idx] <- lane_df$.end[idx]
          lane_df$.end[idx] <- tmp
          showNotification("检测到结束时间小于起始时间，已自动交换。", type = "warning")
        }
        lane_df <- lane_df %>%
          filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.start), !is.na(.end)) %>%
          group_by(.subject_id) %>%
          summarise(
            .start = min(.start, na.rm = TRUE),
            .end = max(.end, na.rm = TRUE),
            .lane_group = first_non_missing(.lane_group, "全部受试者"),
            .ongoing = any(.ongoing, na.rm = TRUE),
            across(all_of(track_cols_all), ~ first_non_missing(as.character(.x), "NA")),
            .groups = "drop"
          )
      }

      if (nrow(lane_df) == 0) stop("没有可用于绘图的有效泳道数据。")

      lane_df <- lane_df %>%
        mutate(.duration = .end - .start) %>%
        ungroup()

      if (input$sort_mode == "duration_desc") lane_df <- lane_df %>% arrange(desc(.duration), desc(.end))
      if (input$sort_mode == "duration_asc") lane_df <- lane_df %>% arrange(.duration, .end)
      if (input$sort_mode == "end_desc") lane_df <- lane_df %>% arrange(desc(.end), desc(.duration))
      if (input$sort_mode == "end_asc") lane_df <- lane_df %>% arrange(.end, .duration)
      if (input$sort_mode == "subject") lane_df <- lane_df %>% arrange(.subject_id)

      lane_df <- lane_df %>%
        mutate(
          .subject_factor = factor(.subject_id, levels = rev(.subject_id)),
          .start_plot = .start / unit_divisor,
          .end_plot = .end / unit_divisor,
          .duration_plot = .duration / unit_divisor
        )

      lane_df$.tooltip_lane <- paste0(
        "受试者: ", lane_df$.subject_id,
        "<br>起始: ", formatC(lane_df$.start_plot, format = "f", digits = 2), " ", unit_label,
        "<br>结束: ", formatC(lane_df$.end_plot, format = "f", digits = 2), " ", unit_label,
        "<br>时长: ", formatC(lane_df$.duration_plot, format = "f", digits = 2), " ", unit_label,
        ifelse(isTRUE(lane_has_group), paste0("<br>分组: ", lane_df$.lane_group), "")
      )

      event_list <- lapply(seq_len(event_map_count()), function(i) {
        event_time_var <- input[[paste0("event_time_", i)]] %||% ""
        event_type_var <- input[[paste0("event_type_", i)]] %||% ""
        event_label_var <- input[[paste0("event_label_", i)]] %||% ""
        if (!nzchar(event_time_var) || !nzchar(event_type_var) || !(event_time_var %in% names(df)) || !(event_type_var %in% names(df))) {
          return(NULL)
        }
        event_cols <- unique(c(input$subject_id, event_time_var, event_type_var, event_label_var))
        event_cols <- event_cols[nzchar(event_cols)]
        event_cols <- event_cols[event_cols %in% names(df)]
        tmp_df <- df[, event_cols, drop = FALSE]
        names(tmp_df)[names(tmp_df) == input$subject_id] <- ".subject_id"
        names(tmp_df)[names(tmp_df) == event_time_var] <- ".event_time"
        names(tmp_df)[names(tmp_df) == event_type_var] <- ".event_type"
        if (nzchar(event_label_var) && event_label_var %in% names(df)) {
          names(tmp_df)[names(tmp_df) == event_label_var] <- ".event_label"
        } else {
          tmp_df$.event_label <- ""
        }
        event_type_label <- get_var_label(df, event_type_var) %||% event_type_var
        event_source_title <- trimws(input[[paste0("event_legend_title_", i)]] %||% "")
        if (!nzchar(event_source_title)) {
          event_source_title <- event_type_label
        }
        tmp_df$.event_source <- event_source_title
        tmp_df$.event_group_index <- i
        tmp_df$.event_group_key <- paste0("G", i)
        event_time_is_date_i <- inherits(df[[event_time_var]], "Date") || inherits(df[[event_time_var]], "POSIXt")
        tmp_df <- tmp_df %>%
          mutate(
            .subject_id = as.character(.subject_id),
            .event_type = as.character(.event_type),
            .event_label = as.character(.event_label)
          )
        if (!use_duration_mode && isTRUE(date_mode) && isTRUE(event_time_is_date_i)) {
          tmp_df <- tmp_df %>%
            mutate(.event_date = as.Date(.event_time)) %>%
            left_join(lane_df %>% select(.subject_id, .start_date), by = ".subject_id") %>%
            mutate(.event_time = as.numeric(difftime(.event_date, .start_date, units = "days")))
        } else {
          tmp_df$.event_time <- as.numeric(tmp_df$.event_time)
        }
        tmp_df %>%
          filter(!is.na(.subject_id), !is.na(.event_time), nzchar(.event_type))
      })
      event_df <- dplyr::bind_rows(event_list)
      if (nrow(event_df) == 0) {
        event_df <- NULL
      } else {
        event_df <- event_df %>%
          semi_join(lane_df %>% select(.subject_id), by = ".subject_id") %>%
          mutate(
            .subject_factor = factor(.subject_id, levels = levels(lane_df$.subject_factor)),
            .event_time_plot = .event_time / unit_divisor
          )
      }

      track_cols <- grep("^\\.track__", names(lane_df), value = TRUE)
      if (length(track_cols) > 0) {
        track_df <- lane_df %>%
          mutate(across(all_of(track_cols), ~ as.character(.x))) %>%
          select(.subject_id, .subject_factor, all_of(track_cols)) %>%
          pivot_longer(
            cols = all_of(track_cols),
            names_to = ".track_name",
            values_to = ".track_value"
          ) %>%
          mutate(
            .track_name_raw = sub("^\\.track__", "", .track_name),
            .track_name = unname(track_label_map[.track_name_raw]),
            .track_name = ifelse(is.na(.track_name) | !nzchar(.track_name), .track_name_raw, .track_name),
            .track_value = format_missing_vec(.track_value),
            .track_name = factor(.track_name, levels = rev(unname(track_label_map[selected_tracks])))
          )
      } else {
        track_df <- NULL
      }

      lane_levels <- unique(lane_df$.lane_group)
      lane_colors <- setNames(palette_values(length(lane_levels), input$lane_palette %||% "hue"), lane_levels)
      for (lv in lane_levels) {
        id <- paste0("lane_col_", digest::digest(lv, algo = "crc32"))
        if (!is.null(input[[id]]) && nzchar(input[[id]])) lane_colors[[lv]] <- input[[id]]
      }
      lane_single_color <- lane_colors[[1]] %||% "#4E79A7"
      has_event_data <- !is.null(event_df) && nrow(event_df) > 0

      if (isTRUE(lane_has_group)) {
        if (isTRUE(has_event_data)) {
          lane_df$.lane_color <- unname(lane_colors[as.character(lane_df$.lane_group)])
          p_main <- ggplot(lane_df, aes(y = .subject_factor, text = .tooltip_lane)) +
            geom_segment(
              aes(x = .start_plot, xend = .end_plot, yend = .subject_factor, color = .lane_color),
              linewidth = input$lane_size,
              alpha = input$lane_alpha,
              lineend = "round"
            ) +
            scale_color_identity() +
            labs(
              title = ifelse(nzchar(input$plot_title %||% ""), input$plot_title, "泳道图"),
              subtitle = input$plot_subtitle %||% "",
              caption = input$plot_caption %||% "",
              x = ifelse(nzchar(input$plot_xlab %||% ""), input$plot_xlab, "时间"),
              y = ifelse(nzchar(input$plot_ylab %||% ""), input$plot_ylab, "受试者")
            ) +
            theme_minimal(base_size = input$base_font_size, base_family = "sans") +
            theme(
              panel.grid.major.y = element_blank(),
              axis.text.y = if (isTRUE(input$show_subject_labels)) element_text() else element_blank(),
              axis.ticks.y = if (isTRUE(input$show_subject_labels)) element_line() else element_blank(),
              legend.position = if (isTRUE(input$show_legend)) (input$event_legend_position %||% "right") else "none"
            )
        } else {
          p_main <- ggplot(lane_df, aes(y = .subject_factor, text = .tooltip_lane)) +
            geom_segment(
              aes(x = .start_plot, xend = .end_plot, yend = .subject_factor, color = .lane_group),
              linewidth = input$lane_size,
              alpha = input$lane_alpha,
              lineend = "round"
            ) +
            scale_color_manual(values = lane_colors) +
            labs(
              title = ifelse(nzchar(input$plot_title %||% ""), input$plot_title, "泳道图"),
              subtitle = input$plot_subtitle %||% "",
              caption = input$plot_caption %||% "",
              x = ifelse(nzchar(input$plot_xlab %||% ""), input$plot_xlab, "时间"),
              y = ifelse(nzchar(input$plot_ylab %||% ""), input$plot_ylab, "受试者"),
              color = ifelse(nzchar(input$lane_legend_title %||% ""), input$lane_legend_title, input$lane_color_by)
            ) +
            theme_minimal(base_size = input$base_font_size, base_family = "sans") +
            theme(
              panel.grid.major.y = element_blank(),
              axis.text.y = if (isTRUE(input$show_subject_labels)) element_text() else element_blank(),
              axis.ticks.y = if (isTRUE(input$show_subject_labels)) element_line() else element_blank(),
              legend.position = if (isTRUE(input$show_legend)) (input$main_legend_position %||% "right") else "none"
            )
        }
      } else {
        p_main <- ggplot(lane_df, aes(y = .subject_factor, text = .tooltip_lane)) +
          geom_segment(
            aes(x = .start_plot, xend = .end_plot, yend = .subject_factor),
            linewidth = input$lane_size,
            alpha = input$lane_alpha,
            color = lane_single_color,
            lineend = "round"
          ) +
          labs(
            title = ifelse(nzchar(input$plot_title %||% ""), input$plot_title, "泳道图"),
            subtitle = input$plot_subtitle %||% "",
            caption = input$plot_caption %||% "",
            x = ifelse(nzchar(input$plot_xlab %||% ""), input$plot_xlab, "时间"),
            y = ifelse(nzchar(input$plot_ylab %||% ""), input$plot_ylab, "受试者")
          ) +
          theme_minimal(base_size = input$base_font_size, base_family = "sans") +
          theme(
            panel.grid.major.y = element_blank(),
            axis.text.y = if (isTRUE(input$show_subject_labels)) element_text() else element_blank(),
            axis.ticks.y = if (isTRUE(input$show_subject_labels)) element_line() else element_blank(),
            legend.position = if (isTRUE(input$show_legend)) (input$main_legend_position %||% "right") else "none"
          ) +
          guides(color = "none")
      }

      x_break_step <- suppressWarnings(as.numeric(input$x_break_step %||% 0))
      if (!is.na(x_break_step) && x_break_step > 0) {
        x_min <- min(lane_df$.start_plot, na.rm = TRUE)
        x_max <- max(lane_df$.end_plot, na.rm = TRUE)
        x_from <- floor(x_min / x_break_step) * x_break_step
        x_to <- ceiling(x_max / x_break_step) * x_break_step
        p_main <- p_main + scale_x_continuous(breaks = seq(x_from, x_to, by = x_break_step))
      }

      event_legend_df <- NULL
      if (!is.null(event_df) && nrow(event_df) > 0) {
        key_info <- event_df %>%
          group_by(.event_group_key) %>%
          summarise(
            .event_group_index = first(.event_group_index),
            .event_source = first(.event_source),
            .groups = "drop"
          ) %>%
          arrange(.event_group_index)
        event_keys <- key_info$.event_group_key
        event_label_map <- setNames(key_info$.event_source, key_info$.event_group_key)
        source_default_colors <- setNames(palette_values(length(event_keys), input$event_palette %||% "hue"), event_keys)
        event_colors_by_key <- source_default_colors
        for (k in seq_along(event_keys)) {
          idx <- key_info$.event_group_index[[k]]
          id <- paste0("event_grp_col_", idx)
          if (!is.null(input[[id]]) && nzchar(input[[id]])) event_colors_by_key[[event_keys[[k]]]] <- input[[id]]
        }
        shape_pool <- unique(as.numeric(unname(shape_choice_values)))
        event_shapes_by_key <- setNames(rep(NA_real_, length(event_keys)), event_keys)
        used_shapes <- numeric(0)
        for (k in seq_along(event_keys)) {
          idx <- key_info$.event_group_index[[k]]
          mode_i <- input[[paste0("event_grp_symbol_mode_", idx)]] %||% "random_unique"
          if (identical(mode_i, "single")) {
            chosen <- suppressWarnings(as.numeric(input[[paste0("event_grp_shape_", idx)]]))
            if (is.na(chosen)) chosen <- shape_pool[[((k - 1) %% length(shape_pool)) + 1]]
            event_shapes_by_key[[event_keys[[k]]]] <- chosen
            used_shapes <- c(used_shapes, chosen)
          }
        }
        for (k in seq_along(event_keys)) {
          if (!is.na(event_shapes_by_key[[event_keys[[k]]]])) next
          available <- setdiff(shape_pool, used_shapes)
          chosen <- if (length(available) > 0) available[[1]] else shape_pool[[((k - 1) %% length(shape_pool)) + 1]]
          event_shapes_by_key[[event_keys[[k]]]] <- chosen
          used_shapes <- c(used_shapes, chosen)
        }

        event_df$.tooltip_event <- paste0(
          "受试者: ", event_df$.subject_id,
          "<br>事件时间: ", formatC(event_df$.event_time_plot, format = "f", digits = 2), " ", unit_label,
          "<br>事件组: ", event_df$.event_source,
          "<br>事件类型: ", event_df$.event_type,
          ifelse(nzchar(event_df$.event_label), paste0("<br>标签: ", event_df$.event_label), "")
        )

        p_main <- p_main +
          geom_point(
            data = event_df,
            aes(x = .event_time_plot, y = .subject_factor, shape = .event_group_key, color = .event_group_key, text = .tooltip_event),
            size = input$event_size,
            stroke = 0.4
          ) +
          scale_shape_manual(values = event_shapes_by_key, breaks = event_keys, labels = unname(event_label_map[event_keys])) +
          scale_color_manual(values = event_colors_by_key, breaks = event_keys, labels = unname(event_label_map[event_keys]))

        if (isTRUE(input$show_event_labels)) {
          p_main <- p_main +
            geom_text(
              data = event_df %>% filter(nzchar(.event_label)),
              aes(x = .event_time_plot, y = .subject_factor, label = .event_label),
              nudge_y = 0.3,
              size = max(2.8, input$base_font_size * 0.22),
              check_overlap = TRUE
            )
        }

        p_main <- p_main + guides(shape = "none", color = "none")
        event_legend_df <- data.frame(
          .key = event_keys,
          .label = unname(event_label_map[event_keys]),
          .color = unname(event_colors_by_key[event_keys]),
          .shape = as.numeric(unname(event_shapes_by_key[event_keys])),
          stringsAsFactors = FALSE
        )
      }

      if (isTRUE(input$show_ongoing_arrow)) {
        ongoing_df <- lane_df %>% filter(.ongoing)
        if (nrow(ongoing_df) > 0) {
          if (isTRUE(lane_has_group)) {
            p_main <- p_main +
              geom_segment(
                data = ongoing_df,
                aes(x = .end_plot - 0.001, xend = .end_plot + max(.duration_plot, na.rm = TRUE) * 0.03, y = .subject_factor, yend = .subject_factor, color = .lane_group),
                linewidth = input$lane_size * 0.45,
                arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
                inherit.aes = FALSE
              )
          } else {
            p_main <- p_main +
              geom_segment(
                data = ongoing_df,
                aes(x = .end_plot - 0.001, xend = .end_plot + max(.duration_plot, na.rm = TRUE) * 0.03, y = .subject_factor, yend = .subject_factor),
                linewidth = input$lane_size * 0.45,
                color = lane_single_color,
                arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
                inherit.aes = FALSE
              )
          }
        }
      }

      if (!isTRUE(input$show_grid_lines)) {
        p_main <- p_main + theme(panel.grid = element_blank(), panel.grid.minor = element_blank())
      }
      if ((input$axis_style %||% "default") == "classic_arrow") {
        n_y <- length(levels(lane_df$.subject_factor))
        x_rng <- range(c(lane_df$.start_plot, lane_df$.end_plot), na.rm = TRUE)
        x_span <- max(1e-6, diff(x_rng))
        x_axis_start <- x_rng[1] - 0.03 * x_span
        x_axis_end <- x_rng[2] + 0.06 * x_span
        p_main <- p_main +
          theme_classic(base_size = input$base_font_size, base_family = "sans") +
          theme(
            axis.line = element_blank(),
            axis.text.y = if (isTRUE(input$show_subject_labels)) element_text() else element_blank(),
            axis.ticks.y = if (isTRUE(input$show_subject_labels)) element_line() else element_blank(),
            legend.position = if (isTRUE(input$show_legend)) (input$main_legend_position %||% "right") else "none",
            plot.margin = margin(10, 20, 12, 16)
          ) +
          coord_cartesian(clip = "off") +
          annotate("segment", x = x_axis_start, xend = x_axis_end, y = 0.5, yend = 0.5, arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"), linewidth = 0.45, color = "black") +
          annotate("segment", x = x_axis_start, xend = x_axis_start, y = 0.5, yend = n_y + 0.55, arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"), linewidth = 0.45, color = "black")
      }

      if (is.null(track_df) || !isTRUE(input$show_tracks)) {
        p_combined <- p_main
      } else {
        track_mode_map <- setNames(
          vapply(selected_tracks, function(tr) {
            id <- paste0("track_mode_", digest::digest(tr, algo = "crc32"))
            mode_val <- input[[id]]
            if (is.null(mode_val) || !nzchar(mode_val)) input$track_mode %||% "color" else mode_val
          }, character(1)),
          selected_tracks
        )

        track_df <- track_df %>%
          mutate(
            .track_mode = unname(track_mode_map[.track_name_raw]),
            .track_mode = ifelse(is.na(.track_mode), input$track_mode %||% "color", .track_mode)
          )

        text_track_df <- track_df %>% filter(.track_mode == "text")
        color_track_df <- track_df %>%
          filter(.track_mode == "color") %>%
          mutate(.track_legend_key = paste0(as.character(.track_name), " : ", .track_value))
        track_keys <- unique(color_track_df$.track_legend_key)
        track_colors <- setNames(palette_values(length(track_keys), "Set3"), track_keys)

        compact_mode <- isTRUE(input$track_compact_mode)
        track_row_spacing_eff <- if (compact_mode) 0 else max(0, input$track_row_spacing %||% 0)
        track_tile_height_eff <- if (track_row_spacing_eff <= 1e-8) 1 else (if (compact_mode) min(0.35, input$track_tile_height %||% 0.65) else (input$track_tile_height %||% 0.65))
        track_rel_eff <- if (compact_mode) min(0.35, input$track_rel_height %||% 0.5) else (input$track_rel_height %||% 0.5)

        p_track <- ggplot(track_df, aes(x = .subject_factor, y = .track_name))
        if (nrow(color_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = color_track_df, aes(fill = .track_legend_key), color = "white", height = track_tile_height_eff)
        }
        if (nrow(text_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = text_track_df, fill = input$track_text_bg_color, color = "white", height = track_tile_height_eff) +
            geom_text(data = text_track_df, aes(label = .track_value), size = max(2.8, input$base_font_size * 0.22))
        }
        if (nrow(color_track_df) > 0) {
          p_track <- p_track + scale_fill_manual(values = track_colors)
        }
        p_track <- p_track +
          labs(x = NULL, y = NULL, fill = ifelse(nzchar(input$track_legend_title %||% ""), input$track_legend_title, "轨道分组")) +
          scale_y_discrete(expand = expansion(add = c(track_row_spacing_eff, track_row_spacing_eff))) +
          theme_minimal(base_size = max(9, input$base_font_size - 1), base_family = "sans") +
          theme(
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            panel.grid = element_blank(),
            legend.position = if (isTRUE(input$show_legend) && nrow(color_track_df) > 0) (input$track_legend_position %||% "right") else "none"
          )

        track_n <- length(unique(as.character(track_df$.track_name)))
        main_rel_h <- 1
        track_rel_h <- max(0.12, min(2.0, track_rel_eff))

        p_combined <- cowplot::plot_grid(
          p_main,
          p_track,
          ncol = 1,
          rel_heights = c(main_rel_h, track_rel_h),
          align = "v",
          axis = "lr"
        )
      }

      if (isTRUE(input$show_legend) && !is.null(event_legend_df) && nrow(event_legend_df) > 0) {
        legend_title <- trimws(input$event_legend_title %||% "")
        p_event_legend <- ggplot(event_legend_df, aes(y = factor(.label, levels = rev(.label)))) +
          geom_point(aes(x = 0, shape = .shape, color = .color), size = input$event_size, stroke = 0.4) +
          geom_text(aes(x = 0.22, label = .label), hjust = 0, size = max(3, input$base_font_size * 0.24)) +
          scale_shape_identity() +
          scale_color_identity() +
          coord_cartesian(xlim = c(-0.1, 1), clip = "off") +
          theme_void(base_family = "sans") +
          theme(
            plot.margin = margin(8, 8, 8, 8),
            plot.title = element_text(size = max(10, input$base_font_size), face = "bold")
          )
        if (nzchar(legend_title)) {
          p_event_legend <- p_event_legend + ggtitle(legend_title)
        }
        legend_pos <- input$event_legend_position %||% "right"
        if (legend_pos == "left") {
          p_combined <- cowplot::plot_grid(p_event_legend, p_combined, ncol = 2, rel_widths = c(0.35, 1), align = "h", axis = "tb")
        } else if (legend_pos == "top") {
          p_combined <- cowplot::plot_grid(p_event_legend, p_combined, ncol = 1, rel_heights = c(0.35, 1), align = "v", axis = "lr")
        } else if (legend_pos == "bottom") {
          p_combined <- cowplot::plot_grid(p_combined, p_event_legend, ncol = 1, rel_heights = c(1, 0.35), align = "v", axis = "lr")
        } else {
          p_combined <- cowplot::plot_grid(p_combined, p_event_legend, ncol = 2, rel_widths = c(1, 0.35), align = "h", axis = "tb")
        }
      }

      final_plot(p_combined)
      main_plot_obj(p_main)
      lane_data(lane_df)
      event_data(event_df)
      track_data(track_df)
      showNotification("泳道图生成完成", type = "message")
    }, error = function(e) {
      final_plot(NULL)
      main_plot_obj(NULL)
      lane_data(NULL)
      event_data(NULL)
      track_data(NULL)
      showNotification(paste("泳道图生成错误:", e$message), type = "error")
    })
  })

  output$static_plot <- renderPlot({
    validate(need(!is.null(final_plot()), "请先完成参数设置并点击“生成图形”。"))
    final_plot()
  }, width = function() {
    as.integer(size_config()$static_width)
  }, height = function() {
    cfg <- size_config()
    base_h <- as.integer(cfg$static_height)
    td <- track_data()
    if (is.null(td) || !isTRUE(input$show_tracks)) {
      base_h
    } else {
      track_n <- length(unique(as.character(td$.track_name)))
      if (isTRUE(input$track_compact_mode)) {
        base_h
      } else {
        tile_eff <- ifelse((input$track_row_spacing %||% 0) <= 1e-8, 1, input$track_tile_height %||% 0.65)
        base_h + as.integer(min(180, 18 * tile_eff * track_n))
      }
    }
  })

  output$interactive_plot <- plotly::renderPlotly({
    validate(need(!is.null(main_plot_obj()), "请先生成泳道图后查看交互式图。"))
    cfg <- size_config()
    ggplotly(main_plot_obj(), tooltip = "text", width = as.integer(cfg$interactive_width), height = as.integer(cfg$interactive_height))
  })

  output$lane_table <- renderDT({
    validate(need(!is.null(lane_data()) && nrow(lane_data()) > 0, "当前无可展示的泳道数据。"))
    datatable(lane_data(), options = list(pageLength = 15, scrollX = TRUE))
  })

  output$event_table <- renderDT({
    ed <- event_data()
    validate(need(!is.null(ed) && nrow(ed) > 0, "未配置事件映射或无事件数据"))
    datatable(ed, options = list(pageLength = 15, scrollX = TRUE))
  })

  output$track_table <- renderDT({
    td <- track_data()
    validate(need(!is.null(td), "未选择分组轨道变量"))
    out <- td %>% select(.subject_id, .track_name, .track_value) %>% tidyr::pivot_wider(names_from = .track_name, values_from = .track_value)
    datatable(out, options = list(pageLength = 15, scrollX = TRUE))
  })

  output$dl_plot <- downloadHandler(
    filename = function() {
      build_plot_export_filename("swimmer_plot", input$export_format)
    },
    content = function(file) {
      req(final_plot())
      cfg <- size_config()
      save_plot_export(
        file = file,
        plot_obj = final_plot(),
        format = input$export_format,
        width = cfg$export_width,
        height = cfg$export_height,
        dpi = input$export_dpi %||% 600
      )
    }
  )

  return(reactive({
    event_mappings <- lapply(seq_len(event_map_count()), function(i) {
      list(
        event_time = input[[paste0("event_time_", i)]] %||% "",
        event_type = input[[paste0("event_type_", i)]] %||% "",
        event_label = input[[paste0("event_label_", i)]] %||% "",
        event_legend_title = input[[paste0("event_legend_title_", i)]] %||% ""
      )
    })
    list(
      subject_id = input$subject_id,
      lane_time_mode = input$lane_time_mode,
      start_time = input$start_time,
      end_time = input$end_time,
      duration_var = input$duration_var,
      event_mappings = event_mappings,
      lock_event_style_refresh = input$lock_event_style_refresh,
      event_legend_title = input$event_legend_title,
      x_break_step = input$x_break_step,
      tracks = input$tracks %||% character(0),
      size_mode = input$size_mode,
      export_width_in = size_config()$export_width,
      export_height_in = size_config()$export_height
    )
  }))
}
