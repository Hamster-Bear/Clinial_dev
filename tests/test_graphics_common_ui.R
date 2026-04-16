library(testthat)
library(shiny)
library(htmltools)

# 模拟加载依赖的UI模块
source(file.path("..", "modules", "statistical_graphics_ui", "common_ui_shell.R"))

context("Graphics Common UI Components")

test_that("graphics_reference_line_ui generates correct HTML structure", {
  # 模拟命名空间函数
  ns <- NS("test_module")
  
  # 调用UI生成函数
  ui_output <- graphics_reference_line_ui(
    ns = ns, 
    id_prefix = "ref_line", 
    label = "Test Line", 
    default_value = 15,
    default_color = "#123456",
    default_linetype = "dotted",
    default_linewidth = 1.5
  )
  
  # 将UI对象转换为HTML字符串进行断言
  html_str <- as.character(ui_output)
  
  # 验证核心控件是否存在并包含了正确的前缀和默认值
  expect_match(html_str, 'id="test_module-ref_line"')
  expect_match(html_str, 'value="15"')
  
  # 验证颜色控件
  expect_match(html_str, 'id="test_module-ref_line_color"')
  expect_match(html_str, 'value="#123456"')
  
  # 验证线型控件
  expect_match(html_str, 'id="test_module-ref_line_linetype"')
  expect_match(html_str, 'dotted')
  
  # 验证线宽控件
  expect_match(html_str, 'id="test_module-ref_line_linewidth"')
  expect_match(html_str, 'value="1.5"')
  
  # 验证Label传递
  expect_match(html_str, 'Test Line')
  expect_match(html_str, 'Test Line颜色')
  expect_match(html_str, 'Test Line线型')
  expect_match(html_str, 'Test Line线宽')
})

test_that("graphics_export_size_controls_ui 暴露统一尺寸同步与页面距控件", {
  ns <- NS("test_module")
  ui_output <- graphics_export_size_controls_ui(
    ns = ns,
    download_id = "dl_plot",
    include_size_mode = TRUE,
    include_download_button = FALSE
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, 'id="test_module-sync_export_size"')
  expect_match(html_str, 'id="test_module-size_sync_ppi"')
  expect_match(html_str, 'id="test_module-page_margin_top_px"')
  expect_match(html_str, 'id="test_module-page_margin_left_px"')
  expect_match(html_str, '导出尺寸跟随前端画布')
})

test_that("graphics_centered_output_container 生成居中容器并支持边框", {
  ui_output <- graphics_centered_output_container(
    content = tags$div("plot area"),
    frame_width_px = 960,
    frame_height_px = 540,
    canvas_config = list(
      canvas_border = TRUE,
      canvas_border_color = "#CCCCCC",
      canvas_border_size = 1,
      canvas_background = "#FFFFFF"
    ),
    use_canvas_border = TRUE
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "justify-content:center")
  expect_match(html_str, "width:960px")
  expect_match(html_str, "border: 1.0px solid #CCCCCC")
})

test_that("graphics_axis_range_controls_ui 生成统一轴范围控件", {
  ns <- NS("test_module")
  ui_output <- graphics_axis_range_controls_ui(
    ns = ns,
    min_id = "x_min",
    max_id = "x_max",
    axis_label = "X轴",
    min_value = 1,
    max_value = 99
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, 'id="test_module-x_min"')
  expect_match(html_str, 'id="test_module-x_max"')
  expect_match(html_str, 'X轴下限')
  expect_match(html_str, 'X轴上限')
  expect_match(html_str, 'value="1"')
  expect_match(html_str, 'value="99"')
})

test_that("graphics_time_axis_settings_ui 生成统一时间轴设置控件", {
  ns <- NS("test_module")
  ui_output <- graphics_time_axis_settings_ui(
    ns = ns,
    unit_id = "time_unit",
    unit_choices = c("天" = "day", "周" = "week"),
    selected_unit = "day",
    step_id = "x_break_step",
    step_label = "X轴刻度步长"
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, 'id="test_module-time_unit"')
  expect_match(html_str, 'id="test_module-x_break_step"')
  expect_match(html_str, 'X轴刻度步长')
})

test_that("graphics_column_mapping_panel_ui 生成统一列映射卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_column_mapping_panel_ui(
    ns = ns,
    title = "数据映射",
    fields = list(
      list(
        list(id = "var_a", label = "变量A", type = "selectize", column = 6),
        list(id = "var_b", label = "变量B", type = "select", choices = c("A", "B"), column = 6)
      )
    ),
    help_text = "用于测试"
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "panel-heading")
  expect_match(html_str, "数据映射")
  expect_match(html_str, 'id="test_module-var_a"')
  expect_match(html_str, 'id="test_module-var_b"')
  expect_match(html_str, "用于测试")
})

test_that("graphics_time_axis_panel_ui 组合统一时间轴卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_time_axis_panel_ui(
    ns = ns,
    title = "时间轴设置",
    unit_id = "time_unit",
    unit_choices = c("天" = "day"),
    selected_unit = "day",
    include_range_slider = TRUE,
    include_slider_step_input = FALSE
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "时间轴设置")
  expect_match(html_str, 'id="test_module-time_unit"')
  expect_match(html_str, 'id="test_module-time_range_slider"')
})

test_that("graphics_export_panel_ui 组合统一导出卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_export_panel_ui(
    ns = ns,
    download_id = "dl_plot",
    include_size_mode = TRUE,
    include_download_button = FALSE
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "输出与导出")
  expect_match(html_str, 'id="test_module-render_plot"')
  expect_match(html_str, 'id="test_module-export_width_in"')
})

test_that("graphics_export_panel_ui 支持关闭内置生成按钮", {
  ns <- NS("test_module")
  ui_output <- graphics_export_panel_ui(
    ns = ns,
    download_id = "dl_plot",
    include_render_button = FALSE,
    include_size_mode = TRUE,
    include_download_button = FALSE
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "输出与导出")
  expect_no_match(html_str, 'id="test_module-render_plot"')
  expect_match(html_str, 'id="test_module-export_width_in"')
})

test_that("graphics_output_action_bar_ui 生成统一结果动作条", {
  ns <- NS("test_module")
  ui_output <- graphics_output_action_bar_ui(
    ns = ns,
    render_button_id = "render_plot",
    download_id = "dl_plot"
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, 'id="test_module-render_plot"')
  expect_match(html_str, 'id="test_module-dl_plot"')
  expect_match(html_str, "生成图形")
  expect_match(html_str, "下载图形")
})

test_that("graphics_dynamic_mapping_rows_panel_ui 生成统一动态映射容器", {
  ns <- NS("test_module")
  ui_output <- graphics_dynamic_mapping_rows_panel_ui(
    ns = ns,
    title = "事件映射",
    rows_ui = tags$div("rows"),
    add_button_id = "add_row",
    remove_button_id = "remove_row",
    add_label = "添加",
    remove_label = "减少"
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "事件映射")
  expect_match(html_str, 'id="test_module-add_row"')
  expect_match(html_str, 'id="test_module-remove_row"')
  expect_match(html_str, "rows")
})

test_that("graphics_dynamic_mapping_fields_ui 生成 spec 驱动的动态映射字段", {
  ns <- NS("test_module")
  ui_output <- graphics_dynamic_mapping_fields_ui(
    ns = ns,
    fields = list(
      list(
        list(id = "field_a", label = "字段A", type = "selectize", choices = c("无" = "", "A" = "a"), selected = "a", column = 6),
        list(id = "field_b", label = "字段B", type = "text", selected = "demo", column = 6)
      )
    )
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, 'id="test_module-field_a"')
  expect_match(html_str, 'id="test_module-field_b"')
  expect_match(html_str, "字段A")
  expect_match(html_str, "字段B")
})

test_that("graphics_display_legend_panel_ui 生成统一显示与图例卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_display_legend_panel_ui(
    ns = ns,
    title = "显示与图例",
    fields = list(
      list(list(id = "show_legend", label = "显示图例", type = "checkbox", value = TRUE)),
      list(list(id = "legend_title", label = "图例标题", type = "text", selected = "标题")),
      list(list(id = "decimals", label = "小数位", type = "numeric", value = 1, min = 0, max = 5, step = 1))
    )
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "显示与图例")
  expect_match(html_str, 'id="test_module-show_legend"')
  expect_match(html_str, 'id="test_module-legend_title"')
  expect_match(html_str, 'id="test_module-decimals"')
})

test_that("graphics_text_label_panel_ui 生成统一文本与标签卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_text_label_panel_ui(
    ns = ns,
    title = "文本与标签",
    fields = list(
      list(list(id = "plot_title", label = "主标题", type = "text", selected = "标题")),
      list(list(id = "plot_caption", label = "脚注", type = "textarea", selected = "说明", rows = 2)),
      list(
        list(id = "plot_xlab", label = "X轴标签", type = "text", selected = "X", column = 6),
        list(id = "plot_ylab", label = "Y轴标签", type = "text", selected = "Y", column = 6)
      )
    )
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "文本与标签")
  expect_match(html_str, 'id="test_module-plot_title"')
  expect_match(html_str, 'id="test_module-plot_caption"')
  expect_match(html_str, 'id="test_module-plot_xlab"')
  expect_match(html_str, 'id="test_module-plot_ylab"')
})

test_that("graphics_palette_layout_panel_ui 生成统一配色与布局卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_palette_layout_panel_ui(
    ns = ns,
    title = "配色与布局",
    fields = list(
      list(list(id = "palette", label = "调色板", type = "select", choices = graphics_palette_choice_values("qualitative"), selected = "Set2")),
      list(
        list(id = "alpha", label = "透明度", type = "slider", value = 0.8, min = 0.2, max = 1, step = 0.05, column = 6),
        list(id = "size", label = "线宽", type = "numeric", value = 1, min = 0.5, max = 5, step = 0.1, column = 6)
      )
    )
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "配色与布局")
  expect_match(html_str, 'id="test_module-palette"')
  expect_match(html_str, 'id="test_module-alpha"')
  expect_match(html_str, 'id="test_module-size"')
})

test_that("graphics_palette_choice_values 提供共享调色板枚举", {
  pal_choices <- graphics_palette_choice_values("qualitative")
  expect_true("默认Hue" %in% names(pal_choices))
  expect_equal(unname(pal_choices[["Set2"]]), "Set2")
})

test_that("graphics_axis_proportion_panel_ui 生成统一坐标与比例卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_axis_proportion_panel_ui(
    ns = ns,
    title = "坐标与比例",
    fields = list(
      list(
        list(id = "breaks_n", label = "刻度数量", type = "numeric", value = 9, min = 4, max = 20, step = 1, column = 6),
        list(id = "rel_height", label = "占比", type = "slider", value = 0.5, min = 0.2, max = 4, step = 0.1, column = 6)
      )
    )
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "坐标与比例")
  expect_match(html_str, 'id="test_module-breaks_n"')
  expect_match(html_str, 'id="test_module-rel_height"')
})

test_that("graphics_reference_threshold_panel_ui 生成统一参考线与阈值卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_reference_threshold_panel_ui(
    ns = ns,
    title = "参考线与阈值",
    toggle_id = "show_ref",
    toggle_label = "显示参考线",
    toggle_value = TRUE,
    conditional_ui = tags$div("ref-body")
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "参考线与阈值")
  expect_match(html_str, 'id="test_module-show_ref"')
  expect_match(html_str, "ref-body")
})

test_that("graphics_symbol_style_panel_ui 生成统一符号与样式卡片", {
  ns <- NS("test_module")
  ui_output <- graphics_symbol_style_panel_ui(
    ns = ns,
    title = "符号与样式",
    fields = list(
      list(
        list(id = "point_color", label = "默认颜色", type = "color", value = "#112233", column = 6),
        list(id = "point_size", label = "点大小", type = "numeric", value = 3, min = 1, max = 10, step = 1, column = 6)
      )
    )
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, "符号与样式")
  expect_match(html_str, 'id="test_module-point_color"')
  expect_match(html_str, 'id="test_module-point_size"')
})

test_that("graphics_point_shape_choices 提供共享点形状枚举", {
  shape_choices <- graphics_point_shape_choices()
  expect_true("+" %in% names(shape_choices))
  expect_equal(unname(shape_choices[["+"]]), 3)
  expect_true("☆" %in% names(shape_choices))
})

test_that("graphics_group_style_mode_choices 提供共享样式模式枚举", {
  mode_choices <- graphics_group_style_mode_choices()
  expect_equal(unname(mode_choices[["随机且不重复"]]), "random_unique")
  expect_equal(unname(mode_choices[["单一指定"]]), "single")
  expect_equal(unname(mode_choices[["分别指定"]]), "manual_each")
})

test_that("graphics_group_style_rule_ui 生成统一按组样式规则控件", {
  ns <- NS("test_module")
  session <- list(ns = ns)
  ui_output <- graphics_group_style_rule_ui(
    session = session,
    mode_input_id = "color_mode",
    mode_label = "颜色分配",
    selected_mode = "single",
    single_input_id = "single_color",
    single_input_label = "指定颜色",
    single_input_type = "color",
    single_value = "#112233",
    manual_each_ui = tags$div("manual-ui")
  )
  html_str <- as.character(ui_output)
  expect_match(html_str, 'id="test_module-color_mode"')
  expect_match(html_str, 'id="test_module-single_color"')
  expect_match(html_str, "manual-ui")
})

test_that("graphics_group_style_mapping_panel_ui 生成统一按组样式映射面板", {
  ui_output <- graphics_group_style_mapping_panel_ui("符号分组映射", tags$div("mapping-body"))
  html_str <- as.character(ui_output)
  expect_match(html_str, "符号分组映射")
  expect_match(html_str, "mapping-body")
})

test_that("graphics_build_overlay_point_layer_fields_spec 生成叠加点层字段定义", {
  spec <- graphics_build_overlay_point_layer_fields_spec(
    row_index = 2,
    time_choices = c("ADT"),
    type_choices = c("BOR"),
    label_choices = c("AVALC"),
    selected_time = "ADT",
    selected_type = "BOR",
    selected_label = "AVALC",
    selected_legend_title = "事件标题"
  )
  expect_length(spec, 3)
  expect_equal(spec[[1]][[1]]$id, "event_time_2")
  expect_equal(spec[[1]][[2]]$id, "event_type_2")
  expect_equal(spec[[2]][[1]]$id, "event_label_2")
  expect_equal(spec[[3]][[1]]$id, "event_legend_title_2")
  expect_equal(spec[[3]][[1]]$selected, "事件标题")
})
