test_find_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- sub(file_arg, "", args[grep(file_arg, args)])
  script_path <- if (length(script_path) > 0) script_path[[1]] else ""
  start_candidates <- unique(c(
    if (nzchar(script_path)) dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)) else character(0),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  ))

  for (candidate in start_candidates) {
    current <- candidate
    repeat {
      if (file.exists(file.path(current, "app.R")) &&
          dir.exists(file.path(current, "modules")) &&
          dir.exists(file.path(current, "tests"))) {
        return(normalizePath(current, winslash = "/", mustWork = TRUE))
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }

  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))
library(testthat)

source(file.path("..", "modules", "common", "graphics", "graphics_common.R"))

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
  expect_equal(cfg_default$export_width, 12.5)
  expect_equal(cfg_default$export_height, 7.92)
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
  expect_equal(cfg_custom$export_width, 14.58)
  expect_equal(cfg_custom$export_height, 9.16)
})

test_that("resolve_plot_size_config 支持关闭同步并保留边距与边框配置", {
  cfg <- resolve_plot_size_config(
    mode = "custom",
    static_width_px = 1440,
    static_height_px = 900,
    export_width_in = 11,
    export_height_in = 8.5,
    sync_export_size = FALSE,
    page_margin_top_px = 36,
    page_margin_right_px = 20,
    page_margin_bottom_px = 18,
    page_margin_left_px = 40,
    canvas_border = FALSE
  )
  expect_false(cfg$sync_export_size)
  expect_equal(cfg$export_width, 11)
  expect_equal(cfg$export_height, 8.5)
  expect_equal(cfg$page_margin_top, 36)
  expect_equal(cfg$page_margin_left, 40)
  expect_false(cfg$canvas_border)
})

test_that("graphics_apply_canvas_frame 返回可导出的组合画布对象", {
  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  canvas_plot <- graphics_apply_canvas_frame(
    p,
    frame_width_px = 1200,
    frame_height_px = 760,
    canvas_config = resolve_plot_size_config()
  )
  expect_s3_class(canvas_plot, "ggplot")
})

test_that("graphics_collect_reference_line_spec 与 graphics_add_reference_lines 支持统一辅助线抽象", {
  input <- list(
    ref_line = 1,
    ref_line_color = "#123456",
    ref_line_linetype = "solid",
    ref_line_linewidth = 1.2
  )
  spec <- graphics_collect_reference_line_spec(input, "ref_line", orientation = "v")
  expect_equal(spec$orientation, "v")
  expect_equal(spec$value, 1)
  expect_equal(spec$color, "#123456")

  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  out <- graphics_add_reference_lines(p, list(spec))
  expect_s3_class(out, "ggplot")
  expect_equal(length(out$layers), length(p$layers) + 1)
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
  corners_aux <- graphics_legend_position_choices("corners_aux_none")
  expect_true(all(c("top-right", "inside_custom", "none") %in% unname(corners_aux)))
  aux <- graphics_legend_position_choices("aux")
  expect_true(all(c("inside_bottom_right", "inside_custom") %in% unname(aux)))
})

test_that("graphics_legend_controls_ui 生成统一图例控件", {
  skip_if_not_installed("shiny")
  ns <- shiny::NS("legend")
  ui <- graphics_legend_controls_ui(ns, position_kind = "outer")
  expect_s3_class(ui, "shiny.tag")
})

test_that("graphics_aux_legend_anchor_controls_ui 生成统一比例滑条控件", {
  skip_if_not_installed("shiny")
  ns <- shiny::NS("legend")
  ui <- graphics_aux_legend_anchor_controls_ui(ns, position_id = "legend_position")
  expect_s3_class(ui, "shiny.tag")
  compact_ui <- graphics_aux_legend_anchor_controls_ui(
    ns,
    position_id = "text_position_preset",
    x_ratio_id = "stats_x",
    y_ratio_id = "stats_y",
    include_size = FALSE,
    condition_positions = "custom"
  )
  expect_s3_class(compact_ui, "shiny.tag")
})

test_that("graphics 辅助图例绘制器支持点线图例与堆叠组合", {
  point_legend <- graphics_build_point_legend_plot(
    labels = c("A", "B"),
    colors = c(A = "#E41A1C", B = "#377EB8"),
    shape_value = 124,
    title = "Censor"
  )
  line_legend <- graphics_build_line_legend_plot(
    labels = c("A", "B"),
    colors = c(A = "#E41A1C", B = "#377EB8"),
    title = "Arm"
  )
  stacked <- graphics_compose_stacked_legends(line_legend, point_legend)
  expect_s3_class(point_legend, "ggplot")
  expect_s3_class(line_legend, "ggplot")
  expect_false(is.null(stacked))
})

test_that("graphics 设备安全字体解析与统一字体方案职责分离", {
  expect_equal(graphics_resolve_device_safe_family("Arial"), "sans")
  expect_equal(graphics_resolve_device_safe_family(" serif "), "serif")
  expect_equal(graphics_resolve_device_safe_family(NULL), "sans")
  expect_true(graphics_resolve_font_spec("sans")$unified %in% c("sans", "Noto Sans SC"))
})

test_that("graphics 辅助图例支持透传统一字体族", {
  point_legend <- graphics_build_point_legend_plot(
    labels = c("A", "B"),
    colors = c(A = "#E41A1C", B = "#377EB8"),
    font_family = "serif"
  )
  line_legend <- graphics_build_line_legend_plot(
    labels = c("A", "B"),
    colors = c(A = "#E41A1C", B = "#377EB8"),
    font_family = "mono"
  )
  expect_equal(point_legend$layers[[2]]$aes_params$family, "serif")
  expect_equal(point_legend$theme$text$family, "serif")
  expect_equal(line_legend$layers[[2]]$aes_params$family, "mono")
  expect_equal(line_legend$theme$text$family, "mono")
})

test_that("graphics 辅助图例统一使用紧凑因子间距规则", {
  rows <- graphics_build_legend_rows(c("A", "B", "C"))
  expect_equal(round(diff(rows$y), 2), c(-1, -1))
  expect_equal(graphics_aux_legend_compact_defaults$row_gap, 1.0)
  point_legend <- graphics_build_point_legend_plot(c("A", "B"), c(A = "#E41A1C", B = "#377EB8"))
  line_legend <- graphics_build_line_legend_plot(c("A", "B"), c(A = "#E41A1C", B = "#377EB8"))
  point_y <- ggplot2::ggplot_build(point_legend)$data[[1]]$y
  line_y <- ggplot2::ggplot_build(line_legend)$data[[1]]$y
  expect_equal(point_y, line_y)
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

