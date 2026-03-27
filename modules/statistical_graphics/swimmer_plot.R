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
      box(
        width = 12,
        title = "泳道图参数配置",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = FALSE,
        fluidRow(
          column(
            6,
            wellPanel(
              style = "height: 650px; overflow-y: auto;",
              h4("数据与变量设置", style = "color: #007bff; margin-top: 0;"),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "泳道核心映射"),
                tags$div(
                  class = "panel-body",
                  selectizeInput(ns("subject_id"), "受试者ID变量", choices = NULL, width = "100%"),
                  fluidRow(
                    column(6, selectizeInput(ns("start_time"), "起始时间变量(数值/日期)", choices = NULL, width = "100%")),
                    column(6, selectizeInput(ns("end_time"), "结束时间变量(数值/日期)", choices = NULL, width = "100%"))
                  ),
                  selectizeInput(ns("lane_color_by"), "泳道颜色分组", choices = NULL, width = "100%"),
                  selectizeInput(ns("ongoing_var"), "持续中标记变量", choices = NULL, width = "100%")
                )
              ),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "事件映射"),
                tags$div(
                  class = "panel-body",
                  fluidRow(
                    column(6, selectizeInput(ns("event_time"), "事件时间变量(数值/日期)", choices = NULL, width = "100%")),
                    column(6, selectizeInput(ns("event_type"), "事件类型变量", choices = NULL, width = "100%"))
                  ),
                  selectizeInput(ns("event_label"), "事件标签变量", choices = NULL, width = "100%"),
                  checkboxInput(ns("show_event_labels"), "显示事件文本标签", FALSE)
                )
              ),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "轨道与排序"),
                tags$div(
                  class = "panel-body",
                  selectizeInput(ns("tracks"), "下方分组轨道", choices = NULL, multiple = TRUE, width = "100%"),
                  fluidRow(
                    column(
                      6,
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
                      )
                    ),
                    column(
                      6,
                      selectInput(
                        ns("track_mode"),
                        "轨道默认展示方式",
                        choices = c("颜色填充" = "color", "文本填充" = "text"),
                        selected = "color",
                        width = "100%"
                      )
                    )
                  ),
                  checkboxInput(ns("show_tracks"), "显示下方分组轨道", TRUE),
                  uiOutput(ns("track_mode_controls"))
                )
              )
            )
          ),
          column(
            6,
            wellPanel(
              style = "height: 650px; overflow-y: auto;",
              h4("图形与样式设置", style = "color: #007bff; margin-top: 0;"),
              tabsetPanel(
                tabPanel(
                  "文本与布局",
                  br(),
                  actionButton(ns("render_plot"), "生成图形", icon = icon("chart-line"), class = "btn-primary btn-block", style = "font-weight: bold; margin-bottom: 12px;"),
                  textInput(ns("plot_title"), "主标题", value = "泳道图", width = "100%"),
                  textInput(ns("plot_subtitle"), "副标题", value = "", width = "100%"),
                  textAreaInput(ns("plot_caption"), "脚注", value = "", rows = 2, width = "100%"),
                  fluidRow(
                    column(6, textInput(ns("plot_xlab"), "X轴标签", value = "时间", width = "100%")),
                    column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "受试者", width = "100%"))
                  ),
                  textInput(ns("lane_legend_title"), "泳道图例标题", value = "", width = "100%"),
                  textInput(ns("event_legend_title"), "事件图例标题", value = "", width = "100%")
                ),
                tabPanel(
                  "配色与比例",
                  br(),
                  checkboxInput(ns("show_legend"), "显示图例", TRUE),
                  checkboxInput(ns("show_ongoing_arrow"), "持续中显示箭头", TRUE),
                  selectInput(
                    ns("x_unit"),
                    "X轴单位换算",
                    choices = c("天" = "day", "周" = "week", "月(30.44天)" = "month", "年(365.25天)" = "year"),
                    selected = "day",
                    width = "100%"
                  ),
                  fluidRow(
                    column(6, sliderInput(ns("lane_size"), "泳道线宽", min = 0.8, max = 8, value = 4, step = 0.2, width = "100%")),
                    column(6, sliderInput(ns("event_size"), "事件点大小", min = 1, max = 8, value = 3.2, step = 0.2, width = "100%"))
                  ),
                  sliderInput(ns("lane_alpha"), "泳道透明度", min = 0.3, max = 1, value = 0.9, step = 0.05, width = "100%"),
                  selectInput(
                    ns("lane_palette"),
                    "泳道调色板",
                    choices = c("默认Hue" = "hue", "Set2" = "Set2", "Set3" = "Set3", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
                    selected = "Set2",
                    width = "100%"
                  ),
                  selectInput(
                    ns("event_palette"),
                    "事件调色板",
                    choices = c("默认Hue" = "hue", "Set1" = "Set1", "Set2" = "Set2", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
                    selected = "Set1",
                    width = "100%"
                  ),
                  uiOutput(ns("lane_color_controls")),
                  uiOutput(ns("event_color_controls")),
                  sliderInput(ns("track_rel_height"), "下方表格占比", min = 0.4, max = 4, value = 1.2, step = 0.1, width = "100%"),
                  numericInput(ns("base_font_size"), "全局字号", value = 12, min = 8, max = 22, step = 1, width = "100%")
                )
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
          column(
            12,
            div(
              style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 10px;",
              div(
                style = "margin-right: 10px; width: 150px;",
                selectInput(ns("export_format"), NULL, choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")
              ),
              downloadButton(ns("dl_plot"), "下载图形", class = "btn-primary")
            )
          )
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

  pick_first <- function(candidates, choices) {
    m <- candidates[candidates %in% choices]
    if (length(m) == 0) NULL else m[[1]]
  }

  to_logical_flag <- function(x) {
    v <- tolower(as.character(x))
    v %in% c("1", "true", "t", "yes", "y", "ongoing", "continued")
  }

  is_time_var <- function(x) {
    is.numeric(x) || inherits(x, "Date") || inherits(x, "POSIXt")
  }

  graphics_state <- reactiveValues(
    subject_id = NULL,
    start_time = NULL,
    end_time = NULL,
    lane_color_by = "",
    ongoing_var = "",
    event_time = "",
    event_type = "",
    event_label = "",
    tracks = character(0),
    columns_signature = NULL
  )

  observeEvent(data(), {
    req(data())
    all_vars <- names(data())
    time_vars <- names(data())[sapply(data(), is_time_var)]
    current_signature <- paste(all_vars, collapse = "|")
    if (!is.null(graphics_state$columns_signature) && identical(graphics_state$columns_signature, current_signature)) return()
    graphics_state$columns_signature <- current_signature

    subject_candidates <- c("USUBJID", "SUBJID", "SUBJECT", "PATIENT", "subject_id", "ID")
    start_candidates <- c("START", "START_TIME", "ASTDY", "TRTSTDY", "start_time", "START_DAY")
    end_candidates <- c("END", "END_TIME", "AENDY", "TRTEDY", "end_time", "END_DAY")
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

    selected_event_time <- isolate(input$event_time)
    if (is.null(selected_event_time) || !(selected_event_time %in% c("", time_vars))) {
      selected_event_time <- graphics_state$event_time
      if (is.null(selected_event_time) || !(selected_event_time %in% c("", time_vars))) {
        selected_event_time <- pick_first(event_time_candidates, time_vars)
        if (is.null(selected_event_time)) selected_event_time <- ""
      }
    }

    selected_event_type <- isolate(input$event_type)
    if (is.null(selected_event_type) || !(selected_event_type %in% c("", all_vars))) {
      selected_event_type <- graphics_state$event_type
      if (is.null(selected_event_type) || !(selected_event_type %in% c("", all_vars))) {
        selected_event_type <- pick_first(event_type_candidates, all_vars)
        if (is.null(selected_event_type)) selected_event_type <- ""
      }
    }

    selected_event_label <- isolate(input$event_label)
    if (is.null(selected_event_label) || !(selected_event_label %in% c("", all_vars))) {
      selected_event_label <- graphics_state$event_label
      if (is.null(selected_event_label) || !(selected_event_label %in% c("", all_vars))) {
        selected_event_label <- pick_first(event_label_candidates, all_vars)
        if (is.null(selected_event_label)) selected_event_label <- ""
      }
    }

    selected_tracks <- isolate(input$tracks)
    if (is.null(selected_tracks) || length(selected_tracks) == 0) selected_tracks <- graphics_state$tracks
    selected_tracks <- intersect(selected_tracks, all_vars)
    if (length(selected_tracks) == 0) {
      suggested_tracks <- c("TRT", "TRTA", "ARM", "COHORT", "BOR", "SEX", "RACE", "SITEID")
      selected_tracks <- head(setdiff(suggested_tracks[suggested_tracks %in% all_vars], c(selected_subject, selected_start, selected_end, selected_event_time)), 3)
    }

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = selected_subject, server = TRUE)
    updateSelectizeInput(session, "start_time", choices = time_vars, selected = selected_start, server = TRUE)
    updateSelectizeInput(session, "end_time", choices = time_vars, selected = selected_end, server = TRUE)
    updateSelectizeInput(session, "lane_color_by", choices = c("无" = "", all_vars), selected = selected_color, server = TRUE)
    updateSelectizeInput(session, "ongoing_var", choices = c("无" = "", all_vars), selected = selected_ongoing, server = TRUE)
    updateSelectizeInput(session, "event_time", choices = c("无" = "", time_vars), selected = selected_event_time, server = TRUE)
    updateSelectizeInput(session, "event_type", choices = c("无" = "", all_vars), selected = selected_event_type, server = TRUE)
    updateSelectizeInput(session, "event_label", choices = c("无" = "", all_vars), selected = selected_event_label, server = TRUE)
    updateSelectizeInput(session, "tracks", choices = all_vars, selected = selected_tracks, server = TRUE)
  }, ignoreInit = FALSE)

  observe({
    graphics_state$subject_id <- input$subject_id
    graphics_state$start_time <- input$start_time
    graphics_state$end_time <- input$end_time
    graphics_state$lane_color_by <- input$lane_color_by
    graphics_state$ongoing_var <- input$ongoing_var
    graphics_state$event_time <- input$event_time
    graphics_state$event_type <- input$event_type
    graphics_state$event_label <- input$event_label
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

  output$event_color_controls <- renderUI({
    req(data())
    if (is.null(input$event_type) || !nzchar(input$event_type) || !(input$event_type %in% names(data()))) {
      return(helpText("选择事件类型变量后，可在此为每个事件类型自定义颜色。"))
    }
    levels <- unique(as.character(data()[[input$event_type]]))
    levels <- levels[!is.na(levels) & nzchar(levels)]
    levels <- head(levels, 12)
    if (length(levels) == 0) return(helpText("当前事件类型变量没有可用水平。"))
    defaults <- palette_values(length(levels), input$event_palette %||% "hue")
    tagList(
      h5("事件类型颜色"),
      lapply(seq_along(levels), function(i) {
        lv <- levels[[i]]
        colourpicker::colourInput(
          session$ns(paste0("event_col_", digest::digest(lv, algo = "crc32"))),
          label = lv,
          value = defaults[[i]],
          width = "100%"
        )
      })
    )
  })

  output$track_mode_controls <- renderUI({
    req(input$tracks)
    selected_tracks <- input$tracks
    if (length(selected_tracks) == 0) {
      return(NULL)
    }
    tagList(
      h5("分组轨道展示方式"),
      lapply(selected_tracks, function(tr) {
        selectInput(
          session$ns(paste0("track_mode_", digest::digest(tr, algo = "crc32"))),
          label = tr,
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

  observeEvent(input$render_plot, {
    req(data(), input$subject_id, input$start_time, input$end_time)

    tryCatch({
      df <- data()
      start_is_date <- inherits(df[[input$start_time]], "Date") || inherits(df[[input$start_time]], "POSIXt")
      end_is_date <- inherits(df[[input$end_time]], "Date") || inherits(df[[input$end_time]], "POSIXt")
      date_mode <- isTRUE(start_is_date && end_is_date)
      event_time_is_date <- nzchar(input$event_time %||% "") &&
        input$event_time %in% names(df) &&
        (inherits(df[[input$event_time]], "Date") || inherits(df[[input$event_time]], "POSIXt"))
      unit_divisor <- switch(input$x_unit %||% "day", day = 1, week = 7, month = 30.4375, year = 365.25, 1)
      unit_label <- switch(input$x_unit %||% "day", day = "天", week = "周", month = "月", year = "年", "天")

      selected_tracks <- input$tracks %||% character(0)
      selected_tracks <- selected_tracks[selected_tracks %in% names(df)]

      lane_cols <- unique(c(input$subject_id, input$start_time, input$end_time, input$lane_color_by, input$ongoing_var, selected_tracks))
      lane_cols <- lane_cols[nzchar(lane_cols)]
      lane_cols <- lane_cols[lane_cols %in% names(df)]
      lane_df <- df[, lane_cols, drop = FALSE]

      names(lane_df)[names(lane_df) == input$subject_id] <- ".subject_id"
      names(lane_df)[names(lane_df) == input$start_time] <- ".start"
      names(lane_df)[names(lane_df) == input$end_time] <- ".end"
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

      lane_df <- lane_df %>%
        mutate(
          .subject_id = as.character(.subject_id),
          .lane_group = as.character(.lane_group),
          .ongoing = to_logical_flag(.ongoing)
        )

      if (isTRUE(date_mode)) {
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
        lane_df$.start <- 0
        lane_df$.end <- as.numeric(difftime(end_dates, start_dates, units = "days"))
      } else {
        lane_df$.start <- as.numeric(lane_df$.start)
        lane_df$.end <- as.numeric(lane_df$.end)
        if (any(lane_df$.end < lane_df$.start, na.rm = TRUE)) {
          idx <- which(lane_df$.end < lane_df$.start)
          tmp <- lane_df$.start[idx]
          lane_df$.start[idx] <- lane_df$.end[idx]
          lane_df$.end[idx] <- tmp
          showNotification("检测到结束时间小于起始时间，已自动交换。", type = "warning")
        }
      }

      lane_df <- lane_df %>%
        filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.start), !is.na(.end))

      if (nrow(lane_df) == 0) stop("没有可用于绘图的有效泳道数据。")

      lane_df <- lane_df %>%
        mutate(.duration = .end - .start) %>%
        group_by(.subject_id) %>%
        arrange(desc(.duration), .by_group = TRUE) %>%
        slice(1) %>%
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
        "<br>分组: ", lane_df$.lane_group
      )

      event_df <- NULL
      if (nzchar(input$event_time %||% "") && nzchar(input$event_type %||% "") &&
          input$event_time %in% names(df) && input$event_type %in% names(df)) {
        event_cols <- unique(c(input$subject_id, input$event_time, input$event_type, input$event_label))
        event_cols <- event_cols[nzchar(event_cols)]
        event_cols <- event_cols[event_cols %in% names(df)]
        event_df <- df[, event_cols, drop = FALSE]

        names(event_df)[names(event_df) == input$subject_id] <- ".subject_id"
        names(event_df)[names(event_df) == input$event_time] <- ".event_time"
        names(event_df)[names(event_df) == input$event_type] <- ".event_type"
        if (nzchar(input$event_label %||% "") && input$event_label %in% names(df)) {
          names(event_df)[names(event_df) == input$event_label] <- ".event_label"
        } else {
          event_df$.event_label <- ""
        }

        event_df <- event_df %>%
          mutate(
            .subject_id = as.character(.subject_id),
            .event_type = as.character(.event_type),
            .event_label = as.character(.event_label)
          )

        if (isTRUE(date_mode) && isTRUE(event_time_is_date)) {
          event_df <- event_df %>%
            mutate(.event_date = as.Date(.event_time)) %>%
            left_join(lane_df %>% select(.subject_id, .start_date), by = ".subject_id") %>%
            mutate(.event_time = as.numeric(difftime(.event_date, .start_date, units = "days")))
        } else {
          event_df$.event_time <- as.numeric(event_df$.event_time)
        }

        event_df <- event_df %>%
          filter(!is.na(.subject_id), !is.na(.event_time), nzchar(.event_type))

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
          select(.subject_id, .subject_factor, all_of(track_cols)) %>%
          pivot_longer(
            cols = all_of(track_cols),
            names_to = ".track_name",
            values_to = ".track_value"
          ) %>%
          mutate(
            .track_name = sub("^\\.track__", "", .track_name),
            .track_value = ifelse(is.na(.track_value), "NA", as.character(.track_value)),
            .track_name = factor(.track_name, levels = rev(selected_tracks))
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
          x = ifelse(nzchar(input$plot_xlab %||% ""), paste0(input$plot_xlab, "（", unit_label, "）"), paste0("时间（", unit_label, "）")),
          y = ifelse(nzchar(input$plot_ylab %||% ""), input$plot_ylab, "受试者"),
          color = ifelse(nzchar(input$lane_legend_title %||% ""), input$lane_legend_title, ifelse(nzchar(input$lane_color_by %||% ""), input$lane_color_by, "分组"))
        ) +
        theme_minimal(base_size = input$base_font_size) +
        theme(
          panel.grid.major.y = element_blank(),
          legend.position = if (isTRUE(input$show_legend)) "right" else "none"
        )

      if (!is.null(event_df) && nrow(event_df) > 0) {
        event_levels <- unique(event_df$.event_type)
        event_colors <- setNames(palette_values(length(event_levels), input$event_palette %||% "hue"), event_levels)
        event_shapes <- setNames(rep(c(16, 17, 15, 18, 8, 3, 7), length.out = length(event_levels)), event_levels)
        for (lv in event_levels) {
          id <- paste0("event_col_", digest::digest(lv, algo = "crc32"))
          if (!is.null(input[[id]]) && nzchar(input[[id]])) event_colors[[lv]] <- input[[id]]
        }

        event_df$.tooltip_event <- paste0(
          "受试者: ", event_df$.subject_id,
          "<br>事件时间: ", formatC(event_df$.event_time_plot, format = "f", digits = 2), " ", unit_label,
          "<br>事件类型: ", event_df$.event_type,
          ifelse(nzchar(event_df$.event_label), paste0("<br>标签: ", event_df$.event_label), "")
        )

        p_main <- p_main +
          geom_point(
            data = event_df,
            aes(x = .event_time_plot, y = .subject_factor, shape = .event_type, fill = .event_type, text = .tooltip_event),
            size = input$event_size,
            color = "#333333",
            stroke = 0.4
          ) +
          scale_shape_manual(values = event_shapes) +
          scale_fill_manual(values = event_colors)

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

        if (isTRUE(input$show_legend)) {
          p_main <- p_main + guides(
            shape = guide_legend(title = ifelse(nzchar(input$event_legend_title %||% ""), input$event_legend_title, input$event_type)),
            fill = guide_legend(title = ifelse(nzchar(input$event_legend_title %||% ""), input$event_legend_title, input$event_type))
          )
        }
      }

      if (isTRUE(input$show_ongoing_arrow)) {
        ongoing_df <- lane_df %>% filter(.ongoing)
        if (nrow(ongoing_df) > 0) {
          p_main <- p_main +
            geom_segment(
              data = ongoing_df,
              aes(x = .end_plot - 0.001, xend = .end_plot + max(.duration_plot, na.rm = TRUE) * 0.03, y = .subject_factor, yend = .subject_factor, color = .lane_group),
              linewidth = input$lane_size * 0.45,
              arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
              inherit.aes = FALSE
            )
        }
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
            .track_name_chr = as.character(.track_name),
            .track_mode = unname(track_mode_map[.track_name_chr]),
            .track_mode = ifelse(is.na(.track_mode), input$track_mode %||% "color", .track_mode)
          )

        text_track_df <- track_df %>% filter(.track_mode == "text")
        color_track_df <- track_df %>% filter(.track_mode == "color")
        track_vals <- unique(color_track_df$.track_value)
        track_colors <- setNames(palette_values(length(track_vals), "Set3"), track_vals)

        p_track <- ggplot(track_df, aes(x = .subject_factor, y = .track_name))
        if (nrow(color_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = color_track_df, aes(fill = .track_value), color = "white", height = 0.9)
        }
        if (nrow(text_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = text_track_df, fill = "#F7F7F7", color = "white", height = 0.9) +
            geom_text(data = text_track_df, aes(label = .track_value), size = max(2.8, input$base_font_size * 0.22))
        }
        if (nrow(color_track_df) > 0) {
          p_track <- p_track + scale_fill_manual(values = track_colors)
        }
        p_track <- p_track +
          labs(x = NULL, y = NULL, fill = "轨道分组") +
          theme_minimal(base_size = max(9, input$base_font_size - 1)) +
          theme(
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            panel.grid = element_blank(),
            legend.position = if (isTRUE(input$show_legend) && nrow(color_track_df) > 0) "right" else "none"
          )

        p_combined <- cowplot::plot_grid(
          p_main,
          p_track,
          ncol = 1,
          rel_heights = c(4, max(1, input$track_rel_height * max(1, length(selected_tracks)) * 0.65)),
          align = "v",
          axis = "lr"
        )
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
    req(final_plot())
    final_plot()
  }, height = function() {
    td <- track_data()
    if (is.null(td) || !isTRUE(input$show_tracks)) 720 else 720 + as.integer(40 * input$track_rel_height * length(unique(as.character(td$.track_name))))
  })

  output$interactive_plot <- plotly::renderPlotly({
    req(main_plot_obj())
    ggplotly(main_plot_obj(), tooltip = "text", height = 620)
  })

  output$lane_table <- renderDT({
    req(lane_data())
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
      save_plot_export(
        file = file,
        plot_obj = final_plot(),
        format = input$export_format,
        width = 13,
        height = 9,
        dpi = 300
      )
    }
  )

  return(reactive({
    list(
      subject_id = input$subject_id,
      start_time = input$start_time,
      end_time = input$end_time,
      event_time = input$event_time,
      event_type = input$event_type,
      tracks = input$tracks %||% character(0)
    )
  }))
}
