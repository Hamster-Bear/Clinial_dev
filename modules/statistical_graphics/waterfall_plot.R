library(ggplot2)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(cowplot)
library(scales)

waterfall_plot_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      box(
        width = 12,
        title = "瀑布图参数配置",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = FALSE,
        fluidRow(
          column(
            6,
            wellPanel(
              style = "height: 640px; overflow-y: auto;",
              h4("数据与变量设置", style = "color: #007bff; margin-top: 0;"),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "核心变量映射"),
                tags$div(
                  class = "panel-body",
                  selectizeInput(ns("subject_id"), "受试者ID变量", choices = NULL, width = "100%"),
                  selectizeInput(ns("value_var"), "变化值变量", choices = NULL, width = "100%"),
                  selectizeInput(ns("bar_color_by"), "柱颜色分组", choices = NULL, width = "100%"),
                  selectizeInput(ns("tracks"), "下方分组轨道", choices = NULL, multiple = TRUE, width = "100%")
                )
              ),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "排序与显示"),
                tags$div(
                  class = "panel-body",
                  fluidRow(
                    column(
                      6,
                      selectInput(
                        ns("sort_order"),
                        "排序方向",
                        choices = c("从低到高" = "asc", "从高到低" = "desc"),
                        selected = "asc",
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
                  uiOutput(ns("track_mode_controls")),
                  checkboxInput(ns("show_subject_labels"), "显示受试者标签", FALSE),
                  checkboxInput(ns("use_percent_label"), "Y轴默认显示百分比", TRUE),
                  checkboxInput(ns("show_legend"), "显示图例", TRUE)
                )
              ),
              tags$div(
                class = "panel panel-default",
                tags$div(class = "panel-heading", "阈值与临床线"),
                tags$div(
                  class = "panel-body",
                  checkboxInput(ns("show_recist"), "显示RECIST阈值线", TRUE),
                  fluidRow(
                    column(6, numericInput(ns("recist_lower"), "RECIST下阈值", value = -30, step = 1, width = "100%")),
                    column(6, numericInput(ns("recist_upper"), "RECIST上阈值", value = 20, step = 1, width = "100%"))
                  ),
                  checkboxInput(ns("show_recist_labels"), "显示阈值文本标签", TRUE),
                  fluidRow(
                    column(6, textInput(ns("recist_lower_label"), "下阈值标签", value = "RECIST -30%", width = "100%")),
                    column(6, textInput(ns("recist_upper_label"), "上阈值标签", value = "RECIST +20%", width = "100%"))
                  )
                )
              )
            )
          ),
          column(
            6,
            wellPanel(
              style = "height: 640px; overflow-y: auto;",
              h4("图形与样式设置", style = "color: #007bff; margin-top: 0;"),
              tabsetPanel(
                tabPanel(
                  "文本与标签",
                  br(),
                  actionButton(ns("render_plot"), "生成图形", icon = icon("chart-bar"), class = "btn-primary btn-block", style = "font-weight: bold; margin-bottom: 12px;"),
                  textInput(ns("plot_title"), "主标题", value = "瀑布图", width = "100%"),
                  textInput(ns("plot_subtitle"), "副标题", value = "", width = "100%"),
                  textAreaInput(ns("plot_caption"), "脚注", value = "", rows = 2, width = "100%"),
                  fluidRow(
                    column(6, textInput(ns("plot_xlab"), "X轴标签", value = "受试者", width = "100%")),
                    column(6, textInput(ns("plot_ylab"), "Y轴标签", value = "较基线变化 (%)", width = "100%"))
                  ),
                  textInput(ns("legend_title"), "图例标题", value = "", width = "100%")
                ),
                tabPanel(
                  "配色与布局",
                  br(),
                  selectInput(
                    ns("bar_palette"),
                    "柱图调色板",
                    choices = c("默认Hue" = "hue", "Set2" = "Set2", "Set3" = "Set3", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"),
                    selected = "Set2",
                    width = "100%"
                  ),
                  uiOutput(ns("bar_color_controls")),
                  colourpicker::colourInput(ns("bar_single_color"), "单组柱颜色", value = "#4E79A7", width = "100%"),
                  fluidRow(
                    column(6, colourpicker::colourInput(ns("bar_border_color"), "柱边框颜色", value = "#4D4D4D", width = "100%")),
                    column(6, colourpicker::colourInput(ns("zero_line_color"), "零线颜色", value = "#000000", width = "100%"))
                  ),
                  fluidRow(
                    column(6, colourpicker::colourInput(ns("recist_lower_color"), "下阈值线颜色", value = "#2C7BB6", width = "100%")),
                    column(6, colourpicker::colourInput(ns("recist_upper_color"), "上阈值线颜色", value = "#D7191C", width = "100%"))
                  ),
                  selectInput(
                    ns("track_palette"),
                    "轨道调色板",
                    choices = c("默认Hue" = "hue", "Set3" = "Set3", "Paired" = "Paired", "Dark2" = "Dark2", "Viridis" = "viridis"),
                    selected = "Set3",
                    width = "100%"
                  ),
                  colourpicker::colourInput(ns("track_text_color"), "轨道文本颜色", value = "#1A1A1A", width = "100%"),
                  sliderInput(ns("track_rel_height"), "下方表格占比", min = 0.5, max = 4, value = 1.4, step = 0.1, width = "100%"),
                  numericInput(ns("base_font_size"), "全局字号", value = 12, min = 8, max = 22, step = 1, width = "100%"),
                  numericInput(ns("bar_width"), "柱宽", value = 0.9, min = 0.2, max = 1, step = 0.05, width = "100%")
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
        title = "瀑布图输出",
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
          tabPanel("瀑布数据", DTOutput(ns("data_table"))),
          tabPanel("分组轨道数据", DTOutput(ns("track_table")))
        )
      )
    ),
    tags$script(HTML('
      $(document).ready(function() {
        $(document).on("mousewheel DOMMouseScroll", ".selectize-control .selectize-input", function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
        $(document).on("mousewheel DOMMouseScroll", "select", function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
        $(document).on("mousewheel DOMMouseScroll", "input[type=number]", function(e) {
          if ($(this).is(":focus")) {
            e.preventDefault();
            e.stopPropagation();
            $(this).blur();
          }
        });
      });
    '))
  )
}

waterfall_plot_server <- function(input, output, session, data) {
  palette_values <- function(n, palette_name = "hue") {
    if (n <= 0) return(character(0))
    if (palette_name == "hue") {
      return(scales::hue_pal()(n))
    }
    if (palette_name == "viridis") {
      return(grDevices::hcl.colors(n, "Viridis"))
    }
    max_n <- min(max(n, 3), 12)
    base_vals <- RColorBrewer::brewer.pal(max_n, palette_name)
    if (n <= length(base_vals)) {
      return(base_vals[seq_len(n)])
    }
    grDevices::colorRampPalette(base_vals)(n)
  }

  pick_first <- function(candidates, choices) {
    m <- candidates[candidates %in% choices]
    if (length(m) == 0) NULL else m[[1]]
  }

  pick_default_tracks <- function(choices, excluded = character(0)) {
    candidates <- c("TRT", "TRTA", "ARM", "COHORT", "BOR", "SEX", "RACE", "CENTER", "SITEID")
    out <- unique(c(candidates[candidates %in% choices], choices))
    out <- setdiff(out, excluded)
    head(out, 3)
  }

  graphics_state <- reactiveValues(
    subject_id = NULL,
    value_var = NULL,
    bar_color_by = "",
    tracks = character(0),
    columns_signature = NULL
  )

  output$bar_color_controls <- renderUI({
    req(data())
    if (is.null(input$bar_color_by) || !nzchar(input$bar_color_by) || !(input$bar_color_by %in% names(data()))) {
      return(helpText("选择柱颜色分组后，可在此为每个分组自定义颜色。"))
    }
    levels <- unique(as.character(data()[[input$bar_color_by]]))
    levels <- levels[!is.na(levels) & nzchar(levels)]
    levels <- head(levels, 12)
    if (length(levels) == 0) {
      return(helpText("当前分组变量没有可用水平。"))
    }
    defaults <- palette_values(length(levels), input$bar_palette %||% "hue")
    tagList(
      h5("柱图分组颜色"),
      lapply(seq_along(levels), function(i) {
        lv <- levels[[i]]
        colourpicker::colourInput(
          session$ns(paste0("bar_col_", digest::digest(lv, algo = "crc32"))),
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

  observeEvent(data(), {
    req(data())
    all_vars <- names(data())
    numeric_vars <- names(data())[sapply(data(), is.numeric)]
    current_signature <- paste(all_vars, collapse = "|")
    if (!is.null(graphics_state$columns_signature) && identical(graphics_state$columns_signature, current_signature)) {
      return()
    }
    graphics_state$columns_signature <- current_signature

    subject_candidates <- c("USUBJID", "SUBJID", "SUBJECT", "subject_id", "ID", "PATID")
    value_candidates <- c("PCHG", "CHG_PCT", "PERCENT_CHANGE", "CHANGE_PCT", "PERCENT", "chg", "pct_change")
    group_candidates <- c("BOR", "AVALC", "TRT", "TRTA", "ARM", "COHORT", "GROUP")

    selected_subject <- isolate(input$subject_id)
    if (is.null(selected_subject) || !nzchar(selected_subject) || !(selected_subject %in% all_vars)) {
      selected_subject <- graphics_state$subject_id
      if (is.null(selected_subject) || !(selected_subject %in% all_vars)) {
        selected_subject <- pick_first(subject_candidates, all_vars)
      }
    }

    selected_value <- isolate(input$value_var)
    if (is.null(selected_value) || !nzchar(selected_value) || !(selected_value %in% numeric_vars)) {
      selected_value <- graphics_state$value_var
      if (is.null(selected_value) || !(selected_value %in% numeric_vars)) {
        selected_value <- pick_first(value_candidates, numeric_vars)
      }
      if (is.null(selected_value) && length(numeric_vars) > 0) {
        selected_value <- numeric_vars[[1]]
      }
    }

    selected_color <- isolate(input$bar_color_by)
    if (is.null(selected_color) || !(selected_color %in% c("", all_vars))) {
      selected_color <- graphics_state$bar_color_by
      if (is.null(selected_color) || !(selected_color %in% c("", all_vars))) {
        selected_color <- pick_first(group_candidates, setdiff(all_vars, c(selected_subject, selected_value)))
        if (is.null(selected_color)) selected_color <- ""
      }
    }

    selected_tracks <- isolate(input$tracks)
    if (is.null(selected_tracks) || length(selected_tracks) == 0) {
      selected_tracks <- graphics_state$tracks
    }
    selected_tracks <- intersect(selected_tracks, all_vars)
    if (length(selected_tracks) == 0) {
      selected_tracks <- pick_default_tracks(all_vars, excluded = c(selected_subject, selected_value, selected_color))
    }

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = selected_subject, server = TRUE)
    updateSelectizeInput(session, "value_var", choices = numeric_vars, selected = selected_value, server = TRUE)
    updateSelectizeInput(session, "bar_color_by", choices = c("无" = "", all_vars), selected = selected_color, server = TRUE)
    updateSelectizeInput(session, "tracks", choices = all_vars, selected = selected_tracks, server = TRUE)
  }, ignoreInit = FALSE)

  observe({
    graphics_state$subject_id <- input$subject_id
    graphics_state$value_var <- input$value_var
    graphics_state$bar_color_by <- input$bar_color_by
    graphics_state$tracks <- if (is.null(input$tracks)) character(0) else input$tracks
  })

  `%||%` <- function(x, y) if (is.null(x)) y else x

  final_plot <- reactiveVal(NULL)
  main_plot_obj <- reactiveVal(NULL)
  prepared_data <- reactiveVal(NULL)
  prepared_track_data <- reactiveVal(NULL)

  observeEvent(input$render_plot, {
    req(data(), input$subject_id, input$value_var)

    tryCatch({
      df <- data()
      selected_tracks <- if (is.null(input$tracks)) character(0) else input$tracks
      selected_tracks <- selected_tracks[selected_tracks %in% names(df)]
      selected_cols <- unique(c(input$subject_id, input$value_var, input$bar_color_by, selected_tracks))
      selected_cols <- selected_cols[nzchar(selected_cols)]
      selected_cols <- selected_cols[selected_cols %in% names(df)]

      plot_df <- df[, selected_cols, drop = FALSE]
      names(plot_df)[names(plot_df) == input$subject_id] <- ".subject_id"
      names(plot_df)[names(plot_df) == input$value_var] <- ".value"

      if (!is.null(input$bar_color_by) && nzchar(input$bar_color_by) && input$bar_color_by %in% names(df)) {
        names(plot_df)[names(plot_df) == input$bar_color_by] <- ".bar_color"
      } else {
        plot_df$.bar_color <- "全部受试者"
      }

      for (tr in selected_tracks) {
        names(plot_df)[names(plot_df) == tr] <- paste0(".track__", tr)
      }

      plot_df <- plot_df %>%
        mutate(
          .subject_id = as.character(.subject_id),
          .value = as.numeric(.value),
          .bar_color = as.character(.bar_color)
        ) %>%
        filter(!is.na(.subject_id), nzchar(.subject_id), !is.na(.value))

      if (nrow(plot_df) == 0) {
        stop("没有可用于绘图的有效数据，请检查变量是否包含缺失值。")
      }

      if (anyDuplicated(plot_df$.subject_id) > 0) {
        plot_df <- plot_df %>%
          group_by(.subject_id) %>%
          slice(1) %>%
          ungroup()
        showNotification("检测到重复受试者ID，已自动保留每位受试者第一条记录。", type = "warning")
      }

      plot_df <- if (input$sort_order == "desc") {
        plot_df %>% arrange(desc(.value))
      } else {
        plot_df %>% arrange(.value)
      }

      plot_df <- plot_df %>%
        mutate(
          .order = row_number(),
          .subject_factor = factor(.subject_id, levels = .subject_id)
        )

      track_cols <- grep("^\\.track__", names(plot_df), value = TRUE)
      if (length(track_cols) > 0) {
        track_df <- plot_df %>%
          select(.subject_id, .subject_factor, .order, all_of(track_cols)) %>%
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

      tooltip_text <- apply(
        plot_df,
        1,
        function(r) {
          base_text <- paste0(
            "受试者: ", r[[".subject_id"]],
            "<br>变化值: ", formatC(as.numeric(r[[".value"]]), format = "f", digits = 2)
          )
          if (!is.null(input$bar_color_by) && nzchar(input$bar_color_by)) {
            base_text <- paste0(base_text, "<br>", input$bar_color_by, ": ", r[[".bar_color"]])
          }
          if (length(track_cols) > 0) {
            track_text <- vapply(
              selected_tracks,
              function(tr) {
                key <- paste0(".track__", tr)
                val <- if (key %in% names(r)) as.character(r[[key]]) else "NA"
                if (is.na(val) || !nzchar(val)) val <- "NA"
                paste0(tr, ": ", val)
              },
              character(1)
            )
            base_text <- paste0(base_text, "<br>", paste(track_text, collapse = "<br>"))
          }
          base_text
        }
      )

      plot_df$.tooltip <- tooltip_text

      y_axis_title <- if (isTRUE(input$use_percent_label) && !nzchar(input$plot_ylab %||% "")) {
        "较基线变化 (%)"
      } else if (nzchar(input$plot_ylab %||% "")) {
        input$plot_ylab
      } else {
        input$value_var
      }

      x_axis_title <- if (nzchar(input$plot_xlab %||% "")) input$plot_xlab else "受试者"
      legend_title <- if (nzchar(input$legend_title %||% "")) input$legend_title else ifelse(nzchar(input$bar_color_by %||% ""), input$bar_color_by, "分组")

      p_main <- ggplot(plot_df, aes(x = .subject_factor, y = .value, fill = .bar_color, text = .tooltip)) +
        geom_col(width = input$bar_width, color = input$bar_border_color) +
        geom_hline(yintercept = 0, color = input$zero_line_color, linewidth = 0.35) +
        labs(
          title = ifelse(nzchar(input$plot_title %||% ""), input$plot_title, "瀑布图"),
          subtitle = input$plot_subtitle %||% "",
          caption = input$plot_caption %||% "",
          x = x_axis_title,
          y = y_axis_title,
          fill = legend_title
        ) +
        theme_minimal(base_size = input$base_font_size) +
        theme(
          axis.text.x = if (isTRUE(input$show_subject_labels)) element_text(angle = 90, vjust = 0.5, hjust = 1) else element_blank(),
          axis.ticks.x = if (isTRUE(input$show_subject_labels)) element_line() else element_blank(),
          panel.grid.major.x = element_blank(),
          legend.position = if (isTRUE(input$show_legend)) "right" else "none"
        )

      group_levels <- unique(plot_df$.bar_color)
      if (length(group_levels) <= 1) {
        p_main <- p_main + scale_fill_manual(values = setNames(input$bar_single_color, group_levels))
      } else {
        default_vals <- palette_values(length(group_levels), input$bar_palette %||% "hue")
        color_vals <- setNames(default_vals, group_levels)
        for (lv in group_levels) {
          id <- paste0("bar_col_", digest::digest(lv, algo = "crc32"))
          if (!is.null(input[[id]]) && nzchar(input[[id]])) {
            color_vals[[lv]] <- input[[id]]
          }
        }
        p_main <- p_main + scale_fill_manual(values = color_vals)
      }

      if (isTRUE(input$use_percent_label)) {
        p_main <- p_main + scale_y_continuous(labels = label_number(accuracy = 0.1, suffix = "%"))
      }

      if (isTRUE(input$show_recist)) {
        p_main <- p_main +
          geom_hline(yintercept = input$recist_lower, linetype = "dashed", color = input$recist_lower_color, linewidth = 0.8) +
          geom_hline(yintercept = input$recist_upper, linetype = "dashed", color = input$recist_upper_color, linewidth = 0.8)
        if (isTRUE(input$show_recist_labels)) {
          p_main <- p_main +
            annotate("text", x = Inf, y = input$recist_lower, label = input$recist_lower_label %||% "", hjust = 1.02, vjust = -0.2, color = input$recist_lower_color, size = 3.5) +
            annotate("text", x = Inf, y = input$recist_upper, label = input$recist_upper_label %||% "", hjust = 1.02, vjust = -0.2, color = input$recist_upper_color, size = 3.5)
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
        track_values <- unique(color_track_df$.track_value)
        track_colors <- setNames(palette_values(length(track_values), input$track_palette %||% "hue"), track_values)

        p_track <- ggplot(track_df, aes(x = .subject_factor, y = .track_name))
        if (nrow(color_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = color_track_df, aes(fill = .track_value), color = "white", height = 0.9)
        }
        if (nrow(text_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = text_track_df, fill = "#F7F7F7", color = "white", height = 0.9) +
            geom_text(data = text_track_df, aes(label = .track_value), size = max(2.8, input$base_font_size * 0.22), color = input$track_text_color)
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
          rel_heights = c(4, max(1, input$track_rel_height * max(1, length(selected_tracks)) * 0.7)),
          align = "v",
          axis = "lr"
        )
      }

      final_plot(p_combined)
      main_plot_obj(p_main)
      prepared_data(plot_df %>% select(.order, .subject_id, .value, .bar_color, everything()))
      prepared_track_data(track_df)
      showNotification("瀑布图生成完成", type = "message")
    }, error = function(e) {
      final_plot(NULL)
      main_plot_obj(NULL)
      prepared_data(NULL)
      prepared_track_data(NULL)
      showNotification(paste("瀑布图生成错误:", e$message), type = "error")
    })
  })

  output$static_plot <- renderPlot({
    req(final_plot())
    final_plot()
  }, height = function() {
    track_df <- prepared_track_data()
    if (is.null(track_df) || !isTRUE(input$show_tracks)) {
      700
    } else {
      track_n <- length(unique(as.character(track_df$.track_name)))
      700 + as.integer(45 * input$track_rel_height * track_n)
    }
  })

  output$interactive_plot <- plotly::renderPlotly({
    req(main_plot_obj())
    ggplotly(main_plot_obj(), tooltip = "text", height = 620)
  })

  output$data_table <- renderDT({
    req(prepared_data())
    datatable(prepared_data(), options = list(pageLength = 15, scrollX = TRUE))
  })

  output$track_table <- renderDT({
    track_df <- prepared_track_data()
    validate(need(!is.null(track_df), "未选择分组轨道变量"))
    out <- track_df %>%
      select(.subject_id, .track_name, .track_value) %>%
      tidyr::pivot_wider(names_from = .track_name, values_from = .track_value)
    datatable(out, options = list(pageLength = 15, scrollX = TRUE))
  })

  output$dl_plot <- downloadHandler(
    filename = function() {
      build_plot_export_filename("waterfall_plot", input$export_format)
    },
    content = function(file) {
      req(final_plot())
      save_plot_export(
        file = file,
        plot_obj = final_plot(),
        format = input$export_format,
        width = 12,
        height = 9,
        dpi = 300
      )
    }
  )

  return(reactive({
    list(
      subject_id = input$subject_id,
      value_var = input$value_var,
      color_by = input$bar_color_by,
      tracks = if (is.null(input$tracks)) character(0) else input$tracks
    )
  }))
}
