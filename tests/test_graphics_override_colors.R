library(testthat)

source(file.path("..", "modules", "common", "graphics_common.R"))

test_that("graphics_override_colors 在无覆盖时返回默认颜色", {
  defaults <- c("A : x" = "#111111", "B : y" = "#222222")
  out <- graphics_override_colors(defaults, NULL)
  expect_equal(out, defaults)
})

test_that("graphics_override_colors 仅覆盖有效键且忽略空值", {
  defaults <- c("A : x" = "#111111", "B : y" = "#222222")
  manual <- list(
    "A : x" = "#abcdef",
    "B : y" = "",
    "C : z" = "#123456"
  )
  out <- graphics_override_colors(defaults, manual)
  expect_equal(out[["A : x"]], "#abcdef")
  expect_equal(out[["B : y"]], "#222222")
  expect_false("C : z" %in% names(out))
})

test_that("graphics_filter_tracks_by_mode 仅保留目标模式轨道", {
  tracks <- c("trt", "site", "arm")
  mode_map <- list(trt = "color", site = "text", arm = "color")
  out <- graphics_filter_tracks_by_mode(tracks, mode_map, "color")
  expect_equal(out, c("trt", "arm"))
  out_text <- graphics_filter_tracks_by_mode(tracks, mode_map, "text")
  expect_equal(out_text, "site")
})

test_that("resolve_plot_size_config 支持统一尺寸模式切换", {
  cfg_default <- resolve_plot_size_config()
  expect_equal(cfg_default$static_width, 1200)
  expect_equal(cfg_default$interactive_height, 620)
  cfg_custom <- resolve_plot_size_config(
    mode = "custom",
    static_width_px = 1400,
    static_height_px = 880,
    interactive_width_px = 1100,
    interactive_height_px = 700,
    export_width_in = 11,
    export_height_in = 7.5
  )
  expect_equal(cfg_custom$static_width, 1400)
  expect_equal(cfg_custom$static_height, 880)
  expect_equal(cfg_custom$export_height, 7.5)
})

test_that("graphics_remember_choice 优先保留当前输入并支持空值回退", {
  expect_equal(
    graphics_remember_choice("b", "a", c("a", "b", "c"), "c"),
    "b"
  )
  expect_equal(
    graphics_remember_choice(NULL, "a", c("a", "b", "c"), "c"),
    "a"
  )
  expect_equal(
    graphics_remember_choice(NULL, NULL, character(0), "", allow_empty = TRUE),
    ""
  )
})

test_that("graphics_resolve_mapping_var 支持回退到默认变量", {
  vars <- c("USUBJID", "ARM", "AVAL")
  expect_equal(
    graphics_resolve_mapping_var("ARM", "USUBJID", vars, enable_fallback = TRUE),
    "ARM"
  )
  expect_equal(
    graphics_resolve_mapping_var("", "USUBJID", vars, enable_fallback = TRUE),
    "USUBJID"
  )
  expect_null(
    graphics_resolve_mapping_var("", "USUBJID", vars, enable_fallback = FALSE)
  )
})

test_that("graphics_group_symbol_controls_ui 生成分组符号配置控件", {
  skip_if_not_installed("shiny")
  ui <- graphics_group_symbol_controls_ui(
    session = shiny::MockShinySession$new(),
    levels = c("CR", "PR"),
    symbol_input_prefix = "symbol_lbl_",
    color_input_prefix = "symbol_col_",
    title = "符号分组映射"
  )
  expect_false(is.null(ui))
  expect_s3_class(ui, "shiny.tag.list")
  expect_true(length(ui) >= 1)
  color_only_ui <- graphics_group_symbol_controls_ui(
    session = shiny::MockShinySession$new(),
    levels = c("CR"),
    color_input_prefix = "symbol_col_",
    title = "仅颜色",
    show_symbol = FALSE,
    show_color = TRUE
  )
  expect_s3_class(color_only_ui, "shiny.tag.list")
})

test_that("graphics_compose_caption 合并用户脚注与自动脚注", {
  caption <- graphics_compose_caption("用户脚注", c("事件颜色按变量“分组”分别指定。", "轨道图显示变量：治疗组。"))
  expect_match(caption, "用户脚注")
  expect_match(caption, "事件颜色按变量")
  expect_match(caption, "轨道图显示变量")
})

test_that("graphics_resolve_legend_title 按优先级返回图例标题", {
  expect_equal(graphics_resolve_legend_title("自定义标题", "回退标题", "默认标题"), "自定义标题")
  expect_equal(graphics_resolve_legend_title("", "回退标题", "默认标题"), "回退标题")
  expect_equal(graphics_resolve_legend_title("", "", "默认标题"), "默认标题")
})

test_that("graphics_legend_position_choices 提供统一位置枚举", {
  outer <- graphics_legend_position_choices("outer")
  expect_true(all(c("right", "left", "top", "bottom") %in% unname(outer)))
  corners <- graphics_legend_position_choices("corners_none")
  expect_true(all(c("top-right", "bottom-right", "none") %in% unname(corners)))
  aux <- graphics_legend_position_choices("aux")
  expect_true(all(c("inside_bottom_right", "inside_custom") %in% unname(aux)))
})

test_that("graphics_legend_controls_ui 生成统一图例控件", {
  skip_if_not_installed("shiny")
  ns <- shiny::NS("legend")
  ui <- graphics_legend_controls_ui(ns, position_kind = "outer")
  expect_s3_class(ui, "shiny.tag")
})

test_that("graphics_place_aux_legend 支持图内右下角叠加", {
  p_main <- ggplot2::ggplot(data.frame(x = 1:2, y = 1:2), ggplot2::aes(x, y)) + ggplot2::geom_point()
  p_legend <- ggplot2::ggplot() + ggplot2::theme_void()
  out <- graphics_place_aux_legend(p_main, p_legend, position = "inside_bottom_right")
  expect_false(is.null(out))
})

test_that("graphics_apply_legend_theme 支持统一图例位置应用", {
  p <- ggplot2::ggplot(data.frame(x = 1:2, y = 1:2, g = c("A", "B")), ggplot2::aes(x, y, color = g)) + ggplot2::geom_point()
  out_top_right <- graphics_apply_legend_theme(p, show_legend = TRUE, position = "top-right")
  expect_equal(out_top_right$theme$legend.position, "inside")
  expect_equal(out_top_right$theme$legend.position.inside, c(1, 1))
  out_none <- graphics_apply_legend_theme(p, show_legend = FALSE, position = "right")
  expect_equal(out_none$theme$legend.position, "none")
})

test_that("graphics_resolve_inside_anchor 限制比例范围并保留有效尺寸", {
  anchor <- graphics_resolve_inside_anchor(x_ratio = 0.95, y_ratio = -0.2, width_ratio = 0.4, height_ratio = 0.3)
  expect_equal(length(anchor), 4)
  expect_true(anchor[[1]] <= 0.6)
  expect_true(anchor[[2]] >= 0)
  expect_equal(anchor[[3]], 0.4)
  expect_equal(anchor[[4]], 0.3)
})
