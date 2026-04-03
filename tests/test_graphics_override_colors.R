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
