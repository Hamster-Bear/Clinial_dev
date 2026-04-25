library(ggplot2)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(cowplot)
library(scales)

if (!exists("app_card_box", mode = "function") ||
    !exists("app_card_note", mode = "function") ||
    !exists("app_result_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}
if (file.exists("modules/common/graphics_result_copy.R")) {
  source("modules/common/graphics_result_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics_result_copy.R"))
}
if (file.exists("modules/common/graphics_export_copy.R")) {
  source("modules/common/graphics_export_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics_export_copy.R"))
}

swimmer_plot_ui <- function(id) {
  ns <- NS(id)
  copy <- GRAPHICS_RESULT_COPY$swimmer
  export_copy <- GRAPHICS_EXPORT_COPY$swimmer

  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "设置核心映射、事件映射与轨道变量",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("选择时间模式、事件映射、轨道变量和排序方式。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "核心映射",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "核心映射",
                    fields = list(
                      list(list(id = "subject_id", label = "受试者ID变量", type = "selectize")),
                      list(list(id = "lane_time_mode", label = "泳道时间模式", type = "select", choices = c("起始+结束时间" = "start_end", "ADY/时长变量" = "duration"), selected = "start_end"))
                    ),
                    extra_ui = tagList(
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
                      )
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
                      list(list(id = "lane_color_by", label = "泳道颜色分组", type = "selectize")),
                      list(list(id = "ongoing_var", label = "持续中标记变量", type = "selectize"))
                    ),
                    help_text = "泳道图当前没有独立分面变量；事件映射和轨道变量在本页签中设置。"
                  ),
                  graphics_dynamic_mapping_rows_panel_ui(
                    ns,
                    title = "事件映射",
                    rows_ui = uiOutput(ns("event_mapping_ui")),
                    add_button_id = "add_event_map",
                    remove_button_id = "remove_event_map",
                    add_label = "添加事件变量组",
                    remove_label = "减少事件变量组"
                  ),
                  graphics_card_panel_ui(
                    title = "轨道变量与排序",
                    tagList(
                      selectizeInput(ns("tracks"), "下方分组轨道(可多选)", choices = NULL, multiple = TRUE, width = "100%"),
                      helpText("默认不自动填入轨道变量；仅当你明确选择后，才在下方轨道区和分组轨道数据中显示。"),
                      selectInput(
                        ns("sort_mode"),
                        "受试者排序方式",
                        choices = c(
                          "随访时长-降序" = "duration_desc",
                          "随访时长-升序" = "duration_asc",
                          "泳道终点-降序" = "end_desc",
                          "泳道终点-升序" = "end_asc",
                          "受试者ID" = "subject"
                        ),
                        selected = "duration_desc",
                        width = "100%"
                      ),
                      helpText("排序基于每位受试者汇总后的主泳道长度或绘图终点位置；若使用日期型起止时间，这里的“泳道终点”指换算后的随访终点位置，而不是原始日历日期。"),
                      checkboxInput(ns("show_tracks"), "显示下方分组轨道", TRUE),
                      selectInput(ns("track_mode"), "轨道默认展示方式", choices = c("颜色填充" = "color", "文本填充" = "text"), selected = "color", width = "100%"),
                      helpText("这里设置的是新选轨道的默认展示方式；下方“分组轨道展示方式”可对每条轨道分别改成颜色填充或文本填充。"),
                      uiOutput(ns("track_mode_controls")),
                      uiOutput(ns("track_color_controls"))
                    )
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
          subtitle = "设置标题、坐标、图例与轨道区样式",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置事件样式、主图颜色映射、缺失值文本和下方轨道区比例。"),
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
                      list(list(id = "plot_title", label = "主标题", type = "text", selected = "泳道图")),
                      list(list(id = "plot_subtitle", label = "副标题", type = "text", selected = "")),
                      list(list(id = "plot_caption", label = "脚注", type = "text", selected = "")),
                      list(
                        list(id = "plot_xlab", label = "X轴标签", type = "text", selected = "时间", column = 6),
                        list(id = "plot_ylab", label = "Y轴标签", type = "text", selected = "受试者", column = 6)
                      ),
                      list(list(id = "lane_legend_title", label = "泳道图例标题", type = "text", selected = ""))
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
                          list(list(id = "show_legend", label = "显示图例", type = "checkbox", value = TRUE)),
                          list(
                            list(id = "main_legend_position", label = "主图图例位置", type = "select", choices = graphics_legend_position_choices("outer"), selected = "right", column = 6),
                            list(id = "track_legend_position", label = "轨道图例位置", type = "select", choices = graphics_legend_position_choices("outer"), selected = "right", column = 6)
                          ),
                          list(list(id = "show_grid_lines", label = "显示网格线", type = "checkbox", value = TRUE)),
                          list(list(id = "show_subject_labels", label = "显示受试者标签", type = "checkbox", value = TRUE)),
                          list(list(id = "show_ongoing_arrow", label = "持续中显示箭头", type = "checkbox", value = TRUE))
                        )
                      )
                    ),
                    column(
                      6,
                      graphics_axis_proportion_panel_ui(
                        ns,
                        title = "坐标与尺寸",
                        prepend_ui = tagList(
                          selectInput(ns("axis_style"), "坐标轴样式", choices = c("默认" = "default", "经典坐标轴(不带箭头)" = "classic", "经典XY轴(箭头)" = "classic_arrow"), selected = "default", width = "100%"),
                          graphics_time_axis_panel_ui(
                            ns,
                            title = "时间轴设置",
                            unit_id = "x_unit",
                            unit_label = "X轴单位换算",
                            unit_choices = c("天" = "day", "周" = "week", "月(30.44天)" = "month", "年(365.25天)" = "year"),
                            selected_unit = "day",
                            step_id = "x_break_step",
                            step_label = "X轴刻度步长(0为自动)",
                            step_value = 0,
                            step_min = 0,
                            step_step = 0.1,
                            include_range_slider = TRUE,
                            slider_id = "time_range_slider",
                            include_slider_step_input = FALSE
                          )
                        ),
                        fields = list(
                          list(
                            list(id = "lane_size", label = "泳道线宽", type = "slider", value = 4, min = 0.8, max = 8, step = 0.2, column = 6),
                            list(id = "event_size", label = "事件点大小", type = "slider", value = 3.2, min = 1, max = 8, step = 0.2, column = 6)
                          )
                        )
                      )
                    )
                  )
                ),
                tabPanel(
                  "图层样式",
                  br(),
                  graphics_symbol_style_panel_ui(
                    ns,
                    title = "事件图例与样式",
                    fields = list(
                      list(list(id = "show_event_labels", label = "显示事件文本标签", type = "checkbox", value = FALSE)),
                      list(list(id = "lock_event_style_refresh", label = "锁定事件样式（变量刷新不重置）", type = "checkbox", value = TRUE)),
                      list(list(id = "event_palette", label = "事件调色板", type = "select", choices = c("默认Hue" = "hue", "Set1" = "Set1", "Set2" = "Set2", "Dark2" = "Dark2", "Paired" = "Paired", "Viridis" = "viridis"), selected = "Set1")),
                      list(list(id = "auto_mapping_caption", label = "自动追加样式脚注", type = "checkbox", value = TRUE)),
                      list(list(id = "event_legend_position", label = "事件图例位置", type = "select", choices = graphics_legend_position_choices("aux"), selected = "right")),
                      list(list(id = "event_legend_title", label = "事件总图例标题(可选)", type = "text", selected = ""))
                    ),
                    prepend_ui = numericInput(ns("event_symbol_seed"), "随机符号种子", value = 2026, min = 1, step = 1, width = "100%"),
                    extra_ui = graphics_aux_legend_anchor_controls_ui(
                      ns,
                      position_id = "event_legend_position",
                      x_ratio_id = "event_legend_x_ratio",
                      y_ratio_id = "event_legend_y_ratio",
                      width_ratio_id = "event_legend_width_ratio",
                      height_ratio_id = "event_legend_height_ratio",
                      default_anchor = c(0.95, 0.85, 0.13, 0.14)
                    ),
                    help_text = "这里控制事件图例整体层级；每个事件变量组自己的图例标题在“事件映射”中逐组设置。"
                  ),
                  fluidRow(
                    column(
                      6,
                      graphics_group_style_mapping_panel_ui(
                        "事件分组样式",
                        uiOutput(ns("event_group_style_controls"))
                      )
                    ),
                    column(
                      6,
                      graphics_palette_layout_panel_ui(
                        ns,
                        title = "泳道主色",
                        fields = list(
                          list(list(id = "lane_alpha", label = "泳道透明度", type = "slider", value = 0.9, min = 0.3, max = 1, step = 0.05)),
                          list(list(id = "lane_palette", label = "泳道调色板", type = "select", choices = graphics_palette_choice_values("qualitative"), selected = "Set2")),
                          list(list(id = "lane_color_mode", label = "泳道颜色分配", type = "select", choices = c("调色板自动" = "palette", "分别指定" = "manual_each"), selected = "palette"))
                        )
                      )
                    )
                  ),
                  graphics_group_style_mapping_panel_ui(
                    "分组颜色映射",
                    uiOutput(ns("lane_color_controls"))
                  ),
                  fluidRow(
                    column(
                      6,
                      graphics_card_panel_ui(
                        title = "轨道显示",
                        tagList(
                          colourpicker::colourInput(ns("track_text_bg_color"), "轨道文本底色", value = "#F7F7F7", width = "100%"),
                          textInput(ns("track_legend_title"), "轨道总图例标题", value = "轨道分组", width = "100%"),
                          checkboxInput(ns("track_compact_mode"), "轨道紧凑模式", TRUE),
                          fluidRow(
                            column(6, sliderInput(ns("track_tile_height"), "轨道方框高度", min = 0.1, max = 1.4, value = 0.65, step = 0.05, width = "100%")),
                            column(6, sliderInput(ns("track_row_spacing"), "轨道行间距", min = 0, max = 0.8, value = 0.08, step = 0.02, width = "100%"))
                          ),
                          helpText("这里控制下方分组轨道区的显示方式与总图例标题，不影响泳道主图的颜色分组图例。")
                        )
                      )
                    ),
                    column(
                      6,
                      graphics_card_panel_ui(
                        title = "缺失值与版式",
                        tagList(
                          selectInput(ns("missing_display_mode"), "空值显示方式", choices = c("空白" = "blank", "无" = "none", "NA" = "na", "破折号" = "dash", "自定义" = "custom"), selected = "na", width = "100%"),
                          conditionalPanel(
                            condition = sprintf("input['%s'] === 'custom'", ns("missing_display_mode")),
                            textInput(ns("missing_display_custom"), "自定义空值文本", value = "NA", width = "100%")
                          ),
                          sliderInput(ns("track_rel_height"), "下方轨道区占比", min = 0.5, max = 4, value = 0.5, step = 0.1, width = "100%"),
                          fluidRow(
                            column(6, numericInput(ns("base_font_size"), "全局字号", value = 12, min = 8, max = 22, step = 1, width = "100%")),
                            column(6, graphics_font_family_pair_ui(ns, latin_id = "base_family", cjk_id = "cjk_family"))
                          ),
                          helpText("“空值显示方式”影响轨道和数据表中的缺失文本；“下方轨道区占比”和“全局字号”影响主图与下方轨道区的版式比例。")
                        )
                      )
                    )
                  )
                ),
                tabPanel(
                  "参考线与阈值",
                  br(),
                  graphics_card_panel_ui(
                    title = "参考线与阈值",
                    tagList(
                      helpText("泳道图当前没有独立的参考线或阈值控件。"),
                      helpText("当前页签未提供业务阈值线设置。")
                    )
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
          graphics_output_action_bar_ui(ns, render_button_id = "render_plot", download_id = "dl_plot"),
          tabsetPanel(
            id = ns("output_tabs"),
            tabPanel(
              "静态图",
              app_result_panel(
                title = "静态图结果",
                note = copy$static_plot$note,
                tone = "success",
                uiOutput(ns("static_plot_ui"))
              )
            ),
            tabPanel(
              "交互图",
              app_result_panel(
                title = "交互图结果",
                note = copy$interactive_plot$note,
                tone = "info",
                uiOutput(ns("interactive_plot_ui"))
              )
            ),
            tabPanel(
              "数据",
              app_result_panel(
                title = "泳道数据、事件数据与分组轨道数据",
                note = copy$data_tab$note,
                tone = "warning",
                tabsetPanel(
                  tabPanel("泳道数据", DTOutput(ns("lane_table"))),
                  tabPanel("事件数据", DTOutput(ns("event_table"))),
                  tabPanel("分组轨道数据", DTOutput(ns("track_table")))
                )
              )
            )
          )
        )
      )
    )
  )
}

swimmer_plot_server <- function(input, output, session, data) {
  ns <- session$ns
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
  shape_choice_values <- graphics_shape_choice_values()

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

  normalize_time_range <- function(x) {
    if (is.null(x) || length(x) != 2) {
      return(NULL)
    }
    range_num <- suppressWarnings(as.numeric(x))
    if (any(is.na(range_num)) || any(!is.finite(range_num))) {
      return(NULL)
    }
    range_num
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
    time_range = NULL,
    lane_color_by = "",
    ongoing_var = "",
    tracks = character(0),
    columns_signature = NULL
  )
  event_map_count <- reactiveVal(1)
  event_ui_state <- reactiveVal(list())
  restoring_event_controls <- reactiveVal(FALSE)
  committed_params <- reactiveVal(NULL)

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
        event_grp_color_mode = input[[paste0("event_grp_color_mode_", i)]] %||% state_get(i, "event_grp_color_mode", "random_unique"),
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

  capture_lane_manual_color_values <- function(df_current = NULL) {
    if (!identical(input$lane_color_mode %||% "palette", "manual_each")) {
      return(list())
    }
    if (is.null(df_current)) {
      df_current <- data()
    }
    if (is.null(df_current)) {
      return(list())
    }
    lane_color_source <- graphics_resolve_mapping_var(input$lane_color_by, input$subject_id, names(df_current), enable_fallback = TRUE)
    if (is.null(lane_color_source) || !nzchar(lane_color_source) || !(lane_color_source %in% names(df_current))) {
      return(list())
    }
    levels <- unique(as.character(df_current[[lane_color_source]]))
    levels <- levels[!is.na(levels) & nzchar(levels)]
    levels <- head(levels, 12)
    setNames(
      lapply(levels, function(lv) input[[paste0("lane_col_", digest::digest(lv, algo = "crc32"))]] %||% NULL),
      levels
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

  capture_track_color_values <- function(df_current = NULL, selected_tracks = NULL, track_mode_map = NULL) {
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
      vals <- unique(format_missing_vec(df_current[[tr]]))
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

  capture_event_style_snapshot <- function(i, df_current = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    event_type_var <- input[[paste0("event_type_", i)]] %||% state_get(i, "event_type", "")
    event_levels <- if (!is.null(df_current) && !is.null(event_type_var) && nzchar(event_type_var) && event_type_var %in% names(df_current)) {
      vals <- unique(as.character(df_current[[event_type_var]]))
      vals[!is.na(vals) & nzchar(vals)]
    } else {
      character(0)
    }
    list(
      event_grp_color_mode = input[[paste0("event_grp_color_mode_", i)]] %||% state_get(i, "event_grp_color_mode", "random_unique"),
      event_grp_col = input[[paste0("event_grp_col_", i)]] %||% state_get(i, "event_grp_col", NULL),
      event_grp_shape = input[[paste0("event_grp_shape_", i)]] %||% state_get(i, "event_grp_shape", NULL),
      event_grp_symbol_mode = input[[paste0("event_grp_symbol_mode_", i)]] %||% state_get(i, "event_grp_symbol_mode", "random_unique"),
      event_grp_col_each = setNames(
        lapply(event_levels, function(lv) input[[paste0("event_grp_col_each_", i, "_", digest::digest(lv, algo = "crc32"))]] %||% NULL),
        event_levels
      ),
      event_grp_shape_each = setNames(
        lapply(event_levels, function(lv) input[[paste0("event_grp_shape_each_", i, "_", digest::digest(lv, algo = "crc32"))]] %||% NULL),
        event_levels
      )
    )
  }

  restore_swimmer_dynamic_style_inputs <- function(extra_state) {
    if (!is.list(extra_state)) {
      return(invisible(NULL))
    }
    if (is.list(extra_state$track_mode_map) && length(extra_state$track_mode_map) > 0) {
      for (track_name in names(extra_state$track_mode_map)) {
        updateSelectInput(
          session,
          paste0("track_mode_", digest::digest(track_name, algo = "crc32")),
          selected = extra_state$track_mode_map[[track_name]] %||% "color"
        )
      }
    }
    if (is.list(extra_state$lane_manual_colors) && length(extra_state$lane_manual_colors) > 0) {
      for (lane_name in names(extra_state$lane_manual_colors)) {
        lane_color <- extra_state$lane_manual_colors[[lane_name]]
        if (!is.null(lane_color) && nzchar(lane_color %||% "")) {
          colourpicker::updateColourInput(session, paste0("lane_col_", digest::digest(lane_name, algo = "crc32")), value = lane_color)
        }
      }
    }
    if (is.list(extra_state$track_color_values) && length(extra_state$track_color_values) > 0) {
      for (track_key in names(extra_state$track_color_values)) {
        track_color <- extra_state$track_color_values[[track_key]]
        if (!is.null(track_color) && nzchar(track_color %||% "")) {
          colourpicker::updateColourInput(session, paste0("track_col_", digest::digest(track_key, algo = "crc32")), value = track_color)
        }
      }
    }
    if (is.list(extra_state$event_mappings) && length(extra_state$event_mappings) > 0) {
      for (i in seq_len(length(extra_state$event_mappings))) {
        mapping <- extra_state$event_mappings[[i]]
        if (!is.null(mapping$event_grp_color_mode)) updateSelectInput(session, paste0("event_grp_color_mode_", i), selected = mapping$event_grp_color_mode)
        if (!is.null(mapping$event_grp_symbol_mode)) updateSelectInput(session, paste0("event_grp_symbol_mode_", i), selected = mapping$event_grp_symbol_mode)
        if (!is.null(mapping$event_grp_col) && nzchar(mapping$event_grp_col %||% "")) {
          colourpicker::updateColourInput(session, paste0("event_grp_col_", i), value = mapping$event_grp_col)
        }
        if (!is.null(mapping$event_grp_shape)) {
          updateSelectInput(session, paste0("event_grp_shape_", i), selected = mapping$event_grp_shape)
        }
        if (is.list(mapping$event_grp_col_each) && length(mapping$event_grp_col_each) > 0) {
          for (level_name in names(mapping$event_grp_col_each)) {
            level_color <- mapping$event_grp_col_each[[level_name]]
            if (!is.null(level_color) && nzchar(level_color %||% "")) {
              colourpicker::updateColourInput(session, paste0("event_grp_col_each_", i, "_", digest::digest(level_name, algo = "crc32")), value = level_color)
            }
          }
        }
        if (is.list(mapping$event_grp_shape_each) && length(mapping$event_grp_shape_each) > 0) {
          for (level_name in names(mapping$event_grp_shape_each)) {
            level_shape <- mapping$event_grp_shape_each[[level_name]]
            if (!is.null(level_shape) && nzchar(as.character(level_shape) %||% "")) {
              updateSelectInput(session, paste0("event_grp_shape_each_", i, "_", digest::digest(level_name, algo = "crc32")), selected = level_shape)
            }
          }
        }
      }
    }
    invisible(NULL)
  }

  collect_swimmer_event_mappings <- function(df_current = NULL) {
    lapply(seq_len(event_map_count()), function(i) {
      c(
        list(
          event_time = input[[paste0("event_time_", i)]] %||% "",
          event_type = input[[paste0("event_type_", i)]] %||% "",
          event_label = input[[paste0("event_label_", i)]] %||% "",
          event_legend_title = input[[paste0("event_legend_title_", i)]] %||% ""
        ),
        capture_event_style_snapshot(i, df_current)
      )
    })
  }

  build_swimmer_committed_params <- function(df_current = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    selected_tracks <- input$tracks %||% character(0)
    track_mode_map <- capture_track_mode_map(selected_tracks)
    list(
      subject_id = input$subject_id,
      lane_time_mode = input$lane_time_mode %||% "start_end",
      start_time = input$start_time %||% "",
      end_time = input$end_time %||% "",
      duration_var = input$duration_var %||% "",
      lane_color_by = input$lane_color_by %||% "",
      ongoing_var = input$ongoing_var %||% "",
      lane_color_mode = input$lane_color_mode %||% "palette",
      lane_palette = input$lane_palette %||% "Set2",
      lane_size = input$lane_size %||% 4,
      lane_alpha = input$lane_alpha %||% 0.9,
      lane_legend_title = input$lane_legend_title %||% "",
      sort_mode = input$sort_mode %||% "duration_desc",
      tracks = selected_tracks,
      show_tracks = isTRUE(input$show_tracks),
      track_mode = input$track_mode %||% "color",
      track_mode_map = track_mode_map,
      track_text_bg_color = input$track_text_bg_color %||% "#F7F7F7",
      track_legend_title = input$track_legend_title %||% "轨道分组",
      track_legend_position = input$track_legend_position %||% "right",
      track_compact_mode = isTRUE(input$track_compact_mode),
      track_tile_height = input$track_tile_height %||% 0.65,
      track_row_spacing = input$track_row_spacing %||% 0.08,
      track_rel_height = input$track_rel_height %||% 0.5,
      missing_display_mode = input$missing_display_mode %||% "na",
      missing_display_custom = input$missing_display_custom %||% "NA",
      plot_title = input$plot_title %||% "",
      plot_subtitle = input$plot_subtitle %||% "",
      plot_caption = input$plot_caption %||% "",
      plot_xlab = input$plot_xlab %||% "",
      plot_ylab = input$plot_ylab %||% "",
      show_legend = isTRUE(input$show_legend),
      main_legend_position = input$main_legend_position %||% "right",
      show_grid_lines = isTRUE(input$show_grid_lines),
      show_subject_labels = isTRUE(input$show_subject_labels),
      show_ongoing_arrow = isTRUE(input$show_ongoing_arrow),
      axis_style = input$axis_style %||% "default",
      x_unit = input$x_unit %||% "day",
      x_break_step = input$x_break_step %||% 0,
      time_range = normalize_time_range(input$time_range),
      event_size = input$event_size %||% 3.2,
      show_event_labels = isTRUE(input$show_event_labels),
      lock_event_style_refresh = isTRUE(input$lock_event_style_refresh),
      event_palette = input$event_palette %||% "Set1",
      auto_mapping_caption = isTRUE(input$auto_mapping_caption),
      event_symbol_seed = input$event_symbol_seed %||% 2026,
      event_legend_position = input$event_legend_position %||% "right",
      event_legend_title = input$event_legend_title %||% "",
      event_legend_x_ratio = input$event_legend_x_ratio %||% 0.72,
      event_legend_y_ratio = input$event_legend_y_ratio %||% 0.03,
      event_legend_width_ratio = input$event_legend_width_ratio %||% 0.26,
      event_legend_height_ratio = input$event_legend_height_ratio %||% 0.28,
      base_font_size = input$base_font_size %||% 12,
      base_family = input$base_family %||% "sans",
      cjk_family = input$cjk_family %||% "Noto Sans SC",
      event_mappings = collect_swimmer_event_mappings(df_current),
      lane_manual_colors = capture_lane_manual_color_values(df_current),
      track_color_values = capture_track_color_values(df_current, selected_tracks, track_mode_map)
    )
  }

  refresh_event_mapping_choices <- function(
    all_vars,
    time_vars,
    event_time_candidates,
    event_type_candidates,
    event_label_candidates,
    prefer_state = FALSE,
    mapping_state_override = NULL,
    row_count_override = NULL
  ) {
    n_maps <- if (!is.null(row_count_override)) row_count_override else event_map_count()
    for (i in seq_len(n_maps)) {
      id_time <- paste0("event_time_", i)
      id_type <- paste0("event_type_", i)
      id_label <- paste0("event_label_", i)
      current_time <- if (isTRUE(prefer_state)) NULL else isolate(input[[id_time]])
      current_type <- if (isTRUE(prefer_state)) NULL else isolate(input[[id_type]])
      current_label <- if (isTRUE(prefer_state)) NULL else isolate(input[[id_label]])
      state_time <- if (!is.null(mapping_state_override) && length(mapping_state_override) >= i) mapping_state_override[[i]]$event_time %||% NULL else state_get(i, "event_time", NULL)
      state_type <- if (!is.null(mapping_state_override) && length(mapping_state_override) >= i) mapping_state_override[[i]]$event_type %||% NULL else state_get(i, "event_type", NULL)
      state_label <- if (!is.null(mapping_state_override) && length(mapping_state_override) >= i) mapping_state_override[[i]]$event_label %||% NULL else state_get(i, "event_label", NULL)
      if (is.null(current_time)) current_time <- state_time
      if (is.null(current_type)) current_type <- state_type
      if (is.null(current_label)) current_label <- state_label
      current_time <- graphics_remember_choice(current_time, state_time, time_vars, pick_first(event_time_candidates, time_vars) %||% "", allow_empty = TRUE)
      current_type <- graphics_remember_choice(current_type, state_type, all_vars, pick_first(event_type_candidates, all_vars) %||% "", allow_empty = TRUE)
      current_label <- graphics_remember_choice(current_label, state_label, all_vars, pick_first(event_label_candidates, all_vars) %||% "", allow_empty = TRUE)
      updateSelectizeInput(session, id_time, choices = c("无" = "", time_vars), selected = current_time %||% "", server = TRUE)
      updateSelectizeInput(session, id_type, choices = c("无" = "", all_vars), selected = current_type %||% "", server = TRUE)
      updateSelectizeInput(session, id_label, choices = c("无" = "", all_vars), selected = current_label %||% "", server = TRUE)
    }
  }

  restore_swimmer_mapping_inputs <- function(force = FALSE, df_current = NULL, state_snapshot = NULL) {
    if (is.null(df_current)) {
      df_current <- data()
    }
    shiny::req(df_current)
    if (!isTRUE(force)) {
      snapshot_event_ui_state()
    }
    all_vars <- names(df_current)
    time_vars <- get_time_vars(df_current)
    current_signature <- paste(all_vars, collapse = "|")
    if (!isTRUE(force) && !is.null(graphics_state$columns_signature) && identical(graphics_state$columns_signature, current_signature)) {
      return(invisible(FALSE))
    }
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
    snapshot_get <- function(name, fallback = NULL) {
      if (!is.null(state_snapshot) && !is.null(state_snapshot[[name]])) {
        return(state_snapshot[[name]])
      }
      fallback
    }

    state_subject <- if (isTRUE(force)) snapshot_get("subject_id", NULL) else snapshot_get("subject_id", graphics_state$subject_id)
    current_subject <- if (isTRUE(force)) state_subject else isolate(input$subject_id)
    selected_subject <- graphics_remember_choice(current_subject, state_subject, all_vars, pick_first(subject_candidates, all_vars))

    state_lane_mode <- if (isTRUE(force)) snapshot_get("lane_time_mode", NULL) else snapshot_get("lane_time_mode", graphics_state$lane_time_mode)
    selected_lane_mode <- if (isTRUE(force)) state_lane_mode else isolate(input$lane_time_mode)
    if (is.null(selected_lane_mode) || !(selected_lane_mode %in% c("start_end", "duration"))) {
      selected_lane_mode <- state_lane_mode %||% "start_end"
    }

    state_start <- if (isTRUE(force)) snapshot_get("start_time", NULL) else snapshot_get("start_time", graphics_state$start_time)
    selected_start <- if (isTRUE(force)) state_start else isolate(input$start_time)
    if (is.null(selected_start) || !nzchar(selected_start) || !(selected_start %in% time_vars)) {
      selected_start <- state_start
      if (is.null(selected_start) || !(selected_start %in% time_vars)) selected_start <- pick_first(start_candidates, time_vars)
      if (is.null(selected_start) && length(time_vars) > 0) selected_start <- time_vars[[1]]
    }

    state_end <- if (isTRUE(force)) snapshot_get("end_time", NULL) else snapshot_get("end_time", graphics_state$end_time)
    selected_end <- if (isTRUE(force)) state_end else isolate(input$end_time)
    if (is.null(selected_end) || !nzchar(selected_end) || !(selected_end %in% time_vars)) {
      selected_end <- state_end
      if (is.null(selected_end) || !(selected_end %in% time_vars)) selected_end <- pick_first(end_candidates, time_vars)
      if (is.null(selected_end) && length(time_vars) > 1) selected_end <- time_vars[[2]]
    }

    state_duration <- if (isTRUE(force)) snapshot_get("duration_var", NULL) else snapshot_get("duration_var", graphics_state$duration_var)
    selected_duration <- if (isTRUE(force)) state_duration else isolate(input$duration_var)
    if (is.null(selected_duration) || !nzchar(selected_duration) || !(selected_duration %in% time_vars)) {
      selected_duration <- state_duration
      if (is.null(selected_duration) || !(selected_duration %in% time_vars)) {
        selected_duration <- pick_first(duration_candidates, time_vars)
      }
    }
    if (!nzchar(selected_duration %||% "") && selected_lane_mode == "duration") {
      selected_lane_mode <- "start_end"
    }
    current_lane_time_mode <- if (isTRUE(force)) state_lane_mode else input$lane_time_mode
    if ((is.null(current_lane_time_mode) || !nzchar(current_lane_time_mode %||% "")) && nzchar(selected_duration %||% "")) {
      selected_lane_mode <- "duration"
    }

    state_color <- if (isTRUE(force)) snapshot_get("lane_color_by", NULL) else snapshot_get("lane_color_by", graphics_state$lane_color_by)
    current_color <- if (isTRUE(force)) state_color else isolate(input$lane_color_by)
    selected_color <- graphics_remember_choice(current_color, state_color, all_vars, pick_first(color_candidates, setdiff(all_vars, c(selected_subject, selected_start, selected_end))) %||% "", allow_empty = TRUE)
    state_ongoing <- if (isTRUE(force)) snapshot_get("ongoing_var", NULL) else snapshot_get("ongoing_var", graphics_state$ongoing_var)
    current_ongoing <- if (isTRUE(force)) state_ongoing else isolate(input$ongoing_var)
    selected_ongoing <- graphics_remember_choice(current_ongoing, state_ongoing, all_vars, pick_first(ongoing_candidates, all_vars) %||% "", allow_empty = TRUE)

    state_tracks <- if (isTRUE(force)) snapshot_get("tracks", character(0)) else snapshot_get("tracks", graphics_state$tracks)
    selected_tracks <- if (isTRUE(force)) state_tracks else isolate(input$tracks)
    if (is.null(selected_tracks) || length(selected_tracks) == 0) selected_tracks <- state_tracks
    selected_tracks <- intersect(selected_tracks, all_vars)

    updateSelectizeInput(session, "subject_id", choices = all_vars, selected = selected_subject, server = TRUE)
    updateSelectInput(session, "lane_time_mode", selected = selected_lane_mode)
    updateSelectizeInput(session, "start_time", choices = time_vars, selected = selected_start, server = TRUE)
    updateSelectizeInput(session, "end_time", choices = time_vars, selected = selected_end, server = TRUE)
    updateSelectizeInput(session, "duration_var", choices = time_vars, selected = selected_duration, server = TRUE)
    updateSelectizeInput(session, "lane_color_by", choices = c("无" = "", all_vars), selected = selected_color, server = TRUE)
    updateSelectizeInput(session, "ongoing_var", choices = c("无" = "", all_vars), selected = selected_ongoing, server = TRUE)
    updateSelectizeInput(session, "tracks", choices = all_vars, selected = selected_tracks, server = TRUE)
    refresh_event_mapping_choices(
      all_vars,
      time_vars,
      event_time_candidates,
      event_type_candidates,
      event_label_candidates,
      prefer_state = isTRUE(force),
      mapping_state_override = if (isTRUE(force)) state_snapshot$event_mappings %||% list() else NULL,
      row_count_override = if (isTRUE(force)) length(state_snapshot$event_mappings %||% list()) else NULL
    )
    invisible(TRUE)
  }

  observeEvent(data(), {
    restore_swimmer_mapping_inputs(force = FALSE)
  }, ignoreInit = FALSE)

  observeEvent(input$add_event_map, {
    snapshot_event_ui_state()
    df_now <- isolate(data())
    if (!is.null(df_now)) {
      all_vars <- names(df_now)
      time_vars <- get_time_vars(df_now)
      event_time_candidates <- c("EVENT_TIME", "EVT_TIME", "ADT", "AVISITN", "event_time")
      event_type_candidates <- c("EVENT", "EVENT_TYPE", "BOR", "STATUS", "RESPONSE", "event_type")
      event_label_candidates <- c("EVENT_LABEL", "LABEL", "EVENT_TEXT", "AVALC", "event_label")
      st <- event_ui_state()
      st[[length(st) + 1]] <- list(
        event_time = "",
        event_type = "",
        event_label = "",
        event_legend_title = "",
        event_grp_color_mode = "random_unique",
        event_grp_col = NULL,
        event_grp_shape = NULL,
        event_grp_symbol_mode = "random_unique"
      )
      event_ui_state(st)
    }
    event_map_count(event_map_count() + 1)
  })

  observeEvent(input$remove_event_map, {
    snapshot_event_ui_state()
    event_map_count(max(1, event_map_count() - 1))
    st <- event_ui_state()
    n_maps <- max(1, event_map_count())
    if (length(st) > n_maps) event_ui_state(st[seq_len(n_maps)])
  })

  observeEvent(event_map_count(), {
    st <- event_ui_state()
    n_maps <- event_map_count()
    if (length(st) > n_maps) event_ui_state(st[seq_len(n_maps)])
  }, ignoreInit = TRUE)

  output$event_mapping_ui <- renderUI({
    n_maps <- event_map_count()
    df_ui <- data()
    all_vars_ui <- if (is.null(df_ui)) character(0) else names(df_ui)
    time_vars_ui <- if (is.null(df_ui)) character(0) else get_time_vars(df_ui)
    event_time_candidates <- c("EVENT_TIME", "EVT_TIME", "ADT", "AVISITN", "event_time")
    event_type_candidates <- c("EVENT", "EVENT_TYPE", "BOR", "STATUS", "RESPONSE", "event_type")
    event_label_candidates <- c("EVENT_LABEL", "LABEL", "EVENT_TEXT", "AVALC", "event_label")
    tagList(
      lapply(seq_len(n_maps), function(i) {
        prefer_state <- isTRUE(restoring_event_controls())
        state_time <- state_get(i, "event_time", NULL)
        state_type <- state_get(i, "event_type", NULL)
        state_label <- state_get(i, "event_label", NULL)
        selected_time <- if (prefer_state) state_time %||% isolate(input[[paste0("event_time_", i)]]) else isolate(input[[paste0("event_time_", i)]]) %||% state_time
        selected_type <- if (prefer_state) state_type %||% isolate(input[[paste0("event_type_", i)]]) else isolate(input[[paste0("event_type_", i)]]) %||% state_type
        selected_label <- if (prefer_state) state_label %||% isolate(input[[paste0("event_label_", i)]]) else isolate(input[[paste0("event_label_", i)]]) %||% state_label
        if (is.null(selected_time)) selected_time <- ""
        if (is.null(selected_type)) selected_type <- ""
        if (is.null(selected_label)) selected_label <- ""
        event_row_fields <- graphics_build_overlay_point_layer_fields_spec(
          row_index = i,
          time_choices = time_vars_ui,
          type_choices = all_vars_ui,
          label_choices = all_vars_ui,
          selected_time = selected_time,
          selected_type = selected_type,
          selected_label = selected_label,
          selected_legend_title = state_get(i, "event_legend_title", "")
        )
        graphics_dynamic_mapping_row_ui(
          title = paste0("事件变量组 ", i),
          body = graphics_dynamic_mapping_fields_ui(session$ns, event_row_fields)
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
    if (!identical(input$lane_color_mode %||% "palette", "manual_each")) {
      return(NULL)
    }
    lane_color_source <- graphics_resolve_mapping_var(input$lane_color_by, input$subject_id, names(data()), enable_fallback = TRUE)
    if (is.null(lane_color_source) || !nzchar(lane_color_source) || !(lane_color_source %in% names(data()))) {
      return(helpText("请选择受试者ID或泳道颜色分组后再设置分别指定颜色。"))
    }
    levels <- unique(as.character(data()[[lane_color_source]]))
    levels <- levels[!is.na(levels) & nzchar(levels)]
    levels <- head(levels, 12)
    if (length(levels) == 0) return(helpText("当前分组变量没有可用水平。"))
    defaults <- palette_values(length(levels), input$lane_palette %||% "hue")
    tagList(
      h5(if (!is.null(input$lane_color_by) && nzchar(input$lane_color_by)) "泳道分组颜色" else "受试者泳道颜色"),
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
    prefer_state <- isTRUE(restoring_event_controls())
    tagList(
      h5("事件组样式(每组独立图例)"),
      lapply(seq_len(n_maps), function(i) {
        state_legend_title <- state_get(i, "event_legend_title", "")
        legend_title_raw <- if (prefer_state) state_legend_title %||% input[[paste0("event_legend_title_", i)]] else input[[paste0("event_legend_title_", i)]] %||% state_legend_title
        legend_title <- trimws(legend_title_raw %||% "")
        if (!nzchar(legend_title)) legend_title <- paste0("事件组", i)
        color_default <- if (lock_style) state_get(i, "event_grp_col", defaults[[i]]) else defaults[[i]]
        color_mode_default <- state_get(i, "event_grp_color_mode", "random_unique")
        symbol_mode_default <- state_get(i, "event_grp_symbol_mode", "random_unique")
        shape_default <- state_get(i, "event_grp_shape", default_shapes[[i]])
        state_event_type <- state_get(i, "event_type", "")
        event_type_var <- if (prefer_state) state_event_type %||% input[[paste0("event_type_", i)]] else input[[paste0("event_type_", i)]] %||% state_event_type
        event_levels <- if (!is.null(event_type_var) && nzchar(event_type_var) && event_type_var %in% names(data())) {
          vals <- unique(as.character(data()[[event_type_var]]))
          vals[!is.na(vals) & nzchar(vals)]
        } else {
          character(0)
        }
        color_manual_each_ui <- if (length(event_levels) > 0) {
          graphics_group_style_mapping_panel_ui(
            title = paste0(legend_title, " 颜色分别指定"),
            body = graphics_group_symbol_controls_ui(
              session = session,
              levels = event_levels,
              color_input_prefix = paste0("event_grp_col_each_", i, "_"),
              default_colors = rep(color_default, length(event_levels)),
              title = paste0(legend_title, " 颜色分别指定"),
              color_label_suffix = "颜色",
              show_symbol = FALSE,
              show_color = TRUE
            )
          )
        } else {
          NULL
        }
        symbol_manual_each_ui <- if (length(event_levels) > 0) {
          graphics_group_style_mapping_panel_ui(
            title = paste0(legend_title, " 符号分别指定"),
            body = graphics_group_symbol_controls_ui(
              session = session,
              levels = event_levels,
              symbol_input_prefix = paste0("event_grp_shape_each_", i, "_"),
              symbol_choices = shape_choice_values,
              default_symbols = as.numeric(rep(unname(shape_choice_values), length.out = length(event_levels))),
              title = paste0(legend_title, " 符号分别指定"),
              show_symbol = TRUE,
              show_color = FALSE
            )
          )
        } else {
          NULL
        }
        tagList(
          fluidRow(
            column(
              6,
              graphics_group_style_rule_ui(
                session = session,
                mode_input_id = paste0("event_grp_color_mode_", i),
                mode_label = paste0(legend_title, " 颜色分配"),
                selected_mode = color_mode_default,
                single_input_id = paste0("event_grp_col_", i),
                single_input_label = paste0(legend_title, " 指定颜色"),
                single_input_type = "color",
                single_value = color_default,
                manual_each_ui = color_manual_each_ui
              )
            ),
            column(
              6,
              graphics_group_style_rule_ui(
                session = session,
                mode_input_id = paste0("event_grp_symbol_mode_", i),
                mode_label = paste0(legend_title, " 符号分配"),
                selected_mode = symbol_mode_default,
                single_input_id = paste0("event_grp_shape_", i),
                single_input_label = paste0(legend_title, " 指定符号"),
                single_input_type = "select",
                single_value = shape_default,
                single_choices = shape_choice_values,
                manual_each_ui = symbol_manual_each_ui
              )
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
    defaults <- setNames(palette_values(length(track_keys), "Set3"), track_keys)
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

  outputOptions(output, "event_mapping_ui", suspendWhenHidden = FALSE)
  outputOptions(output, "event_group_style_controls", suspendWhenHidden = FALSE)
  outputOptions(output, "lane_color_controls", suspendWhenHidden = FALSE)
  outputOptions(output, "track_mode_controls", suspendWhenHidden = FALSE)
  outputOptions(output, "track_color_controls", suspendWhenHidden = FALSE)

  final_plot <- reactiveVal(NULL)
  main_plot_obj <- reactiveVal(NULL)
  lane_data <- reactiveVal(NULL)
  event_data <- reactiveVal(NULL)
  track_data <- reactiveVal(NULL)
  size_config <- reactive({
    graphics_collect_size_config(input)
  })

  static_render_height <- reactive({
    cfg <- size_config()
    base_h <- as.integer(cfg$static_height)
    td <- track_data()
    params <- committed_params()
    show_tracks <- if (is.list(params) && !is.null(params$show_tracks)) isTRUE(params$show_tracks) else isTRUE(input$show_tracks)
    compact_mode <- if (is.list(params) && !is.null(params$track_compact_mode)) isTRUE(params$track_compact_mode) else isTRUE(input$track_compact_mode)
    track_row_spacing <- if (is.list(params) && !is.null(params$track_row_spacing)) params$track_row_spacing else (input$track_row_spacing %||% 0)
    track_tile_height <- if (is.list(params) && !is.null(params$track_tile_height)) params$track_tile_height else (input$track_tile_height %||% 0.65)
    if (is.null(td) || !isTRUE(show_tracks)) {
      return(base_h)
    }
    track_n <- length(unique(as.character(td$.track_name)))
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

  swimmer_time_slider_source <- reactive({
    df <- data()
    if (is.null(df) || nrow(df) == 0) {
      return(NULL)
    }
    unit_divisor <- switch(input$x_unit %||% "day", day = 1, week = 7, month = 30.4375, year = 365.25, 1)
    use_duration_mode <- identical(input$lane_time_mode %||% "start_end", "duration")

    if (use_duration_mode) {
      if (!nzchar(input$duration_var %||% "")) return(NULL)
      if (!(input$duration_var %in% names(df))) return(NULL)
      duration_vec <- df[[input$duration_var]]
      if (inherits(duration_vec, "Date") || inherits(duration_vec, "POSIXt")) {
        duration_vec <- as.Date(duration_vec)
        duration_vec <- as.numeric(difftime(duration_vec, min(duration_vec, na.rm = TRUE), units = "days"))
      } else {
        duration_vec <- suppressWarnings(as.numeric(duration_vec))
      }
      duration_vec <- duration_vec[is.finite(duration_vec)]
      if (length(duration_vec) == 0) return(NULL)
      return(data.frame(.slider_end = duration_vec / unit_divisor))
    }

    if (!nzchar(input$start_time %||% "") || !nzchar(input$end_time %||% "")) {
      return(NULL)
    }
    if (!(input$start_time %in% names(df)) || !(input$end_time %in% names(df))) return(NULL)
    start_vec <- df[[input$start_time]]
    end_vec <- df[[input$end_time]]
    if ((inherits(start_vec, "Date") || inherits(start_vec, "POSIXt")) &&
        (inherits(end_vec, "Date") || inherits(end_vec, "POSIXt"))) {
      start_vec <- as.Date(start_vec)
      end_vec <- as.Date(end_vec)
      slider_end <- as.numeric(difftime(end_vec, start_vec, units = "days"))
      swap_idx <- which(is.finite(slider_end) & slider_end < 0)
      if (length(swap_idx) > 0) slider_end[swap_idx] <- abs(slider_end[swap_idx])
    } else {
      slider_end <- suppressWarnings(as.numeric(end_vec))
    }
    slider_end <- slider_end[is.finite(slider_end)]
    if (length(slider_end) == 0) return(NULL)
    data.frame(.slider_end = slider_end / unit_divisor)
  })

  output$time_range_slider <- graphics_render_time_range_slider(
    ns,
    ".slider_end",
    swimmer_time_slider_source,
    selected_range = reactive(graphics_state$time_range %||% input$time_range)
  )

  observeEvent(input$time_range, {
    if (!is.null(input$time_range) && length(input$time_range) == 2) {
      graphics_state$time_range <- input$time_range
    }
  }, ignoreInit = TRUE)

  observeEvent(input$render_plot, {
    req(data(), input$subject_id)

    tryCatch({
      df <- data()
      params <- build_swimmer_committed_params(df)
      lane_color_source <- graphics_resolve_mapping_var(
        params$lane_color_by,
        params$subject_id,
        names(df),
        enable_fallback = identical(params$lane_color_mode, "manual_each")
      )
      lane_has_group <- !is.null(lane_color_source) && nzchar(lane_color_source) && lane_color_source %in% names(df)
      use_duration_mode <- identical(params$lane_time_mode, "duration")
      if (use_duration_mode) {
        req(params$duration_var)
      } else {
        req(params$start_time, params$end_time)
      }
      unit_divisor <- switch(params$x_unit, day = 1, week = 7, month = 30.4375, year = 365.25, 1)
      unit_label <- switch(params$x_unit, day = "天", week = "周", month = "月", year = "年", "天")
      time_range <- params$time_range

      selected_tracks <- params$tracks %||% character(0)
      selected_tracks <- selected_tracks[selected_tracks %in% names(df)]
      track_label_map <- setNames(make.unique(vapply(selected_tracks, function(tr) get_var_label(df, tr), character(1))), selected_tracks)

      lane_time_cols <- if (use_duration_mode) c(params$duration_var) else c(params$start_time, params$end_time)
      lane_cols <- unique(c(params$subject_id, lane_time_cols, lane_color_source, params$ongoing_var, selected_tracks))
      lane_cols <- lane_cols[nzchar(lane_cols)]
      lane_cols <- lane_cols[lane_cols %in% names(df)]
      lane_df <- df[, lane_cols, drop = FALSE]

      names(lane_df)[names(lane_df) == params$subject_id] <- ".subject_id"
      if (use_duration_mode) {
        names(lane_df)[names(lane_df) == params$duration_var] <- ".duration_input"
      } else {
        names(lane_df)[names(lane_df) == params$start_time] <- ".start"
        names(lane_df)[names(lane_df) == params$end_time] <- ".end"
      }
      if (!is.null(lane_color_source) && nzchar(lane_color_source) && lane_color_source %in% names(df)) {
        names(lane_df)[names(lane_df) == lane_color_source] <- ".lane_group"
      } else {
        lane_df$.lane_group <- "全部受试者"
      }
      if (nzchar(params$ongoing_var %||% "") && params$ongoing_var %in% names(df)) {
        names(lane_df)[names(lane_df) == params$ongoing_var] <- ".ongoing"
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
        duration_is_date <- inherits(df[[params$duration_var]], "Date") || inherits(df[[params$duration_var]], "POSIXt")
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
        start_is_date <- inherits(df[[params$start_time]], "Date") || inherits(df[[params$start_time]], "POSIXt")
        end_is_date <- inherits(df[[params$end_time]], "Date") || inherits(df[[params$end_time]], "POSIXt")
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

      if (params$sort_mode == "duration_desc") lane_df <- lane_df %>% arrange(desc(.duration), desc(.end))
      if (params$sort_mode == "duration_asc") lane_df <- lane_df %>% arrange(.duration, .end)
      if (params$sort_mode == "end_desc") lane_df <- lane_df %>% arrange(desc(.end), desc(.duration))
      if (params$sort_mode == "end_asc") lane_df <- lane_df %>% arrange(.end, .duration)
      if (params$sort_mode == "subject") lane_df <- lane_df %>% arrange(.subject_id)

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

      event_list <- lapply(seq_along(params$event_mappings), function(i) {
        mapping <- params$event_mappings[[i]]
        event_time_var <- mapping$event_time %||% ""
        event_type_var <- mapping$event_type %||% ""
        event_label_var <- mapping$event_label %||% ""
        if (!nzchar(event_time_var) || !nzchar(event_type_var) || !(event_time_var %in% names(df)) || !(event_type_var %in% names(df))) {
          return(NULL)
        }
        event_cols <- unique(c(params$subject_id, event_time_var, event_type_var, event_label_var))
        event_cols <- event_cols[nzchar(event_cols)]
        event_cols <- event_cols[event_cols %in% names(df)]
        tmp_df <- df[, event_cols, drop = FALSE]
        names(tmp_df)[names(tmp_df) == params$subject_id] <- ".subject_id"
        names(tmp_df)[names(tmp_df) == event_time_var] <- ".event_time"
        names(tmp_df)[names(tmp_df) == event_type_var] <- ".event_type"
        if (nzchar(event_label_var) && event_label_var %in% names(df)) {
          names(tmp_df)[names(tmp_df) == event_label_var] <- ".event_label"
        } else {
          tmp_df$.event_label <- ""
        }
        event_type_label <- get_var_label(df, event_type_var) %||% event_type_var
        event_source_title <- trimws(mapping$event_legend_title %||% "")
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
            .track_value = format_missing_vec(.track_value, params = params),
            .track_name = factor(.track_name, levels = rev(unname(track_label_map[selected_tracks])))
          )
      } else {
        track_df <- NULL
      }

      lane_levels <- unique(lane_df$.lane_group)
      lane_colors <- setNames(palette_values(length(lane_levels), params$lane_palette %||% "hue"), lane_levels)
      if (identical(params$lane_color_mode, "manual_each")) {
        for (lv in lane_levels) {
          lane_color <- params$lane_manual_colors[[lv]]
          if (!is.null(lane_color) && nzchar(lane_color %||% "")) lane_colors[[lv]] <- lane_color
        }
      }
      lane_single_color <- lane_colors[[1]] %||% "#4E79A7"
      has_event_data <- !is.null(event_df) && nrow(event_df) > 0
      auto_caption_lines <- character(0)
      font_spec <- graphics_resolve_font_spec(
        base_family = params$base_family %||% "sans",
        cjk_family = params$cjk_family %||% "Noto Sans SC"
      )
      plot_family <- font_spec$unified
      if (isTRUE(params$auto_mapping_caption) && isTRUE(lane_has_group) && identical(params$lane_color_mode, "manual_each")) {
        auto_caption_lines <- c(auto_caption_lines, graphics_mapping_caption_line(get_var_label(data(), lane_color_source), "泳道颜色"))
      }

      if (isTRUE(lane_has_group)) {
        if (isTRUE(has_event_data)) {
          lane_df$.lane_color <- unname(lane_colors[as.character(lane_df$.lane_group)])
          p_main <- ggplot(lane_df, aes(y = .subject_factor, text = .tooltip_lane)) +
            geom_segment(
              aes(x = .start_plot, xend = .end_plot, yend = .subject_factor, color = .lane_color),
              linewidth = params$lane_size,
              alpha = params$lane_alpha,
              lineend = "round"
            ) +
            scale_color_identity() +
            labs(
              title = ifelse(nzchar(params$plot_title %||% ""), params$plot_title, "泳道图"),
              subtitle = params$plot_subtitle %||% "",
              x = ifelse(nzchar(params$plot_xlab %||% ""), params$plot_xlab, "时间"),
              y = ifelse(nzchar(params$plot_ylab %||% ""), params$plot_ylab, "受试者")
            ) +
            theme_minimal(base_size = params$base_font_size, base_family = plot_family) +
            theme(
              panel.grid.major.y = element_blank(),
              axis.text.y = if (isTRUE(params$show_subject_labels)) element_text() else element_blank(),
              axis.ticks.y = if (isTRUE(params$show_subject_labels)) element_line() else element_blank()
            )
        } else {
          p_main <- ggplot(lane_df, aes(y = .subject_factor, text = .tooltip_lane)) +
            geom_segment(
              aes(x = .start_plot, xend = .end_plot, yend = .subject_factor, color = .lane_group),
              linewidth = params$lane_size,
              alpha = params$lane_alpha,
              lineend = "round"
            ) +
            scale_color_manual(values = lane_colors) +
            labs(
              title = ifelse(nzchar(params$plot_title %||% ""), params$plot_title, "泳道图"),
              subtitle = params$plot_subtitle %||% "",
              x = ifelse(nzchar(params$plot_xlab %||% ""), params$plot_xlab, "时间"),
              y = ifelse(nzchar(params$plot_ylab %||% ""), params$plot_ylab, "受试者"),
              color = graphics_resolve_legend_title(params$lane_legend_title, get_var_label(data(), lane_color_source %||% params$subject_id))
            ) +
            theme_minimal(base_size = params$base_font_size, base_family = plot_family) +
            theme(
              panel.grid.major.y = element_blank(),
              axis.text.y = if (isTRUE(params$show_subject_labels)) element_text() else element_blank(),
              axis.ticks.y = if (isTRUE(params$show_subject_labels)) element_line() else element_blank()
            )
        }
      } else {
        p_main <- ggplot(lane_df, aes(y = .subject_factor, text = .tooltip_lane)) +
          geom_segment(
            aes(x = .start_plot, xend = .end_plot, yend = .subject_factor),
            linewidth = params$lane_size,
            alpha = params$lane_alpha,
            color = lane_single_color,
            lineend = "round"
          ) +
          labs(
            title = ifelse(nzchar(params$plot_title %||% ""), params$plot_title, "泳道图"),
            subtitle = params$plot_subtitle %||% "",
            x = ifelse(nzchar(params$plot_xlab %||% ""), params$plot_xlab, "时间"),
            y = ifelse(nzchar(params$plot_ylab %||% ""), params$plot_ylab, "受试者")
          ) +
          theme_minimal(base_size = params$base_font_size, base_family = plot_family) +
          theme(
            panel.grid.major.y = element_blank(),
            axis.text.y = if (isTRUE(params$show_subject_labels)) element_text() else element_blank(),
            axis.ticks.y = if (isTRUE(params$show_subject_labels)) element_line() else element_blank()
          ) +
          guides(color = "none")
      }

      p_main <- graphics_apply_legend_theme(
        p_main,
        show_legend = isTRUE(params$show_legend) && !isTRUE(has_event_data) && isTRUE(lane_has_group),
        position = params$main_legend_position %||% "right"
      )

      p_main <- graphics_apply_x_break_step(p_main, c(lane_df$.start_plot, lane_df$.end_plot), params$x_break_step)

      event_legend_df <- NULL
      if (!is.null(event_df) && nrow(event_df) > 0) {
        key_info <- event_df %>%
          group_by(.event_group_key, .event_group_index, .event_source, .event_type) %>%
          summarise(
            .groups = "drop"
          ) %>%
          arrange(.event_group_index, .event_type)
        key_info <- key_info %>%
          mutate(
            .event_style_key = paste0("S", seq_len(dplyr::n())),
            .event_style_label = .event_type
          )
        event_keys <- key_info$.event_style_key
        event_label_map <- setNames(key_info$.event_style_label, key_info$.event_style_key)
        color_seed_val <- suppressWarnings(as.integer(params$event_symbol_seed %||% NA))
        source_default_colors <- palette_values(length(event_keys), params$event_palette %||% "hue")
        if (!is.na(color_seed_val) && is.finite(color_seed_val) && color_seed_val > 0) {
          set.seed(color_seed_val + 17L)
          source_default_colors <- sample(source_default_colors, length(source_default_colors))
        }
        source_default_colors <- setNames(source_default_colors, event_keys)
        event_colors_by_key <- source_default_colors
        for (k in seq_along(event_keys)) {
          idx <- key_info$.event_group_index[[k]]
          mapping <- params$event_mappings[[idx]]
          color_mode_i <- mapping$event_grp_color_mode %||% "random_unique"
          if (identical(color_mode_i, "single")) {
            if (!is.null(mapping$event_grp_col) && nzchar(mapping$event_grp_col %||% "")) {
              event_colors_by_key[[event_keys[[k]]]] <- mapping$event_grp_col
            }
          } else if (identical(color_mode_i, "manual_each")) {
            level_color <- mapping$event_grp_col_each[[key_info$.event_type[[k]]]]
            if (!is.null(level_color) && nzchar(level_color %||% "")) event_colors_by_key[[event_keys[[k]]]] <- level_color
          }
        }
        shape_pool <- unique(as.numeric(unname(shape_choice_values)))
        seed_val <- suppressWarnings(as.integer(params$event_symbol_seed %||% NA))
        if (!is.na(seed_val) && is.finite(seed_val) && seed_val > 0) {
          set.seed(seed_val)
        }
        shape_pool_ordered <- sample(shape_pool, length(shape_pool))
        event_shapes_by_key <- setNames(rep(NA_real_, length(event_keys)), event_keys)
        used_shapes <- numeric(0)
        for (k in seq_along(event_keys)) {
          idx <- key_info$.event_group_index[[k]]
          mapping <- params$event_mappings[[idx]]
          mode_i <- mapping$event_grp_symbol_mode %||% "random_unique"
          if (identical(mode_i, "single")) {
            chosen <- suppressWarnings(as.numeric(mapping$event_grp_shape))
            if (is.na(chosen)) chosen <- shape_pool_ordered[[((k - 1) %% length(shape_pool_ordered)) + 1]]
            event_shapes_by_key[[event_keys[[k]]]] <- chosen
            used_shapes <- c(used_shapes, chosen)
          } else if (identical(mode_i, "manual_each")) {
            chosen <- suppressWarnings(as.numeric(mapping$event_grp_shape_each[[key_info$.event_type[[k]]]]))
            if (is.na(chosen)) chosen <- shape_pool_ordered[[((k - 1) %% length(shape_pool_ordered)) + 1]]
            event_shapes_by_key[[event_keys[[k]]]] <- chosen
            used_shapes <- c(used_shapes, chosen)
          }
        }
        if (isTRUE(params$auto_mapping_caption)) {
          for (idx in unique(key_info$.event_group_index)) {
            mapping <- params$event_mappings[[idx]]
            event_type_var_i <- mapping$event_type %||% ""
            if (!is.null(event_type_var_i) && nzchar(event_type_var_i) && event_type_var_i %in% names(data())) {
              if (identical(mapping$event_grp_color_mode %||% "random_unique", "manual_each")) {
                auto_caption_lines <- c(auto_caption_lines, graphics_mapping_caption_line(get_var_label(data(), event_type_var_i), "事件颜色"))
              }
              if (identical(mapping$event_grp_symbol_mode %||% "random_unique", "manual_each")) {
                auto_caption_lines <- c(auto_caption_lines, graphics_mapping_caption_line(get_var_label(data(), event_type_var_i), "事件符号"))
              }
            }
          }
        }
        for (k in seq_along(event_keys)) {
          if (!is.na(event_shapes_by_key[[event_keys[[k]]]])) next
          available <- shape_pool_ordered[shape_pool_ordered %in% setdiff(shape_pool_ordered, used_shapes)]
          chosen <- if (length(available) > 0) available[[1]] else shape_pool_ordered[[((k - 1) %% length(shape_pool_ordered)) + 1]]
          event_shapes_by_key[[event_keys[[k]]]] <- chosen
          used_shapes <- c(used_shapes, chosen)
        }

        event_df <- event_df %>%
          left_join(
            key_info %>% select(.event_group_key, .event_group_index, .event_source, .event_type, .event_style_key),
            by = c(".event_group_key", ".event_group_index", ".event_source", ".event_type")
          )

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
            aes(x = .event_time_plot, y = .subject_factor, shape = .event_style_key, color = .event_style_key, text = .tooltip_event),
            size = params$event_size,
            stroke = 0.4
          ) +
          scale_shape_manual(values = event_shapes_by_key, breaks = event_keys, labels = unname(event_label_map[event_keys])) +
          scale_color_manual(values = event_colors_by_key, breaks = event_keys, labels = unname(event_label_map[event_keys]))

        if (isTRUE(params$show_event_labels)) {
          p_main <- p_main +
            geom_text(
              data = event_df %>% filter(nzchar(.event_label)),
              aes(x = .event_time_plot, y = .subject_factor, label = .event_label),
              nudge_y = 0.3,
              size = max(2.8, params$base_font_size * 0.22),
              check_overlap = TRUE,
              family = plot_family
            )
        }

        p_main <- p_main + guides(shape = "none", color = "none")
        event_legend_df <- data.frame(
          .key = event_keys,
          .group_index = as.numeric(unname(key_info$.event_group_index[match(event_keys, key_info$.event_style_key)])),
          .group = unname(key_info$.event_source[match(event_keys, key_info$.event_style_key)]),
          .label = unname(event_label_map[event_keys]),
          .color = unname(event_colors_by_key[event_keys]),
          .shape = as.numeric(unname(event_shapes_by_key[event_keys])),
          stringsAsFactors = FALSE
        )
        event_df$.event_shape_assigned <- as.numeric(unname(event_shapes_by_key[event_df$.event_style_key]))
        event_df$.event_color_assigned <- unname(event_colors_by_key[event_df$.event_style_key])
      }

      if (isTRUE(params$show_ongoing_arrow)) {
        ongoing_df <- lane_df %>% filter(.ongoing)
        if (nrow(ongoing_df) > 0) {
          if (isTRUE(lane_has_group)) {
            p_main <- p_main +
              geom_segment(
                data = ongoing_df,
                aes(x = .end_plot - 0.001, xend = .end_plot + max(.duration_plot, na.rm = TRUE) * 0.03, y = .subject_factor, yend = .subject_factor, color = .lane_group),
                linewidth = params$lane_size * 0.45,
                arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
                inherit.aes = FALSE
              )
          } else {
            p_main <- p_main +
              geom_segment(
                data = ongoing_df,
                aes(x = .end_plot - 0.001, xend = .end_plot + max(.duration_plot, na.rm = TRUE) * 0.03, y = .subject_factor, yend = .subject_factor),
                linewidth = params$lane_size * 0.45,
                color = lane_single_color,
                arrow = grid::arrow(length = grid::unit(0.12, "inches"), type = "closed"),
                inherit.aes = FALSE
              )
          }
        }
      }

      if (!isTRUE(params$show_grid_lines)) {
        p_main <- p_main + theme(panel.grid = element_blank(), panel.grid.minor = element_blank())
      }
      if ((params$axis_style %||% "default") %in% c("classic_arrow", "classic")) {
        is_arrow <- (params$axis_style %||% "default") == "classic_arrow"
        n_y <- length(levels(lane_df$.subject_factor))
        x_rng <- if (!is.null(time_range)) time_range else range(c(lane_df$.start_plot, lane_df$.end_plot), na.rm = TRUE)
        x_span <- max(1e-6, diff(x_rng))
        clip_pad <- max(1e-6, 0.001 * x_span)
        x_axis_start <- if (is_arrow) x_rng[1] - 0.03 * x_span else x_rng[1] + clip_pad
        x_axis_end <- if (is_arrow) x_rng[2] + 0.06 * x_span else x_rng[2] - clip_pad
        p_main <- p_main +
          theme_classic(base_size = params$base_font_size, base_family = plot_family) +
          theme(
            axis.line = element_blank(),
            axis.text.y = if (isTRUE(params$show_subject_labels)) element_text() else element_blank(),
            axis.ticks.y = if (isTRUE(params$show_subject_labels)) element_line() else element_blank(),
            legend.position = if (isTRUE(params$show_legend)) (params$main_legend_position %||% "right") else "none",
            plot.margin = margin(10, 20, 12, 16)
          ) +
          coord_cartesian(xlim = time_range, clip = "off")
        
        p_main <- graphics_add_classic_axis_segments(
          p_main,
          x_start = x_axis_start,
          x_end = x_axis_end,
          y_start = 0.5,
          y_end = n_y + 0.55,
          arrow = is_arrow,
          linewidth = 0.45,
          color = "black"
        )
      } else if (!is.null(time_range)) {
        p_main <- p_main + coord_cartesian(xlim = time_range)
      }

      if (is.null(track_df) || !isTRUE(params$show_tracks)) {
        p_combined <- p_main
      } else {
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
        track_colors <- setNames(palette_values(length(track_keys), "Set3"), track_keys)
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
            geom_text(data = text_track_df, aes(label = .track_value), size = max(2.8, params$base_font_size * 0.22), family = plot_family)
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

      if (isTRUE(params$show_legend) && !is.null(event_legend_df) && nrow(event_legend_df) > 0) {
        legend_title <- graphics_resolve_legend_title(params$event_legend_title, "", "")
        group_levels <- unique(event_legend_df$.group[order(event_legend_df$.group_index)])
        legend_rows_list <- lapply(seq_along(group_levels), function(gidx) {
          g <- group_levels[[gidx]]
          sub <- event_legend_df %>% filter(.group == g) %>% arrange(.label)
          header <- data.frame(.group = g, .label = g, .color = NA_character_, .shape = NA_real_, .is_header = TRUE, .is_spacer = FALSE, stringsAsFactors = FALSE)
          items <- sub %>% mutate(.is_header = FALSE, .is_spacer = FALSE) %>% select(.group, .label, .color, .shape, .is_header, .is_spacer)
          spacer <- data.frame(.group = g, .label = "", .color = NA_character_, .shape = NA_real_, .is_header = FALSE, .is_spacer = TRUE, stringsAsFactors = FALSE)
          if (gidx < length(group_levels)) {
            bind_rows(header, items, spacer)
          } else {
            bind_rows(header, items)
          }
        })
        legend_rows <- bind_rows(legend_rows_list)
        
        # Calculate y positions to keep items compact and groups separated
        current_y <- 0
        y_vals <- numeric(nrow(legend_rows))
        for (i in seq_len(nrow(legend_rows))) {
          if (legend_rows$.is_header[i]) {
            current_y <- current_y - 1.2
            y_vals[i] <- current_y
          } else if (legend_rows$.is_spacer[i]) {
            current_y <- current_y - 2.5  # Increase gap between event groups
            y_vals[i] <- current_y
          } else {
            current_y <- current_y - 0.8
            y_vals[i] <- current_y
          }
        }
        legend_rows$.y <- y_vals
        
        min_y_val <- min(y_vals, na.rm = TRUE)
        # Prevent stretching when there are few items by setting a minimum range
        y_lower_limit <- min(min_y_val - 2, -25)
        
        p_event_legend <- ggplot(legend_rows, aes(y = .y)) +
          geom_point(
            data = legend_rows %>% filter(!.is_header, !.is_spacer),
            aes(x = 0.04, shape = .shape, color = .color),
            size = params$event_size,
            stroke = 0.4,
            show.legend = FALSE
          ) +
          geom_text(
            data = legend_rows %>% filter(!.is_spacer),
            aes(x = ifelse(.is_header, 0.02, 0.12), label = .label, fontface = ifelse(.is_header, "bold", "plain")),
            hjust = 0,
            size = max(3, params$base_font_size * 0.24),
            show.legend = FALSE,
            family = plot_family
          ) +
          scale_shape_identity() +
          scale_color_identity() +
          scale_y_continuous(limits = c(y_lower_limit, 0), expand = c(0, 0)) +
          coord_cartesian(xlim = c(0, 1), clip = "off") +
          theme_void(base_family = plot_family) +
          theme(
            plot.margin = margin(8, 8, 8, 8),
            plot.title = element_text(size = max(10, params$base_font_size), family = plot_family, face = "bold")
          )
        if (nzchar(legend_title)) {
          p_event_legend <- p_event_legend + ggtitle(legend_title)
        }
        legend_pos <- params$event_legend_position %||% "right"
        p_combined <- graphics_place_aux_legend(
          p_combined,
          p_event_legend,
          position = legend_pos,
          outside_ratio = 0.35,
          inside_anchor = c(
            params$event_legend_x_ratio %||% 0.72,
            params$event_legend_y_ratio %||% 0.03,
            params$event_legend_width_ratio %||% 0.26,
            params$event_legend_height_ratio %||% 0.28
          )
        )
      }

      if (isTRUE(params$auto_mapping_caption) && isTRUE(params$show_tracks) && length(selected_tracks) > 0) {
        auto_caption_lines <- c(auto_caption_lines, paste0("轨道图显示变量：", paste(unname(track_label_map[selected_tracks]), collapse = "、"), "。"))
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
      lane_data(lane_df)
      event_data(if (!is.null(event_df)) dplyr::select(event_df, -tidyselect::any_of(".event_style_key")) else event_df)
      track_data(track_df)
      showNotification("泳道图生成完成", type = "message")
    }, error = function(e) {
      committed_params(NULL)
      final_plot(NULL)
      main_plot_obj(NULL)
      lane_data(NULL)
      event_data(NULL)
      track_data(NULL)
      graphics_notify_error("泳道图", e)
    })
  })

  output$static_plot <- renderPlot({
    shiny::validate(shiny::need(!is.null(final_plot()), "请先完成参数设置并点击“生成图形”。"))
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
    shiny::validate(shiny::need(!is.null(main_plot_obj()), "请先生成泳道图后查看交互式图。"))
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

  output$lane_table <- renderDT({
    shiny::validate(shiny::need(!is.null(lane_data()) && nrow(lane_data()) > 0, "当前无可展示的泳道数据。"))
    datatable(lane_data(), options = list(pageLength = 15, scrollX = TRUE))
  })

  output$event_table <- renderDT({
    ed <- event_data()
    shiny::validate(shiny::need(!is.null(ed) && nrow(ed) > 0, "未配置事件映射或无事件数据"))
    datatable(ed, options = list(pageLength = 15, scrollX = TRUE))
  })

  output$track_table <- renderDT({
    td <- track_data()
    shiny::validate(shiny::need(!is.null(td), "未选择分组轨道变量"))
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
    if (!is.list(state)) return(invisible(FALSE))
    tryCatch({
      extra_state <- graphics_task_payload_extra_state(state)
      restoring_event_controls(TRUE)

      if (!is.null(extra_state$subject_id)) graphics_state$subject_id <- extra_state$subject_id
      if (!is.null(extra_state$lane_time_mode)) graphics_state$lane_time_mode <- extra_state$lane_time_mode
      if (!is.null(extra_state$start_time)) graphics_state$start_time <- extra_state$start_time
      if (!is.null(extra_state$end_time)) graphics_state$end_time <- extra_state$end_time
      if (!is.null(extra_state$duration_var)) graphics_state$duration_var <- extra_state$duration_var
      if (!is.null(extra_state$lane_color_by)) graphics_state$lane_color_by <- extra_state$lane_color_by
      if (!is.null(extra_state$ongoing_var)) graphics_state$ongoing_var <- extra_state$ongoing_var
      if (!is.null(extra_state$tracks)) graphics_state$tracks <- extra_state$tracks
      if (!is.null(extra_state$event_legend_title)) updateTextInput(session, "event_legend_title", value = extra_state$event_legend_title)
      if (!is.null(extra_state$lock_event_style_refresh)) updateCheckboxInput(session, "lock_event_style_refresh", value = isTRUE(extra_state$lock_event_style_refresh))
      if (!is.null(extra_state$event_symbol_seed)) updateNumericInput(session, "event_symbol_seed", value = extra_state$event_symbol_seed)
      if (!is.null(extra_state$x_unit)) updateSelectInput(session, "x_unit", selected = extra_state$x_unit)
      if (!is.null(extra_state$x_break_step)) updateNumericInput(session, "x_break_step", value = extra_state$x_break_step)
      if (!is.null(extra_state$time_range) && length(extra_state$time_range) == 2) {
        graphics_state$time_range <- extra_state$time_range
      }
      if (!is.null(extra_state$size_mode)) updateSelectInput(session, "size_mode", selected = extra_state$size_mode)
      if (!is.null(extra_state$export_width_in)) updateNumericInput(session, "export_width_in", value = extra_state$export_width_in)
      if (!is.null(extra_state$export_height_in)) updateNumericInput(session, "export_height_in", value = extra_state$export_height_in)
      if (is.list(extra_state$event_mappings) && length(extra_state$event_mappings) > 0) {
        event_ui_state(extra_state$event_mappings)
        event_map_count(length(extra_state$event_mappings))
      }

      df_restore <- isolate(data())
      time_vars_restore <- if (!is.null(df_restore)) get_time_vars(df_restore) else character(0)
      all_vars_restore <- if (!is.null(df_restore)) names(df_restore) else character(0)
      event_time_candidates <- c("EVENT_TIME", "EVT_TIME", "ADT", "AVISITN", "event_time")
      event_type_candidates <- c("EVENT", "EVENT_TYPE", "BOR", "STATUS", "RESPONSE", "event_type")
      event_label_candidates <- c("EVENT_LABEL", "LABEL", "EVENT_TEXT", "AVALC", "event_label")
      restore_snapshot <- list(
        subject_id = extra_state$subject_id %||% NULL,
        lane_time_mode = extra_state$lane_time_mode %||% NULL,
        start_time = extra_state$start_time %||% NULL,
        end_time = extra_state$end_time %||% NULL,
        duration_var = extra_state$duration_var %||% NULL,
        lane_color_by = extra_state$lane_color_by %||% NULL,
        ongoing_var = extra_state$ongoing_var %||% NULL,
        tracks = extra_state$tracks %||% character(0),
        event_mappings = extra_state$event_mappings %||% list()
      )

      graphics_restore_task_input_state(
        session,
        state,
        exclude_ids = c(
          "subject_id", "lane_time_mode", "start_time", "end_time",
          "duration_var", "lane_color_by", "ongoing_var", "tracks", "time_range", "time_range_slider"
        ),
        exclude_patterns = c(
          graphics_task_input_exclude_patterns(),
          "^event_time_",
          "^event_type_",
          "^event_label_",
          "^event_legend_title_[0-9]+$",
          "^event_grp_",
          "^track_mode_[0-9a-f]+$",
          "^lane_col_",
          "^track_col_"
        )
      )

      session$onFlushed(function() {
        tryCatch({
          restore_swimmer_mapping_inputs(force = TRUE, df_current = df_restore, state_snapshot = restore_snapshot)
          if (!is.null(extra_state$time_range) && length(extra_state$time_range) == 2) {
            updateSliderInput(session, "time_range", value = extra_state$time_range)
          }
          if (is.list(extra_state$event_mappings) && length(extra_state$event_mappings) > 0) {
            session$onFlushed(function() {
              tryCatch({
                refresh_event_mapping_choices(
                  all_vars = all_vars_restore,
                  time_vars = time_vars_restore,
                  event_time_candidates = event_time_candidates,
                  event_type_candidates = event_type_candidates,
                  event_label_candidates = event_label_candidates,
                  prefer_state = TRUE
                )
                for (i in seq_len(length(extra_state$event_mappings))) {
                  mapping <- extra_state$event_mappings[[i]]
                  if (!is.null(mapping$event_time)) updateSelectizeInput(session, paste0("event_time_", i), selected = mapping$event_time, server = TRUE)
                  if (!is.null(mapping$event_type)) updateSelectizeInput(session, paste0("event_type_", i), selected = mapping$event_type, server = TRUE)
                  if (!is.null(mapping$event_label)) updateSelectizeInput(session, paste0("event_label_", i), selected = mapping$event_label, server = TRUE)
                  if (!is.null(mapping$event_legend_title)) updateTextInput(session, paste0("event_legend_title_", i), value = mapping$event_legend_title)
                }
                session$onFlushed(function() {
                  tryCatch({
                    restore_swimmer_dynamic_style_inputs(extra_state)
                    restoring_event_controls(FALSE)
                  }, error = function(e) {
                    restoring_event_controls(FALSE)
                    message(sprintf("[SwimmerApplyStateDynamicStyleError] %s", conditionMessage(e)))
                  })
                }, once = TRUE)
              }, error = function(e) {
                restoring_event_controls(FALSE)
                message(sprintf("[SwimmerApplyStateEventFlushError] %s", conditionMessage(e)))
              })
            }, once = TRUE)
          } else {
            restoring_event_controls(FALSE)
          }
        }, error = function(e) {
          restoring_event_controls(FALSE)
          message(sprintf("[SwimmerApplyStateFlushError] %s", conditionMessage(e)))
        })
      }, once = TRUE)
      invisible(TRUE)
    }, error = function(e) {
      restoring_event_controls(FALSE)
      message(sprintf("[SwimmerApplyStateError] %s", conditionMessage(e)))
      invisible(FALSE)
    })
  }

  list(
    state = reactive({
      df_state <- data()
      event_mappings <- collect_swimmer_event_mappings(df_state)
      track_mode_map <- capture_track_mode_map(input$tracks %||% character(0))
      time_axis_cfg <- graphics_collect_time_axis_config(input, unit_id = "x_unit", break_id = "x_break_step")
      graphics_build_task_state(
        input,
        extra_state = list(
          subject_id = graphics_state$subject_id %||% input$subject_id,
          lane_time_mode = graphics_state$lane_time_mode %||% input$lane_time_mode,
          start_time = graphics_state$start_time %||% input$start_time,
          end_time = graphics_state$end_time %||% input$end_time,
          duration_var = graphics_state$duration_var %||% input$duration_var,
          lane_color_by = graphics_state$lane_color_by %||% input$lane_color_by,
          ongoing_var = graphics_state$ongoing_var %||% input$ongoing_var,
          event_mappings = event_mappings,
          lock_event_style_refresh = input$lock_event_style_refresh,
          event_symbol_seed = input$event_symbol_seed,
          event_legend_title = input$event_legend_title,
          x_unit = time_axis_cfg$unit,
          x_break_step = time_axis_cfg$break_step,
          time_range = normalize_time_range(graphics_state$time_range %||% input$time_range),
          tracks = graphics_state$tracks %||% input$tracks %||% character(0),
          track_mode_map = track_mode_map,
          lane_manual_colors = capture_lane_manual_color_values(df_state),
          track_color_values = capture_track_color_values(df_state, input$tracks %||% character(0), track_mode_map),
          size_mode = input$size_mode,
          export_width_in = size_config()$export_width,
          export_height_in = size_config()$export_height
        )
      )
    }),
    apply_state = apply_state
  )
}
