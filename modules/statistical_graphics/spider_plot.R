library(ggplot2)
library(plotly)
library(DT)
library(dplyr)
library(scales)

spider_plot_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      box(
        width = 12,
        title = "蜘蛛图参数配置",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = TRUE,
        fluidRow(
          column(
            6,
            wellPanel(
              style = "height: 620px; overflow-y: auto;",
              h4("数据与变量设置", style = "color: #007bff; margin-top: 0;"),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "数据映射"),
                tags$div(
                  class = "panel-body",
                  selectizeInput(
                    ns("subject_id"),
                    tags$span("受试者ID变量 [字符/因子]", title = "每条轨迹所属受试者ID"),
                    choices = NULL,
                    width = "100%"
                  ),
                  selectizeInput(
                    ns("time_var"),
                    tags$span("时间变量 [数值/日期]", title = "纵向时间轴变量，支持数值或日期"),
                    choices = NULL,
                    width = "100%"
                  ),
                  selectizeInput(
                    ns("value_var"),
                    tags$span("变化值变量 [数值]", title = "连续数值型终点，通常为较基线变化百分比"),
                    choices = NULL,
                    width = "100%"
                  ),
                  selectizeInput(
                    ns("line_color_by"),
                    tags$span("线条颜色分组 [字符/因子，可选]", title = "按分组上色展示不同亚组轨迹"),
                    choices = NULL,
                    width = "100%"
                  ),
                  selectizeInput(
                    ns("facet_var"),
                    tags$span("分面变量 [字符/因子，可选]", title = "按分面变量拆分子图"),
                    choices = NULL,
                    width = "100%"
                  ),
                  helpText("提示：将鼠标悬停在字段标签上可查看变量类型要求。")
                )
              ),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "参考线与阈值"),
                tags$div(
                  class = "panel-body",
                  checkboxInput(ns("show_recist"), "显示RECIST阈值线", TRUE),
                  fluidRow(
                    column(6, numericInput(ns("recist_lower"), "下阈值", value = -30, step = 1, width = "100%")),
                    column(6, numericInput(ns("recist_upper"), "上阈值", value = 20, step = 1, width = "100%"))
                  )
                )
              )
            )
          ),
          column(
            6,
            wellPanel(
              style = "height: 620px; overflow-y: auto;",
              h4("图形与样式设置", style = "color: #007bff; margin-top: 0;"),
              tabsetPanel(
                tabPanel(
                  "文本与布局",
                  br(),
                  textInput(ns("plot_title"), "主标题", value = "蜘蛛图", width = "100%"),
                  textInput(ns("plot_subtitle"), "副标题", value = "", width = "100%"),
                  textAreaInput(ns("plot_caption"), "脚注", value = "", rows = 2, width = "100%"),
                  fluidRow(
                    column(6, textInput(ns("plot_xlab"), "X轴标签", value = "时间", width = "100%")),
                    column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "较基线变化(%)", width = "100%"))
                  ),
                  textInput(ns("legend_title"), "图例标题", value = "", width = "100%")
                ),
                tabPanel(
                  "配色与比例",
                  br(),
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
                            column(6, selectInput(ns("legend_position"), "图例位置", choices = c("右侧" = "right", "左侧" = "left", "顶部" = "top", "底部" = "bottom"), selected = "right", width = "100%")),
                            column(6, selectInput(ns("axis_style"), "坐标轴样式", choices = c("默认" = "default", "经典XY轴(箭头)" = "classic_arrow"), selected = "default", width = "100%"))
                          ),
                          checkboxInput(ns("show_grid_lines"), "显示网格线", TRUE),
                          checkboxInput(ns("show_points"), "显示测量点", FALSE),
                          checkboxInput(ns("show_end_labels"), "显示末次标签", FALSE),
                          checkboxInput(ns("add_baseline_zero"), "补充基线点(time=0, chg=0)", FALSE),
                          fluidRow(
                            column(6, selectInput(
                              ns("time_unit"),
                              "时间单位换算",
                              choices = c("原始数值/天" = "day", "周" = "week", "月(30.44天)" = "month", "年(365.25天)" = "year"),
                              selected = "day",
                              width = "100%"
                            )),
                            column(6, numericInput(ns("x_break_step"), "X轴刻度步长", value = 0, min = 0, step = 0.1, width = "100%"))
                          ),
                          fluidRow(
                            column(6, numericInput(ns("y_breaks_n"), "Y轴刻度数量", value = 9, min = 4, max = 20, step = 1, width = "100%")),
                            column(6, numericInput(ns("base_font_size"), "全局字号", value = 12, min = 8, max = 22, step = 1, width = "100%"))
                          )
                        )
                      )
                    ),
                    column(
                      6,
                      tags$div(
                        class = "panel panel-default",
                        tags$div(class = "panel-heading", "坐标与配色"),
                        tags$div(
                          class = "panel-body",
                          selectInput(
                            ns("line_linetype"),
                            "线条样式",
                            choices = c("实线" = "solid", "虚线" = "dashed", "点线" = "dotted", "点划线" = "dotdash", "长虚线" = "longdash"),
                            selected = "solid",
                            width = "100%"
                          ),
                          selectInput(
                            ns("line_palette"),
                            "线条调色板",
                            choices = c("默认Hue" = "hue", "Set1" = "Set1", "Set2" = "Set2", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
                            selected = "Set1",
                            width = "100%"
                          ),
                          fluidRow(
                            column(6, sliderInput(ns("line_size"), "线宽", min = 0.4, max = 3, value = 0.9, step = 0.1, width = "100%")),
                            column(6, sliderInput(ns("line_alpha"), "线条透明度", min = 0.2, max = 1, value = 0.8, step = 0.05, width = "100%"))
                          ),
                          sliderInput(ns("point_size"), "点大小", min = 0.5, max = 6, value = 1.8, step = 0.1, width = "100%")
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
                      column(3, numericInput(ns("static_height_px"), "静态图高度(px)", value = 760, min = 400, max = 1800, step = 20, width = "100%")),
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
          )
        )
      )
    ),
    fluidRow(
      box(
        width = 12,
        title = "蜘蛛图输出",
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
          tabPanel("蜘蛛图数据", DTOutput(ns("data_table")))
        )
      )
    )
  )
}

spider_plot_server <- function(input, output, session, data) {
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

  is_time_var <- function(x) {
    is.numeric(x) || inherits(x, "Date") || inherits(x, "POSIXt")
  }

  graphics_state <- reactiveValues(
    subject_id = NULL,
    time_var = NULL,
    value_var = NULL,
    line_color_by = "",
    facet_var = "",
    columns_signature = NULL
  )

  observeEvent(data(), {
    req(data())
    all_vars <- names(data())
    numeric_vars <- names(data())[sapply(data(), is.numeric)]
    current_signature <- paste(all_vars, collapse = "|")
    if (!is.null(graphics_state$columns_signature) && identical(graphics_state$columns_signature, current_signature)) return()
    graphics_state$columns_signature <- current_signature

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = graphics_state$subject_id %||% "USUBJID", server = TRUE)
    updateSelectizeInput(session, "time_var", choices = all_vars, selected = graphics_state$time_var, server = TRUE)
    updateSelectizeInput(session, "value_var", choices = numeric_vars, selected = graphics_state$value_var %||% "PCHG", server = TRUE)
    updateSelectizeInput(session, "line_color_by", choices = c("无" = "", all_vars), selected = graphics_state$line_color_by, server = TRUE)
    updateSelectizeInput(session, "facet_var", choices = c("无" = "", all_vars), selected = graphics_state$facet_var, server = TRUE)
  }, ignoreInit = FALSE)

  observe({
    graphics_state$subject_id <- input$subject_id
    graphics_state$time_var <- input$time_var
    graphics_state$value_var <- input$value_var
    graphics_state$line_color_by <- input$line_color_by
    graphics_state$facet_var <- input$facet_var
  })

  final_plot <- reactiveVal(NULL)
  prepared_data <- reactiveVal(NULL)
  main_plot_obj <- reactiveVal(NULL)
  size_config <- reactive({
    mode <- input$size_mode %||% "wide_standard"
    to_num <- function(x, fallback) {
      val <- suppressWarnings(as.numeric(x))
      if (is.na(val) || !is.finite(val)) fallback else val
    }
    if (identical(mode, "custom")) {
      list(
        static_width = to_num(input$static_width_px, 1200),
        static_height = to_num(input$static_height_px, 760),
        interactive_width = to_num(input$interactive_width_px, 1200),
        interactive_height = to_num(input$interactive_height_px, 620),
        export_width = to_num(input$export_width_in, 13),
        export_height = to_num(input$export_height_in, 9)
      )
    } else {
      list(
        static_width = 1200,
        static_height = 760,
        interactive_width = 1200,
        interactive_height = 620,
        export_width = 13,
        export_height = 9
      )
    }
  })

  observeEvent(input$render_plot, {
    req(data(), input$subject_id, input$time_var, input$value_var)

    tryCatch({
      df <- data()
      line_has_group <- nzchar(input$line_color_by %||% "") && input$line_color_by %in% names(df)
      selected_cols <- unique(c(input$subject_id, input$time_var, input$value_var, input$line_color_by, input$facet_var))
      selected_cols <- selected_cols[nzchar(selected_cols)]
      selected_cols <- selected_cols[selected_cols %in% names(df)]
      plot_df <- df[, selected_cols, drop = FALSE]

      names(plot_df)[names(plot_df) == input$subject_id] <- ".subject_id"
      names(plot_df)[names(plot_df) == input$time_var] <- ".time"
      names(plot_df)[names(plot_df) == input$value_var] <- ".value"

      if (nzchar(input$line_color_by %||% "") && input$line_color_by %in% names(df)) {
        names(plot_df)[names(plot_df) == input$line_color_by] <- ".line_group"
      } else {
        plot_df$.line_group <- "全部受试者"
      }
      if (nzchar(input$facet_var %||% "") && input$facet_var %in% names(df)) {
        names(plot_df)[names(plot_df) == input$facet_var] <- ".facet_var"
      } else {
        plot_df$.facet_var <- "全部"
      }

      plot_df <- plot_df %>%
        mutate(
          .subject_id = as.character(.subject_id),
          .value = as.numeric(.value),
          .time_chr = as.character(.time),
          .line_group = as.character(.line_group),
          .facet_var = as.character(.facet_var)
        ) %>%
        filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.value), !is.na(.time_chr), nzchar(.time_chr))

      time_mode <- "numeric"
      if (inherits(df[[input$time_var]], "Date") || inherits(df[[input$time_var]], "POSIXt")) {
        time_mode <- "date"
        plot_df <- plot_df %>%
          mutate(.time_date = as.Date(.time)) %>%
          group_by(.subject_id) %>%
          mutate(.base_date = min(.time_date, na.rm = TRUE)) %>%
          ungroup() %>%
          mutate(
            .time_days = as.numeric(difftime(.time_date, .base_date, units = "days")),
            .time_label = as.character(.time_date)
          )
      } else if (is.numeric(df[[input$time_var]])) {
        time_mode <- "numeric"
        plot_df$.time_days <- as.numeric(plot_df$.time)
        plot_df$.time_label <- formatC(plot_df$.time_days, format = "f", digits = 2)
      } else {
        time_mode <- "categorical"
        time_levels <- unique(plot_df$.time_chr)
        num_guess <- suppressWarnings(as.numeric(gsub("[^0-9\\.\\-]", "", time_levels)))
        if (sum(!is.na(num_guess)) >= 2) {
          ord <- order(ifelse(is.na(num_guess), Inf, num_guess), time_levels)
          time_levels <- time_levels[ord]
          num_guess <- num_guess[ord]
          idx_vals <- ifelse(is.na(num_guess), seq_along(time_levels), num_guess)
        } else {
          idx_vals <- seq_along(time_levels)
        }
        time_map <- setNames(idx_vals, time_levels)
        plot_df$.time_days <- unname(time_map[plot_df$.time_chr])
        plot_df$.time_label <- plot_df$.time_chr
      }

      plot_df <- plot_df %>%
        filter(!is.na(.time_days)) %>%
        group_by(.subject_id, .time_days, .time_label, .line_group, .facet_var) %>%
        summarise(.value = mean(.value, na.rm = TRUE), .groups = "drop")

      unit_divisor <- switch(input$time_unit %||% "day", day = 1, week = 7, month = 30.4375, year = 365.25, 1)
      unit_label <- switch(input$time_unit %||% "day", day = "天", week = "周", month = "月", year = "年", "天")
      plot_df <- plot_df %>%
        mutate(
          .time_plot = if (time_mode == "categorical") .time_days else .time_days / unit_divisor
        )

      if (isTRUE(input$add_baseline_zero)) {
        baseline_df <- plot_df %>%
          group_by(.subject_id) %>%
          summarise(
            .line_group = dplyr::first(.line_group),
            .facet_var = dplyr::first(.facet_var),
            .groups = "drop"
          ) %>%
          mutate(
            .time_days = 0,
            .time_plot = 0,
            .time_label = if (time_mode == "categorical") "Baseline" else "0",
            .value = 0
          )
        plot_df <- bind_rows(plot_df, baseline_df) %>%
          group_by(.subject_id, .time_days, .time_plot, .time_label, .line_group, .facet_var) %>%
          summarise(.value = mean(.value, na.rm = TRUE), .groups = "drop")
      }

      plot_df$.tooltip <- paste0(
        "受试者: ", plot_df$.subject_id,
        "<br>时间: ", ifelse(time_mode == "categorical", plot_df$.time_label, paste0(formatC(plot_df$.time_plot, format = "f", digits = 2), " ", unit_label)),
        "<br>变化值: ", formatC(plot_df$.value, format = "f", digits = 2), "%"
      )

      y_breaks_fun <- scales::breaks_pretty(n = input$y_breaks_n %||% 9)
      line_levels <- unique(plot_df$.line_group)
      line_colors <- setNames(palette_values(length(line_levels), input$line_palette %||% "Set1"), line_levels)
      line_single_color <- line_colors[[1]] %||% "#4E79A7"

      if (isTRUE(line_has_group)) {
        p <- ggplot(plot_df, aes(x = .time_plot, y = .value, group = .subject_id, text = .tooltip, color = .line_group)) +
          geom_line(linewidth = input$line_size, alpha = input$line_alpha, linetype = input$line_linetype %||% "solid") +
          scale_color_manual(values = line_colors) +
          scale_y_continuous(breaks = y_breaks_fun, labels = label_number(accuracy = 0.1, suffix = "%")) +
          labs(
            title = ifelse(nzchar(input$plot_title %||% ""), input$plot_title, "蜘蛛图"),
            subtitle = input$plot_subtitle %||% "",
            caption = input$plot_caption %||% "",
            x = ifelse(nzchar(input$plot_xlab %||% ""), input$plot_xlab, ifelse(time_mode == "categorical", "时间序列", "时间")),
            y = ifelse(nzchar(input$plot_ylab %||% ""), input$plot_ylab, "较基线变化(%)"),
            color = ifelse(nzchar(input$legend_title %||% ""), input$legend_title, input$line_color_by)
          ) +
          theme_minimal(base_size = input$base_font_size, base_family = "sans") +
          theme(
            legend.position = if (isTRUE(input$show_legend)) (input$legend_position %||% "right") else "none",
            panel.grid.minor = element_blank()
          )
      } else {
        p <- ggplot(plot_df, aes(x = .time_plot, y = .value, group = .subject_id, text = .tooltip)) +
          geom_line(linewidth = input$line_size, alpha = input$line_alpha, linetype = input$line_linetype %||% "solid", color = line_single_color) +
          scale_y_continuous(breaks = y_breaks_fun, labels = label_number(accuracy = 0.1, suffix = "%")) +
          labs(
            title = ifelse(nzchar(input$plot_title %||% ""), input$plot_title, "蜘蛛图"),
            subtitle = input$plot_subtitle %||% "",
            caption = input$plot_caption %||% "",
            x = ifelse(nzchar(input$plot_xlab %||% ""), input$plot_xlab, ifelse(time_mode == "categorical", "时间序列", "时间")),
            y = ifelse(nzchar(input$plot_ylab %||% ""), input$plot_ylab, "较基线变化(%)")
          ) +
          theme_minimal(base_size = input$base_font_size, base_family = "sans") +
          theme(
            legend.position = "none",
            panel.grid.minor = element_blank()
          ) +
          guides(color = "none")
      }

      if (!isTRUE(input$show_grid_lines)) {
        p <- p + theme(panel.grid = element_blank(), panel.grid.minor = element_blank())
      }

      if (time_mode == "categorical") {
        x_lab_map <- plot_df %>%
          group_by(.time_plot) %>%
          summarise(.time_label = dplyr::first(.time_label), .groups = "drop") %>%
          arrange(.time_plot)
        p <- p + scale_x_continuous(breaks = x_lab_map$.time_plot, labels = x_lab_map$.time_label)
      } else {
        x_break_step <- suppressWarnings(as.numeric(input$x_break_step %||% 0))
        if (!is.na(x_break_step) && x_break_step > 0) {
          x_min <- min(plot_df$.time_plot, na.rm = TRUE)
          x_max <- max(plot_df$.time_plot, na.rm = TRUE)
          x_from <- floor(x_min / x_break_step) * x_break_step
          x_to <- ceiling(x_max / x_break_step) * x_break_step
          p <- p + scale_x_continuous(breaks = seq(x_from, x_to, by = x_break_step))
        }
      }

      if ((input$axis_style %||% "default") == "classic_arrow") {
        p <- p +
          theme_classic(base_size = input$base_font_size, base_family = "sans") +
          theme(
            axis.line = element_line(colour = "black", arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed")),
            legend.position = if (isTRUE(input$show_legend)) (input$legend_position %||% "right") else "none"
          )
      }

      if (isTRUE(input$show_points)) {
        if (isTRUE(line_has_group)) {
          p <- p + geom_point(size = input$point_size, alpha = min(1, input$line_alpha + 0.1))
        } else {
          p <- p + geom_point(size = input$point_size, alpha = min(1, input$line_alpha + 0.1), color = line_single_color)
        }
      }

      if (isTRUE(input$show_recist)) {
        p <- p +
          geom_hline(yintercept = input$recist_lower, linetype = "dashed", color = "#2C7BB6", linewidth = 0.7) +
          geom_hline(yintercept = input$recist_upper, linetype = "dashed", color = "#D7191C", linewidth = 0.7)
      }

      if (nzchar(input$facet_var %||% "")) {
        p <- p + facet_wrap(vars(.facet_var))
      }

      if (isTRUE(input$show_end_labels)) {
        end_df <- plot_df %>%
          group_by(.subject_id) %>%
          slice_max(order_by = .time_plot, n = 1, with_ties = FALSE) %>%
          ungroup()
        p <- p +
          geom_text(
            data = end_df,
            aes(label = .subject_id),
            color = "#333333",
            size = max(2.8, input$base_font_size * 0.2),
            nudge_x = diff(range(plot_df$.time_plot, na.rm = TRUE)) * 0.01,
            check_overlap = TRUE
          )
      }

      final_plot(p)
      main_plot_obj(p)
      prepared_data(plot_df)
      graphics_notify_success("蜘蛛图")
    }, error = function(e) {
      final_plot(NULL)
      main_plot_obj(NULL)
      prepared_data(NULL)
      graphics_notify_error("蜘蛛图", e)
    })
  })

  output$static_plot <- renderPlot({
    validate(need(!is.null(final_plot()), "请先完成参数设置并点击“生成图形”。"))
    final_plot()
  }, width = function() {
    as.integer(size_config()$static_width)
  }, height = function() {
    as.integer(size_config()$static_height)
  })

  output$interactive_plot <- plotly::renderPlotly({
    validate(need(!is.null(main_plot_obj()), "请先生成蜘蛛图后查看交互式图。"))
    cfg <- size_config()
    ggplotly(main_plot_obj(), tooltip = "text", width = as.integer(cfg$interactive_width), height = as.integer(cfg$interactive_height))
  })

  output$data_table <- renderDT({
    validate(need(!is.null(prepared_data()) && nrow(prepared_data()) > 0, "当前无可展示的蜘蛛图数据。"))
    datatable(prepared_data(), options = list(pageLength = 15, scrollX = TRUE))
  })

  output$dl_plot <- downloadHandler(
    filename = function() {
      build_plot_export_filename("spider_plot", input$export_format)
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
    list(
      subject_id = input$subject_id,
      time_var = input$time_var,
      value_var = input$value_var,
      line_color_by = input$line_color_by,
      facet_var = input$facet_var
      ,add_baseline_zero = input$add_baseline_zero,
      line_linetype = input$line_linetype,
      x_break_step = input$x_break_step,
      size_mode = input$size_mode,
      export_width_in = size_config()$export_width,
      export_height_in = size_config()$export_height
    )
  }))
}
