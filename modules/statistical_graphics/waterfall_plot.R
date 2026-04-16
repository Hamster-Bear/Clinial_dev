library(ggplot2)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(cowplot)
library(scales)

.waterfall_symbol_choices <- function() {
  graphics_text_symbol_choices()
}

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
        collapsed = TRUE,
        fluidRow(
          column(
            4,
            wellPanel(
              style = "height: 680px; overflow-y: auto;",
              h4("数据与变量", style = "color: #007bff; margin-top: 0;"),
              tabsetPanel(
                tabPanel(
                  "核心映射",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "核心映射",
                    fields = list(
                      list(list(id = "subject_id", label = "受试者ID变量", type = "selectize")),
                      list(list(id = "value_var", label = "变化值变量", type = "selectize"))
                    )
                  )
                ),
                tabPanel(
                  "分组/分面/轨道/附加变量",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "分组/轨道/附加变量",
                    fields = list(
                      list(list(id = "bar_color_by", label = "柱颜色分组", type = "selectize")),
                      list(list(id = "symbol_by", label = "柱顶符号文本分组(可选)", type = "selectize")),
                      list(list(id = "tracks", label = "下方分组轨道(可多选)", type = "selectize", multiple = TRUE))
                    ),
                    help_text = "当前瀑布图没有独立分面变量；轨道变量和附加符号映射统一收纳在此页签。"
                  ),
                  graphics_card_panel_ui(
                    "排序与轨道",
                    tagList(
                      selectInput(ns("sort_order"), "排序方向", choices = c("从低到高" = "asc", "从高到低" = "desc"), selected = "asc", width = "100%"),
                      helpText("默认不自动填入轨道变量；仅当你明确选择后，才在下方轨道区和分组轨道数据中显示。"),
                      selectInput(ns("track_mode"), "轨道默认展示方式", choices = c("颜色填充" = "color", "文本填充" = "text"), selected = "color", width = "100%"),
                      checkboxInput(ns("show_tracks"), "显示下方分组轨道", TRUE),
                      uiOutput(ns("track_mode_controls"))
                    )
                  )
                )
              )
            )
          ),
          column(
            4,
            wellPanel(
              style = "height: 680px; overflow-y: auto;",
              h4("图形与样式", style = "color: #007bff; margin-top: 0;"),
              tabsetPanel(
                tabPanel(
                  "标题与说明",
                  br(),
                  graphics_text_label_panel_ui(
                    ns,
                    title = "标题与说明",
                    fields = list(
                      list(list(id = "plot_title", label = "主标题", type = "text", selected = "瀑布图")),
                      list(list(id = "plot_subtitle", label = "副标题", type = "text", selected = "")),
                      list(list(id = "plot_caption", label = "脚注", type = "text", selected = "")),
                      list(
                        list(id = "plot_xlab", label = "X轴标签", type = "text", selected = "受试者", column = 6),
                        list(id = "plot_ylab", label = "Y轴标签", type = "text", selected = "较基线变化 (%)", column = 6)
                      ),
                      list(list(id = "legend_title", label = "柱分组图例标题", type = "text", selected = ""))
                    )
                  )
                ),
                tabPanel(
                  "显示与坐标",
                  br(),
                  fluidRow(
                    column(
                      6,
                      graphics_display_legend_panel_ui(
                        ns,
                        title = "显示与图例",
                        fields = list(
                          list(list(id = "show_symbols", label = "显示柱顶符号文本", type = "checkbox", value = TRUE)),
                          list(list(id = "show_subject_labels", label = "显示受试者标签", type = "checkbox", value = FALSE)),
                          list(list(id = "use_percent_label", label = "Y轴标签按百分比格式显示", type = "checkbox", value = TRUE)),
                          list(list(id = "y_decimals", label = "Y轴保留小数位数", type = "numeric", value = 1, min = 0, max = 5, step = 1)),
                          list(list(id = "show_grid_lines", label = "显示网格线", type = "checkbox", value = TRUE)),
                          list(list(id = "axis_style", label = "坐标轴样式", type = "select", choices = c("默认" = "default", "经典坐标轴(不带箭头)" = "classic", "经典XY轴(箭头)" = "classic_arrow"), selected = "default")),
                          list(list(id = "show_legend", label = "显示图例", type = "checkbox", value = TRUE)),
                          list(list(id = "auto_mapping_caption", label = "自动追加样式脚注", type = "checkbox", value = TRUE)),
                          list(list(id = "main_legend_position", label = "主图图例位置", type = "select", choices = graphics_legend_position_choices("outer"), selected = "right")),
                          list(list(id = "track_legend_position", label = "轨道图例位置", type = "select", choices = graphics_legend_position_choices("outer"), selected = "right"))
                        ),
                        extra_ui = conditionalPanel(
                          condition = paste0("input['", ns("use_percent_label"), "'] == true"),
                          checkboxInput(ns("y_show_percent_sign"), "标签带百分号(%)", value = TRUE)
                        ),
                        help_text = "这里只控制 Y 轴标签的显示格式，不会对原始变化值重新换算。"
                      )
                    ),
                    column(
                      6,
                      graphics_axis_proportion_panel_ui(
                        ns,
                        title = "坐标与版式",
                        fields = list(
                          list(
                            list(id = "y_breaks_n", label = "Y轴刻度数量", type = "numeric", value = 9, min = 4, max = 20, step = 1, column = 4),
                            list(id = "y_break_step", label = "Y轴刻度步长", type = "numeric", value = 0, min = 0, step = 0.1, column = 4),
                            list(id = "base_font_size", label = "全局字号", type = "numeric", value = 12, min = 8, max = 22, step = 1, column = 4)
                          ),
                          list(
                            list(id = "track_rel_height", label = "下方轨道区占比", type = "slider", value = 0.5, min = 0.5, max = 4, step = 0.1, column = 8)
                          )
                        ),
                        extra_ui = fluidRow(
                          column(12, graphics_font_family_pair_ui(ns, latin_id = "base_family", cjk_id = "cjk_family"))
                        )
                      )
                    )
                  )
                ),
                tabPanel(
                  "图层样式",
                  br(),
                  fluidRow(
                    column(
                      6,
                      graphics_palette_layout_panel_ui(
                        ns,
                        title = "柱体配色",
                        fields = list(
                          list(list(id = "bar_palette", label = "柱图调色板", type = "select", choices = graphics_palette_choice_values("qualitative"), selected = "Set2")),
                          list(list(id = "bar_single_color", label = "单组柱颜色", type = "color", value = "#4E79A7")),
                          list(
                            list(id = "bar_border_color", label = "柱边框颜色", type = "color", value = "#4D4D4D", column = 6),
                            list(id = "zero_line_color", label = "零线颜色", type = "color", value = "#000000", column = 6)
                          ),
                          list(list(id = "bar_width", label = "柱宽", type = "numeric", value = 0.9, min = 0.2, max = 1, step = 0.05))
                        ),
                        prepend_ui = uiOutput(ns("bar_color_controls"))
                      )
                    ),
                    column(
                      6,
                      graphics_symbol_style_panel_ui(
                        ns,
                        title = "符号文本样式",
                        fields = list(
                          list(
                            list(id = "symbol_text_color", label = "默认符号文本颜色", type = "color", value = "#1A1A1A", column = 6),
                            list(id = "symbol_text_size", label = "符号文本大小", type = "numeric", value = 4, min = 2, max = 10, step = 0.2, column = 6)
                          )
                        ),
                        prepend_ui = uiOutput(ns("symbol_controls"))
                      )
                    )
                  ),
                  fluidRow(
                    column(
                      6,
                      graphics_card_panel_ui(
                        "轨道与缺失值",
                        tagList(
                          selectInput(
                            ns("track_palette"),
                            "轨道调色板",
                            choices = c("默认Hue" = "hue", "Set3" = "Set3", "Paired" = "Paired", "Dark2" = "Dark2", "Viridis" = "viridis"),
                            selected = "Set3",
                            width = "100%"
                          ),
                          uiOutput(ns("track_color_controls")),
                          fluidRow(
                            column(6, colourpicker::colourInput(ns("track_text_bg_color"), "轨道文本底色", value = "#F7F7F7", width = "100%")),
                            column(6, colourpicker::colourInput(ns("track_text_color"), "轨道文本颜色", value = "#1A1A1A", width = "100%"))
                          ),
                          textInput(ns("track_legend_title"), "轨道总图例标题", value = "轨道分组", width = "100%"),
                          checkboxInput(ns("track_compact_mode"), "轨道紧凑模式", TRUE),
                          fluidRow(
                            column(6, sliderInput(ns("track_tile_height"), "轨道方框高度", min = 0.1, max = 1.4, value = 0.65, step = 0.05, width = "100%")),
                            column(6, sliderInput(ns("track_row_spacing"), "轨道行间距", min = 0, max = 0.8, value = 0.08, step = 0.02, width = "100%"))
                          ),
                          selectInput(ns("missing_display_mode"), "空值显示方式", choices = c("空白" = "blank", "无" = "none", "NA" = "na", "破折号" = "dash", "自定义" = "custom"), selected = "na", width = "100%"),
                          conditionalPanel(
                            condition = sprintf("input['%s'] === 'custom'", ns("missing_display_mode")),
                            textInput(ns("missing_display_custom"), "自定义空值文本", value = "NA", width = "100%")
                          ),
                          helpText("这里控制下方轨道区的颜色、文本显示和缺失值文本，不影响主图柱体颜色与符号映射。")
                        )
                      )
                    )
                  )
                ),
                tabPanel(
                  "参考线与阈值",
                  br(),
                  graphics_reference_threshold_panel_ui(
                    ns,
                    title = "参考线与阈值",
                    toggle_id = "show_recist",
                    toggle_label = "显示RECIST阈值线",
                    toggle_value = TRUE,
                    conditional_ui = tagList(
                      graphics_reference_line_ui(ns, "recist_lower", label = "RECIST下阈值", default_value = -30, default_color = "#2C7BB6"),
                      graphics_reference_line_ui(ns, "recist_upper", label = "RECIST上阈值", default_value = 20, default_color = "#D7191C"),
                      checkboxInput(ns("show_recist_labels"), "显示阈值文本标签", TRUE),
                      textInput(ns("recist_lower_label"), "下阈值标签", value = "RECIST -30%", width = "100%"),
                      textInput(ns("recist_upper_label"), "上阈值标签", value = "RECIST +20%", width = "100%")
                    )
                  )
                )
              )
            )
          ),
          column(
            4,
            wellPanel(
              style = "height: 680px; overflow-y: auto;",
              h4("输出与导出", style = "color: #007bff; margin-top: 0;"),
              tabsetPanel(
                tabPanel(
                  "尺寸与画布",
                  br(),
                  graphics_card_panel_ui(
                    "尺寸与画布",
                    tagList(
                      selectInput(ns("size_mode"), "尺寸模式", choices = c("宽图标准" = "wide_standard", "自定义尺寸" = "custom"), selected = "wide_standard", width = "100%"),
                      conditionalPanel(
                        condition = sprintf("input['%s'] === 'custom'", ns("size_mode")),
                        tagList(
                          fluidRow(
                            column(6, numericInput(ns("static_width_px"), "静态图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                            column(6, numericInput(ns("static_height_px"), "静态图基础高度(px)", value = 760, min = 400, max = 1800, step = 20, width = "100%"))
                          ),
                          fluidRow(
                            column(6, numericInput(ns("interactive_width_px"), "交互图宽度(px)", value = 1200, min = 600, max = 2400, step = 20, width = "100%")),
                            column(6, numericInput(ns("interactive_height_px"), "交互图高度(px)", value = 620, min = 350, max = 1600, step = 20, width = "100%"))
                          ),
                          fluidRow(
                            column(4, checkboxInput(ns("sync_export_size"), "导出尺寸跟随前端画布", value = TRUE, width = "100%")),
                            column(4, numericInput(ns("size_sync_ppi"), "PX/英寸换算", value = 96, min = 72, max = 300, step = 1, width = "100%")),
                            column(4, checkboxInput(ns("canvas_border"), "显示画布边框", value = TRUE, width = "100%"))
                          ),
                          fluidRow(
                            column(3, numericInput(ns("page_margin_top_px"), "上边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
                            column(3, numericInput(ns("page_margin_right_px"), "右边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
                            column(3, numericInput(ns("page_margin_bottom_px"), "下边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%")),
                            column(3, numericInput(ns("page_margin_left_px"), "左边距(px)", value = 24, min = 0, max = 240, step = 2, width = "100%"))
                          )
                        )
                      ),
                      helpText("默认按 PX/英寸换算同步导出尺寸，并保持前端静态图与导出比例一致。")
                    )
                  )
                ),
                tabPanel(
                  "导出参数",
                  br(),
                  graphics_card_panel_ui(
                    "导出参数",
                    tagList(
                      fluidRow(
                        column(6, selectInput(ns("export_format"), "导出格式", choices = c("导出PDF" = "pdf", "导出PNG" = "png", "导出SVG" = "svg"), selected = "pdf", width = "100%")),
                        column(6, numericInput(ns("export_dpi"), "导出DPI", value = 600, min = 72, max = 1200, step = 10, width = "100%"))
                      ),
                      conditionalPanel(
                        condition = sprintf("input['%s'] === false", ns("sync_export_size")),
                        fluidRow(
                          column(6, numericInput(ns("export_width_in"), "导出宽度(英寸)", value = 12.5, min = 6, max = 30, step = 0.5, width = "100%")),
                          column(6, numericInput(ns("export_height_in"), "导出高度(英寸)", value = 7.9, min = 4, max = 24, step = 0.5, width = "100%"))
                        )
                      )
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
        title = "结果区",
        status = "success",
        solidHeader = TRUE,
        graphics_output_action_bar_ui(ns, render_button_id = "render_plot", download_id = "dl_plot"),
        tabsetPanel(
          id = ns("output_tabs"),
          tabPanel("静态图", uiOutput(ns("static_plot_ui"))),
          tabPanel("交互图", uiOutput(ns("interactive_plot_ui"))),
          tabPanel(
            "数据",
            tabsetPanel(
              tabPanel("瀑布数据", DTOutput(ns("data_table"))),
              tabPanel("分组轨道数据", DTOutput(ns("track_table")))
            )
          )
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
  ns <- session$ns
  get_var_label <- function(df, var_name) {
    if (is.null(var_name) || !nzchar(var_name) || !(var_name %in% names(df))) return(var_name)
    lbl <- attr(df[[var_name]], "label")
    if (!is.null(lbl) && nzchar(as.character(lbl))) as.character(lbl) else var_name
  }

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

  get_missing_text <- function(params = NULL) {
    mode <- params$missing_display_mode %||% input$missing_display_mode %||% "na"
    custom_value <- params$missing_display_custom %||% input$missing_display_custom %||% "NA"
    if (mode == "blank") return("")
    if (mode == "none") return("无")
    if (mode == "dash") return("-")
    if (mode == "custom") return(custom_value)
    "NA"
  }

  format_missing_vec <- function(x, params = NULL) {
    x_chr <- as.character(x)
    miss_idx <- is.na(x) | is.na(x_chr) | !nzchar(trimws(x_chr))
    x_chr[miss_idx] <- get_missing_text(params)
    x_chr
  }

  pick_first <- function(candidates, choices) {
    m <- candidates[candidates %in% choices]
    if (length(m) == 0) NULL else m[[1]]
  }

  graphics_state <- reactiveValues(
    subject_id = NULL,
    value_var = NULL,
    bar_color_by = "",
    symbol_by = "",
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

  output$track_color_controls <- renderUI({
    req(input$tracks, data())
    selected_tracks <- input$tracks %||% character(0)
    selected_tracks <- selected_tracks[selected_tracks %in% names(data())]
    if (length(selected_tracks) == 0) {
      return(helpText("选择轨道变量后，可为“轨道名:值”逐项指定颜色。"))
    }
    track_mode_map <- setNames(
      lapply(selected_tracks, function(tr) input[[paste0("track_mode_", digest::digest(tr, algo = "crc32"))]] %||% (input$track_mode %||% "color")),
      selected_tracks
    )
    color_tracks <- graphics_filter_tracks_by_mode(selected_tracks, track_mode_map, "color")
    if (length(color_tracks) == 0) {
      return(helpText("当前所选轨道均为文本填充，无需颜色映射。"))
    }
    track_label_map <- setNames(make.unique(vapply(color_tracks, function(tr) get_var_label(data(), tr), character(1))), color_tracks)
    key_list <- lapply(color_tracks, function(tr) {
      vals <- unique(format_missing_vec(data()[[tr]]))
      vals <- vals[!is.na(vals)]
      paste0(track_label_map[[tr]], " : ", vals)
    })
    track_keys <- unique(unlist(key_list, use.names = FALSE))
    track_keys <- head(track_keys, 30)
    if (length(track_keys) == 0) {
      return(helpText("当前轨道变量没有可用取值。"))
    }
    defaults <- setNames(palette_values(length(track_keys), input$track_palette %||% "hue"), track_keys)
    tagList(
      h5("轨道取值颜色映射"),
      lapply(track_keys, function(key) {
        colourpicker::colourInput(
          session$ns(paste0("track_col_", digest::digest(key, algo = "crc32"))),
          label = key,
          value = defaults[[key]],
          width = "100%"
        )
      })
    )
  })

  output$symbol_controls <- renderUI({
    req(data())
    if (is.null(input$symbol_by) || !nzchar(input$symbol_by) || !(input$symbol_by %in% names(data()))) {
      return(NULL)
    }
    symbol_levels <- unique(as.character(data()[[input$symbol_by]]))
    symbol_levels <- symbol_levels[!is.na(symbol_levels) & nzchar(symbol_levels)]
    symbol_levels <- head(symbol_levels, 12)
    if (length(symbol_levels) == 0) return(NULL)
    default_colors <- rep(input$symbol_text_color %||% "#1A1A1A", length(symbol_levels))
    graphics_group_style_mapping_panel_ui(
      title = "符号分组映射",
      body = graphics_group_symbol_controls_ui(
        session = session,
        levels = symbol_levels,
        symbol_input_prefix = "symbol_lbl_",
        color_input_prefix = "symbol_col_",
        symbol_choices = .waterfall_symbol_choices(),
        default_colors = default_colors,
        title = "符号分组映射"
      )
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

    selected_subject <- graphics_remember_choice(isolate(input$subject_id), graphics_state$subject_id, all_vars, pick_first(subject_candidates, all_vars))
    selected_value <- graphics_remember_choice(isolate(input$value_var), graphics_state$value_var, numeric_vars, pick_first(value_candidates, numeric_vars) %||% (numeric_vars[[1]] %||% NULL))
    selected_color <- graphics_remember_choice(isolate(input$bar_color_by), graphics_state$bar_color_by, all_vars, pick_first(group_candidates, setdiff(all_vars, c(selected_subject, selected_value))) %||% "", allow_empty = TRUE)
    selected_symbol <- graphics_remember_choice(isolate(input$symbol_by), graphics_state$symbol_by, all_vars, "", allow_empty = TRUE)

    selected_tracks <- isolate(input$tracks)
    if (is.null(selected_tracks) || length(selected_tracks) == 0) {
      selected_tracks <- graphics_state$tracks
    }
    selected_tracks <- intersect(selected_tracks, all_vars)

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = selected_subject, server = TRUE)
    updateSelectizeInput(session, "value_var", choices = numeric_vars, selected = selected_value, server = TRUE)
    updateSelectizeInput(session, "bar_color_by", choices = c("无" = "", all_vars), selected = selected_color, server = TRUE)
    updateSelectizeInput(session, "symbol_by", choices = c("无" = "", all_vars), selected = selected_symbol, server = TRUE)
    updateSelectizeInput(session, "tracks", choices = all_vars, selected = selected_tracks, server = TRUE)
  }, ignoreInit = FALSE)

  observe({
    graphics_state$subject_id <- input$subject_id
    graphics_state$value_var <- input$value_var
    graphics_state$bar_color_by <- input$bar_color_by
    graphics_state$symbol_by <- input$symbol_by
    graphics_state$tracks <- if (is.null(input$tracks)) character(0) else input$tracks
  })

  outputOptions(output, "bar_color_controls", suspendWhenHidden = FALSE)
  outputOptions(output, "symbol_controls", suspendWhenHidden = FALSE)
  outputOptions(output, "track_mode_controls", suspendWhenHidden = FALSE)
  outputOptions(output, "track_color_controls", suspendWhenHidden = FALSE)

  `%||%` <- function(x, y) if (is.null(x)) y else x

  final_plot <- reactiveVal(NULL)
  main_plot_obj <- reactiveVal(NULL)
  prepared_data <- reactiveVal(NULL)
  prepared_track_data <- reactiveVal(NULL)
  committed_params <- reactiveVal(NULL)
  size_config <- reactive({
    graphics_collect_size_config(input)
  })

  collect_reference_line_spec_from_params <- function(
    params,
    id_prefix,
    orientation = "h",
    fallback_value = NULL,
    fallback_color = "#1A1A1A",
    fallback_linetype = "dashed",
    fallback_linewidth = 0.8
  ) {
    value <- suppressWarnings(as.numeric(params[[id_prefix]] %||% fallback_value))
    if (length(value) == 0 || is.na(value) || !is.finite(value)) return(NULL)
    list(
      orientation = if (identical(orientation, "v")) "v" else "h",
      value = value,
      color = as.character(params[[paste0(id_prefix, "_color")]] %||% fallback_color),
      linetype = as.character(params[[paste0(id_prefix, "_linetype")]] %||% fallback_linetype),
      linewidth = suppressWarnings(as.numeric(params[[paste0(id_prefix, "_linewidth")]] %||% fallback_linewidth))
    )
  }

  capture_bar_manual_color_values <- function(df_current = NULL, bar_color_by = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    bar_color_by <- bar_color_by %||% input$bar_color_by
    if (is.null(df_current) || is.null(bar_color_by) || !nzchar(bar_color_by) || !(bar_color_by %in% names(df_current))) {
      return(list())
    }
    levels <- unique(as.character(df_current[[bar_color_by]]))
    levels <- levels[!is.na(levels) & nzchar(levels)]
    levels <- head(levels, 12)
    setNames(
      lapply(levels, function(lv) input[[paste0("bar_col_", digest::digest(lv, algo = "crc32"))]] %||% NULL),
      levels
    )
  }

  capture_symbol_style_values <- function(df_current = NULL, symbol_by = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    symbol_by <- symbol_by %||% input$symbol_by
    if (is.null(df_current) || is.null(symbol_by) || !nzchar(symbol_by) || !(symbol_by %in% names(df_current))) {
      return(list(labels = list(), colors = list()))
    }
    symbol_levels <- unique(as.character(df_current[[symbol_by]]))
    symbol_levels <- symbol_levels[!is.na(symbol_levels) & nzchar(symbol_levels)]
    symbol_levels <- head(symbol_levels, 12)
    list(
      labels = setNames(
        lapply(symbol_levels, function(lv) input[[paste0("symbol_lbl_", digest::digest(lv, algo = "crc32"))]] %||% NULL),
        symbol_levels
      ),
      colors = setNames(
        lapply(symbol_levels, function(lv) input[[paste0("symbol_col_", digest::digest(lv, algo = "crc32"))]] %||% NULL),
        symbol_levels
      )
    )
  }

  capture_track_mode_map <- function(selected_tracks = NULL) {
    selected_tracks <- selected_tracks %||% input$tracks %||% character(0)
    if (length(selected_tracks) == 0) {
      return(list())
    }
    setNames(
      lapply(selected_tracks, function(tr) input[[paste0("track_mode_", digest::digest(tr, algo = "crc32"))]] %||% (input$track_mode %||% "color")),
      selected_tracks
    )
  }

  capture_track_color_values <- function(df_current = NULL, selected_tracks = NULL, track_mode_map = NULL, missing_params = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    if (is.null(df_current)) {
      return(list())
    }
    selected_tracks <- selected_tracks %||% input$tracks %||% character(0)
    selected_tracks <- selected_tracks[selected_tracks %in% names(df_current)]
    if (length(selected_tracks) == 0) {
      return(list())
    }
    track_mode_map <- track_mode_map %||% capture_track_mode_map(selected_tracks)
    color_tracks <- graphics_filter_tracks_by_mode(selected_tracks, track_mode_map, "color")
    if (length(color_tracks) == 0) {
      return(list())
    }
    track_label_map <- setNames(make.unique(vapply(color_tracks, function(tr) get_var_label(df_current, tr), character(1))), color_tracks)
    key_list <- lapply(color_tracks, function(tr) {
      vals <- unique(format_missing_vec(df_current[[tr]], params = missing_params))
      vals <- vals[!is.na(vals)]
      paste0(track_label_map[[tr]], " : ", vals)
    })
    track_keys <- unique(unlist(key_list, use.names = FALSE))
    track_keys <- head(track_keys, 30)
    setNames(
      lapply(track_keys, function(key) input[[paste0("track_col_", digest::digest(key, algo = "crc32"))]] %||% NULL),
      track_keys
    )
  }

  build_waterfall_committed_params <- function(df_current = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    selected_tracks <- input$tracks %||% character(0)
    selected_tracks <- if (is.null(df_current)) selected_tracks else selected_tracks[selected_tracks %in% names(df_current)]
    track_mode_map <- capture_track_mode_map(selected_tracks)
    missing_params <- list(
      missing_display_mode = input$missing_display_mode %||% "na",
      missing_display_custom = input$missing_display_custom %||% "NA"
    )
    symbol_styles <- capture_symbol_style_values(df_current, input$symbol_by %||% "")
    list(
      subject_id = input$subject_id,
      value_var = input$value_var,
      bar_color_by = input$bar_color_by %||% "",
      symbol_by = input$symbol_by %||% "",
      tracks = selected_tracks,
      sort_order = input$sort_order %||% "asc",
      track_mode = input$track_mode %||% "color",
      show_tracks = isTRUE(input$show_tracks),
      show_symbols = isTRUE(input$show_symbols),
      show_subject_labels = isTRUE(input$show_subject_labels),
      use_percent_label = isTRUE(input$use_percent_label),
      y_show_percent_sign = isTRUE(input$y_show_percent_sign %||% TRUE),
      y_decimals = input$y_decimals %||% 1,
      show_grid_lines = isTRUE(input$show_grid_lines),
      axis_style = input$axis_style %||% "default",
      show_legend = isTRUE(input$show_legend),
      auto_mapping_caption = isTRUE(input$auto_mapping_caption),
      main_legend_position = input$main_legend_position %||% "right",
      track_legend_position = input$track_legend_position %||% "right",
      plot_title = input$plot_title %||% "",
      plot_subtitle = input$plot_subtitle %||% "",
      plot_caption = input$plot_caption %||% "",
      plot_xlab = input$plot_xlab %||% "",
      plot_ylab = input$plot_ylab %||% "",
      legend_title = input$legend_title %||% "",
      bar_palette = input$bar_palette %||% "Set2",
      bar_single_color = input$bar_single_color %||% "#4E79A7",
      bar_border_color = input$bar_border_color %||% "#4D4D4D",
      zero_line_color = input$zero_line_color %||% "#000000",
      bar_width = input$bar_width %||% 0.9,
      symbol_text_color = input$symbol_text_color %||% "#1A1A1A",
      symbol_text_size = input$symbol_text_size %||% 4,
      track_palette = input$track_palette %||% "Set3",
      track_text_bg_color = input$track_text_bg_color %||% "#F7F7F7",
      track_text_color = input$track_text_color %||% "#1A1A1A",
      track_legend_title = input$track_legend_title %||% "轨道分组",
      track_compact_mode = isTRUE(input$track_compact_mode),
      track_tile_height = input$track_tile_height %||% 0.65,
      track_row_spacing = input$track_row_spacing %||% 0.08,
      missing_display_mode = missing_params$missing_display_mode,
      missing_display_custom = missing_params$missing_display_custom,
      y_breaks_n = input$y_breaks_n %||% 9,
      y_break_step = input$y_break_step %||% 0,
      base_font_size = input$base_font_size %||% 12,
      track_rel_height = input$track_rel_height %||% 0.5,
      base_family = input$base_family %||% "sans",
      cjk_family = input$cjk_family %||% "Noto Sans SC",
      show_recist = isTRUE(input$show_recist),
      recist_lower = input$recist_lower %||% -30,
      recist_lower_color = input$recist_lower_color %||% "#2C7BB6",
      recist_lower_linetype = input$recist_lower_linetype %||% "dashed",
      recist_lower_linewidth = input$recist_lower_linewidth %||% 0.8,
      recist_upper = input$recist_upper %||% 20,
      recist_upper_color = input$recist_upper_color %||% "#D7191C",
      recist_upper_linetype = input$recist_upper_linetype %||% "dashed",
      recist_upper_linewidth = input$recist_upper_linewidth %||% 0.8,
      show_recist_labels = isTRUE(input$show_recist_labels),
      recist_lower_label = input$recist_lower_label %||% "RECIST -30%",
      recist_upper_label = input$recist_upper_label %||% "RECIST +20%",
      bar_manual_colors = capture_bar_manual_color_values(df_current, input$bar_color_by %||% ""),
      symbol_labels = symbol_styles$labels,
      symbol_colors = symbol_styles$colors,
      track_mode_map = track_mode_map,
      track_color_values = capture_track_color_values(df_current, selected_tracks, track_mode_map, missing_params = missing_params)
    )
  }

  static_render_height <- reactive({
    cfg <- size_config()
    base_h <- as.integer(cfg$static_height)
    track_df <- prepared_track_data()
    params <- committed_params()
    show_tracks <- if (is.list(params) && !is.null(params$show_tracks)) isTRUE(params$show_tracks) else isTRUE(input$show_tracks)
    compact_mode <- if (is.list(params) && !is.null(params$track_compact_mode)) isTRUE(params$track_compact_mode) else isTRUE(input$track_compact_mode)
    track_row_spacing <- if (is.list(params) && !is.null(params$track_row_spacing)) params$track_row_spacing else (input$track_row_spacing %||% 0)
    track_tile_height <- if (is.list(params) && !is.null(params$track_tile_height)) params$track_tile_height else (input$track_tile_height %||% 0.65)
    if (is.null(track_df) || !isTRUE(show_tracks)) {
      return(base_h)
    }
    track_n <- length(unique(as.character(track_df$.track_name)))
    if (isTRUE(compact_mode)) {
      return(base_h)
    }
    tile_eff <- ifelse((track_row_spacing %||% 0) <= 1e-8, 1, track_tile_height %||% 0.65)
    base_h + as.integer(min(180, 18 * tile_eff * track_n))
  })

  output$static_plot_ui <- renderUI({
    cfg <- size_config()
    graphics_centered_output_container(
      plotOutput(ns("static_plot"), height = paste0(static_render_height(), "px"), width = "100%"),
      frame_width_px = cfg$static_width,
      frame_height_px = static_render_height()
    )
  })

  output$interactive_plot_ui <- renderUI({
    cfg <- size_config()
    graphics_centered_output_container(
      plotly::plotlyOutput(ns("interactive_plot"), height = paste0(cfg$interactive_height, "px"), width = "100%"),
      frame_width_px = cfg$interactive_width,
      frame_height_px = cfg$interactive_height,
      canvas_config = cfg,
      use_canvas_border = TRUE
    )
  })

  observeEvent(input$render_plot, {
    req(data(), input$subject_id, input$value_var)

    tryCatch({
      df <- data()
      params <- build_waterfall_committed_params(df)
      req(params$subject_id, params$value_var)
      selected_tracks <- params$tracks %||% character(0)
      track_label_map <- setNames(make.unique(vapply(selected_tracks, function(tr) get_var_label(df, tr), character(1))), selected_tracks)
      selected_cols <- unique(c(params$subject_id, params$value_var, params$bar_color_by, params$symbol_by, selected_tracks))
      selected_cols <- selected_cols[nzchar(selected_cols)]
      selected_cols <- selected_cols[selected_cols %in% names(df)]

      plot_df <- df[, selected_cols, drop = FALSE]
      names(plot_df)[names(plot_df) == params$subject_id] <- ".subject_id"
      names(plot_df)[names(plot_df) == params$value_var] <- ".value"

      if (!is.null(params$bar_color_by) && nzchar(params$bar_color_by) && params$bar_color_by %in% names(df)) {
        names(plot_df)[names(plot_df) == params$bar_color_by] <- ".bar_color"
      } else {
        plot_df$.bar_color <- "全部受试者"
      }
      if (!is.null(params$symbol_by) && nzchar(params$symbol_by) && params$symbol_by %in% names(df)) {
        names(plot_df)[names(plot_df) == params$symbol_by] <- ".symbol_group"
      } else {
        plot_df$.symbol_group <- ""
      }

      for (tr in selected_tracks) {
        names(plot_df)[names(plot_df) == tr] <- paste0(".track__", tr)
      }

      plot_df <- plot_df %>%
        mutate(
          .subject_id = as.character(.subject_id),
          .value = as.numeric(.value),
          .bar_color = as.character(.bar_color),
          .symbol_group = as.character(.symbol_group)
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
        showNotification("检测到重复受试者ID，当前按既定口径自动保留每位受试者第一条记录；后续排序、轨道区和导出结果均基于保留后的记录。", type = "warning")
      }

      plot_df <- if (params$sort_order == "desc") {
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
          mutate(across(all_of(track_cols), ~ as.character(.x))) %>%
          select(.subject_id, .subject_factor, .order, all_of(track_cols)) %>%
          pivot_longer(
            cols = all_of(track_cols),
            names_to = ".track_name",
            values_to = ".track_value"
          ) %>%
          mutate(
            .track_name_raw = sub("^\\.track__", "", .track_name),
            .track_name = unname(track_label_map[.track_name_raw]),
            .track_name = ifelse(is.na(.track_name) | !nzchar(.track_name), .track_name_raw, .track_name),
            .track_value = format_missing_vec(.track_value, params = params),
            .track_name = factor(.track_name, levels = rev(unname(track_label_map[selected_tracks])))
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
          if (!is.null(params$bar_color_by) && nzchar(params$bar_color_by)) {
            base_text <- paste0(base_text, "<br>", params$bar_color_by, ": ", r[[".bar_color"]])
          }
          if (!is.null(params$symbol_by) && nzchar(params$symbol_by) && ".symbol_group" %in% names(r) && nzchar(r[[".symbol_group"]])) {
            base_text <- paste0(base_text, "<br>", params$symbol_by, ": ", r[[".symbol_group"]])
          }
          if (length(track_cols) > 0) {
            track_text <- vapply(
              selected_tracks,
              function(tr) {
                key <- paste0(".track__", tr)
                val <- if (key %in% names(r)) format_missing_vec(r[[key]], params = params) else get_missing_text(params)
                if (length(val) > 1) val <- val[[1]]
                paste0(get_var_label(df, tr), ": ", val)
              },
              character(1)
            )
            base_text <- paste0(base_text, "<br>", paste(track_text, collapse = "<br>"))
          }
          base_text
        }
      )

      plot_df$.tooltip <- tooltip_text

      y_axis_title <- if (isTRUE(params$use_percent_label) && !nzchar(params$plot_ylab %||% "")) {
        "较基线变化 (%)"
      } else if (nzchar(params$plot_ylab %||% "")) {
        params$plot_ylab
      } else {
        params$value_var
      }

      x_axis_title <- if (nzchar(params$plot_xlab %||% "")) params$plot_xlab else "受试者"
      legend_title <- graphics_resolve_legend_title(params$legend_title, get_var_label(df, params$bar_color_by), "分组")
      auto_caption_lines <- character(0)
      font_spec <- graphics_resolve_font_spec(
        base_family = params$base_family %||% "sans",
        cjk_family = params$cjk_family %||% "Noto Sans SC"
      )
      plot_family <- font_spec$unified

      p_main <- ggplot(plot_df, aes(x = .subject_factor, y = .value, fill = .bar_color, text = .tooltip)) +
        geom_col(width = params$bar_width, color = params$bar_border_color) +
        geom_hline(yintercept = 0, color = params$zero_line_color, linewidth = 0.35) +
        labs(
          title = ifelse(nzchar(params$plot_title %||% ""), params$plot_title, "瀑布图"),
          subtitle = params$plot_subtitle %||% "",
          x = x_axis_title,
          y = y_axis_title,
          fill = legend_title
        ) +
        theme_minimal(base_size = params$base_font_size, base_family = plot_family) +
        theme(
          axis.text.x = if (isTRUE(params$show_subject_labels)) element_text(angle = 90, vjust = 0.5, hjust = 1) else element_blank(),
          axis.ticks.x = if (isTRUE(params$show_subject_labels)) element_line() else element_blank(),
          panel.grid.major.x = element_blank()
        )

      group_levels <- unique(plot_df$.bar_color)
      if (length(group_levels) <= 1) {
        p_main <- p_main + scale_fill_manual(values = setNames(params$bar_single_color, group_levels))
      } else {
        default_vals <- palette_values(length(group_levels), params$bar_palette %||% "hue")
        color_vals <- setNames(default_vals, group_levels)
        for (lv in group_levels) {
          bar_color <- params$bar_manual_colors[[lv]]
          if (!is.null(bar_color) && nzchar(bar_color %||% "")) {
            color_vals[[lv]] <- bar_color
          }
        }
        p_main <- p_main + scale_fill_manual(values = color_vals)
      }

      if (!is.null(params$y_break_step) && params$y_break_step > 0) {
        y_breaks_fun <- function(x) seq(floor(min(x, na.rm=TRUE) / params$y_break_step) * params$y_break_step, ceiling(max(x, na.rm=TRUE) / params$y_break_step) * params$y_break_step, by = params$y_break_step)
      } else {
        y_breaks_fun <- scales::breaks_pretty(n = params$y_breaks_n %||% 9)
      }
      
      if (isTRUE(params$use_percent_label)) {
        p_main <- p_main + scale_y_continuous(
          breaks = y_breaks_fun,
          labels = graphics_format_percent_labels(show_percent_sign = isTRUE(params$y_show_percent_sign %||% TRUE), scale_factor = 1, decimals = params$y_decimals %||% 1),
          expand = expansion(mult = c(0.02, 0.12))
        )
      } else {
        p_main <- p_main + scale_y_continuous(
          breaks = y_breaks_fun,
          labels = graphics_format_number_labels(decimals = params$y_decimals %||% 1),
          expand = expansion(mult = c(0.02, 0.12))
        )
      }

      if (isTRUE(params$show_symbols) && !is.null(params$symbol_by) && nzchar(params$symbol_by)) {
        if (isTRUE(params$auto_mapping_caption)) {
          auto_caption_lines <- c(auto_caption_lines, graphics_mapping_caption_line(get_var_label(df, params$symbol_by), "柱符号"))
        }
        symbol_levels <- unique(plot_df$.symbol_group)
        symbol_levels <- symbol_levels[!is.na(symbol_levels) & nzchar(symbol_levels)]
        if (length(symbol_levels) > 0) {
          default_symbols <- unname(.waterfall_symbol_choices())
          symbol_map <- setNames(
            vapply(symbol_levels, function(lv) {
              lbl <- params$symbol_labels[[lv]]
              idx <- match(lv, symbol_levels)
              if (is.null(lbl) || !nzchar(lbl)) default_symbols[[idx]] else lbl
            }, character(1)),
            symbol_levels
          )
          symbol_color_defaults <- setNames(rep(params$symbol_text_color %||% "#1A1A1A", length(symbol_levels)), symbol_levels)
          symbol_color_map <- setNames(
            vapply(symbol_levels, function(lv) {
              val <- params$symbol_colors[[lv]]
              if (is.null(val) || !nzchar(val)) symbol_color_defaults[[lv]] else val
            }, character(1)),
            symbol_levels
          )
          value_range <- range(plot_df$.value, na.rm = TRUE)
          symbol_offset <- max(diff(value_range) * 0.03, 0.5)
          symbol_df <- plot_df %>%
            mutate(
              .symbol_label = ifelse(!is.na(.symbol_group) & nzchar(.symbol_group), unname(symbol_map[.symbol_group]), ""),
              .symbol_color = unname(symbol_color_map[.symbol_group]),
              .symbol_y = .value + ifelse(.value >= 0, symbol_offset, -symbol_offset)
            ) %>%
            filter(nzchar(.symbol_label))
          if (nrow(symbol_df) > 0) {
            p_main <- p_main +
              geom_text(
                data = symbol_df,
                aes(x = .subject_factor, y = .symbol_y, label = .symbol_label, color = .symbol_group),
                inherit.aes = FALSE,
                size = params$symbol_text_size,
                family = plot_family
              ) +
              scale_color_manual(values = symbol_color_map, guide = "none")
          }
        }
      }

      if (isTRUE(params$show_recist)) {
        p_main <- graphics_add_reference_lines(
          p_main,
          list(
            collect_reference_line_spec_from_params(params, "recist_lower", orientation = "h", fallback_value = -30, fallback_color = "#2C7BB6", fallback_linewidth = 0.8),
            collect_reference_line_spec_from_params(params, "recist_upper", orientation = "h", fallback_value = 20, fallback_color = "#D7191C", fallback_linewidth = 0.8)
          )
        )
        if (isTRUE(params$show_recist_labels)) {
          p_main <- p_main +
            annotate("text", x = Inf, y = params$recist_lower, label = params$recist_lower_label %||% "", hjust = 1.02, vjust = -0.2, color = params$recist_lower_color, size = 3.5, family = plot_family) +
            annotate("text", x = Inf, y = params$recist_upper, label = params$recist_upper_label %||% "", hjust = 1.02, vjust = -0.2, color = params$recist_upper_color, size = 3.5, family = plot_family)
        }
      }

      if (!isTRUE(params$show_grid_lines)) {
        p_main <- p_main + theme(panel.grid = element_blank(), panel.grid.minor = element_blank())
      }
      if ((params$axis_style %||% "default") %in% c("classic_arrow", "classic")) {
        is_arrow <- (params$axis_style %||% "default") == "classic_arrow"
        n_x <- length(levels(plot_df$.subject_factor))
        y_rng <- range(plot_df$.value, na.rm = TRUE)
        y_span <- max(1e-6, diff(y_rng))
        y_axis_base <- y_rng[1] - 0.06 * y_span
        y_axis_top <- y_rng[2] + 0.08 * y_span
        p_main <- p_main +
          theme_classic(base_size = params$base_font_size, base_family = plot_family) +
          theme(
            axis.text.x = if (isTRUE(params$show_subject_labels)) element_text(angle = 90, vjust = 0.5, hjust = 1) else element_blank(),
            axis.ticks.x = if (isTRUE(params$show_subject_labels)) element_line() else element_blank(),
            plot.margin = margin(10, 20, 14, 16)
          ) +
          coord_cartesian(clip = "off")
        
        if (is_arrow) {
          p_main <- p_main + 
            annotate("segment", x = 0.5, xend = n_x + 0.55, y = y_axis_base, yend = y_axis_base, arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"), linewidth = 0.45, color = "black") +
            annotate("segment", x = 0.5, xend = 0.5, y = y_axis_base, yend = y_axis_top, arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"), linewidth = 0.45, color = "black")
        } else {
          p_main <- p_main + 
            annotate("segment", x = 0.5, xend = n_x + 0.55, y = y_axis_base, yend = y_axis_base, linewidth = 0.45, color = "black", lineend = "square") +
            annotate("segment", x = 0.5, xend = 0.5, y = y_axis_base, yend = y_axis_top, linewidth = 0.45, color = "black", lineend = "square")
        }
      } else {
        p_main <- p_main + theme(
          axis.line = element_line(colour = "black")
        )
      }
      p_main <- graphics_apply_legend_theme(
        p_main,
        show_legend = isTRUE(params$show_legend),
        position = params$main_legend_position %||% "right"
      )

      if (is.null(track_df) || !isTRUE(params$show_tracks)) {
        p_combined <- p_main
      } else {
        if (isTRUE(params$auto_mapping_caption) && length(selected_tracks) > 0) {
          auto_caption_lines <- c(auto_caption_lines, paste0("轨道图显示变量：", paste(vapply(selected_tracks, function(tr) get_var_label(df, tr), character(1)), collapse = "、"), "。"))
        }
        track_mode_map <- setNames(
          vapply(selected_tracks, function(tr) {
            mode_val <- params$track_mode_map[[tr]]
            if (is.null(mode_val) || !nzchar(mode_val)) params$track_mode %||% "color" else mode_val
          }, character(1)),
          selected_tracks
        )

        track_df <- track_df %>%
          mutate(
            .track_mode = unname(track_mode_map[.track_name_raw]),
            .track_mode = ifelse(is.na(.track_mode), params$track_mode %||% "color", .track_mode)
          )

        text_track_df <- track_df %>% filter(.track_mode == "text")
        color_track_df <- track_df %>%
          filter(.track_mode == "color") %>%
          mutate(.track_legend_key = paste0(as.character(.track_name), " : ", .track_value))
        track_keys <- unique(color_track_df$.track_legend_key)
        track_colors <- setNames(palette_values(length(track_keys), params$track_palette %||% "hue"), track_keys)
        if (length(track_keys) > 0) {
          manual_track_colors <- setNames(lapply(track_keys, function(key) params$track_color_values[[key]]), track_keys)
          track_colors <- graphics_override_colors(track_colors, manual_track_colors)
        }

        compact_mode <- isTRUE(params$track_compact_mode)
        track_row_spacing_eff <- if (compact_mode) 0 else max(0, params$track_row_spacing %||% 0)
        track_tile_height_eff <- if (track_row_spacing_eff <= 1e-8) 1 else (if (compact_mode) min(0.35, params$track_tile_height %||% 0.65) else (params$track_tile_height %||% 0.65))
        track_rel_eff <- if (compact_mode) min(0.35, params$track_rel_height %||% 0.5) else (params$track_rel_height %||% 0.5)

        p_track <- ggplot(track_df, aes(x = .subject_factor, y = .track_name))
        if (nrow(color_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = color_track_df, aes(fill = .track_legend_key), color = "white", height = track_tile_height_eff)
        }
        if (nrow(text_track_df) > 0) {
          p_track <- p_track +
            geom_tile(data = text_track_df, fill = params$track_text_bg_color, color = "white", height = track_tile_height_eff) +
            geom_text(data = text_track_df, aes(label = .track_value), size = max(2.8, params$base_font_size * 0.22), color = params$track_text_color, family = plot_family)
        }
        if (nrow(color_track_df) > 0) {
          p_track <- p_track + scale_fill_manual(values = track_colors)
        }
        p_track <- p_track +
          labs(x = NULL, y = NULL, fill = graphics_resolve_legend_title(params$track_legend_title, "轨道分组")) +
          scale_y_discrete(expand = expansion(add = c(track_row_spacing_eff, track_row_spacing_eff))) +
          theme_minimal(base_size = max(9, params$base_font_size - 1), base_family = plot_family) +
          theme(
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            panel.grid = element_blank()
          )
        p_track <- graphics_apply_legend_theme(
          p_track,
          show_legend = isTRUE(params$show_legend) && nrow(color_track_df) > 0,
          position = params$track_legend_position %||% "right"
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

      p_combined <- graphics_append_bottom_caption(
        p_combined,
        graphics_compose_caption(params$plot_caption %||% "", auto_caption_lines),
        base_font_size = params$base_font_size %||% 12,
        font_family = params$base_family %||% "sans",
        cjk_family = params$cjk_family %||% "Noto Sans SC",
        layout_family = font_spec$layout
      )

      committed_params(params)
      final_plot(p_combined)
      main_plot_obj(p_main)
      prepared_data(plot_df %>% select(.order, .subject_id, .value, .bar_color, everything()))
      prepared_track_data(track_df)
      showNotification("瀑布图生成完成", type = "message")
    }, error = function(e) {
      committed_params(NULL)
      final_plot(NULL)
      main_plot_obj(NULL)
      prepared_data(NULL)
      prepared_track_data(NULL)
      graphics_notify_error("瀑布图", e)
    })
  })

  output$static_plot <- renderPlot({
    req(final_plot())
    cfg <- size_config()
    graphics_apply_canvas_frame(
      final_plot(),
      frame_width_px = cfg$static_width,
      frame_height_px = static_render_height(),
      canvas_config = cfg
    )
  }, width = function() {
    as.integer(size_config()$static_width)
  }, height = function() {
    static_render_height()
  })

  output$interactive_plot <- plotly::renderPlotly({
    req(main_plot_obj())
    cfg <- size_config()
    plotly::layout(
      ggplotly(main_plot_obj(), tooltip = "text", width = as.integer(cfg$interactive_width), height = as.integer(cfg$interactive_height)),
      margin = list(
        l = cfg$page_margin_left,
        r = cfg$page_margin_right,
        t = cfg$page_margin_top,
        b = cfg$page_margin_bottom
      ),
      paper_bgcolor = cfg$canvas_background,
      plot_bgcolor = cfg$canvas_background
    )
  })

  output$data_table <- renderDT({
    req(prepared_data())
    datatable(prepared_data(), options = list(pageLength = 15, scrollX = TRUE))
  })

  output$track_table <- renderDT({
    track_df <- prepared_track_data()
    shiny::validate(shiny::need(!is.null(track_df), "未选择分组轨道变量"))
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
      cfg <- size_config()
      save_plot_export(
        file = file,
        plot_obj = graphics_apply_canvas_frame(
          final_plot(),
          frame_width_px = cfg$static_width,
          frame_height_px = static_render_height(),
          canvas_config = cfg
        ),
        format = input$export_format,
        width = cfg$export_width,
        height = graphics_scale_export_height(
          static_width_px = cfg$static_width,
          static_height_px = static_render_height(),
          export_width_in = cfg$export_width
        ),
        dpi = input$export_dpi %||% 600
      )
    }
  )

  apply_state <- function(state) {
    graphics_restore_task_input_state(session, state)
    invisible(TRUE)
  }

  list(
    state = reactive({
      graphics_build_task_state(
        input,
        extra_state = list(
          subject_id = input$subject_id,
          value_var = input$value_var,
          color_by = input$bar_color_by,
          symbol_by = input$symbol_by,
          tracks = if (is.null(input$tracks)) character(0) else input$tracks,
          size_mode = input$size_mode,
          export_width_in = size_config()$export_width,
          export_height_in = size_config()$export_height
        )
      )
    }),
    apply_state = apply_state
  )
}
