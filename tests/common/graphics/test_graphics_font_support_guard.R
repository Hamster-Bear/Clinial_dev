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

source(file.path("..", "modules", "common", "graphics_common.R"))

test_that("设备安全映射、CJK 兜底与统一字体方案分别可预测", {
  expect_equal(graphics_resolve_device_safe_family(""), "sans")
  expect_equal(graphics_resolve_device_safe_family("sans"), "sans")
  expect_equal(graphics_resolve_device_safe_family("Arial"), "sans")
  expect_equal(graphics_resolve_layout_family("Noto Sans SC"), "sans")
  expect_equal(graphics_resolve_layout_family("Times"), "serif")
  expect_true(graphics_resolve_cjk_family("Noto Sans SC", fallback_family = "sans") %in% c("sans", "Noto Sans SC"))
  expect_true(graphics_resolve_font_spec("sans")$layout %in% c("sans", "serif", "mono"))
  expect_true(graphics_resolve_font_spec("sans")$unified %in% c("sans", "Noto Sans SC"))
  expect_true(graphics_resolve_text_family("中文", base_family = "Arial") %in% c("sans", "Noto Sans SC"))
  expect_equal(graphics_resolve_text_family("English", base_family = "Arial"), "sans")
  expect_equal(graphics_resolve_text_family("中文", base_family = "Arial", context = "layout"), "sans")
})

test_that("图形字体 UI 默认暴露中文推荐字体与双字体配置", {
  common_ui_text <- paste(
    readLines(file.path("..", "modules", "statistical_graphics_ui", "common_ui_shell.R"), encoding = "UTF-8"),
    collapse = "\n"
  )

  expect_match(common_ui_text, 'default_family = "Noto Sans SC"')
  expect_match(common_ui_text, '"中文推荐 \\(Noto Sans SC\\)" = "Noto Sans SC"')
  expect_match(common_ui_text, 'graphics_font_family_pair_ui <- function')
  expect_match(common_ui_text, 'latin_label = "西文字体"')
  expect_match(common_ui_text, 'cjk_label = "中文字体"')
})

test_that("关键图形模块不再对自由文本硬编码 sans", {
  target_files <- c(
    "modules/statistical_graphics/waterfall_plot.R",
    "modules/statistical_graphics/swimmer_plot.R",
    "modules/statistical_graphics/forest_plot.R",
    "modules/exploratory_analysis.R",
    "modules/tables/ae_sidebyside.R"
  )

  for (target in target_files) {
    content <- paste(readLines(file.path("..", target), encoding = "UTF-8"), collapse = "\n")
    expect_false(
      grepl('family\\s*=\\s*"sans"', content),
      info = sprintf("%s 仍存在自由文本层硬编码 family = \"sans\"。", target)
    )
    expect_false(
      grepl('theme_void\\(base_family = "sans"\\)', content),
      info = sprintf("%s 仍存在 theme_void(base_family = \"sans\")。", target)
    )
  }
})

test_that("底部 caption 与关键模块显式透传解析后的字体族", {
  common_text <- paste(
    readLines(file.path("..", "modules", "common", "graphics_common.R"), encoding = "UTF-8"),
    collapse = "\n"
  )
  waterfall_text <- paste(
    readLines(file.path("..", "modules", "statistical_graphics", "waterfall_plot.R"), encoding = "UTF-8"),
    collapse = "\n"
  )
  swimmer_text <- paste(
    readLines(file.path("..", "modules", "statistical_graphics", "swimmer_plot.R"), encoding = "UTF-8"),
    collapse = "\n"
  )
  forest_text <- paste(
    readLines(file.path("..", "modules", "statistical_graphics", "forest_plot.R"), encoding = "UTF-8"),
    collapse = "\n"
  )
  exploratory_text <- paste(
    readLines(file.path("..", "modules", "exploratory_analysis.R"), encoding = "UTF-8"),
    collapse = "\n"
  )
  ae_sidebyside_text <- paste(
    readLines(file.path("..", "modules", "tables", "ae_sidebyside.R"), encoding = "UTF-8"),
    collapse = "\n"
  )

  expect_match(common_text, 'graphics_append_bottom_caption <- function\\(plot_obj, caption_text, base_font_size = 12, font_family = "sans", cjk_family = "Noto Sans SC", layout_family = NULL\\)')
  expect_match(common_text, 'family = caption_family', fixed = TRUE)
  expect_match(common_text, 'theme_void(base_family = caption_family)', fixed = TRUE)
  expect_match(common_text, 'graphics_resolve_layout_family <- function', fixed = TRUE)
  expect_match(waterfall_text, 'font_family = params$base_family %||% "sans"', fixed = TRUE)
  expect_match(waterfall_text, 'layout_family = font_spec$layout', fixed = TRUE)
  expect_match(swimmer_text, 'font_family = params$base_family %||% "sans"', fixed = TRUE)
  expect_match(swimmer_text, 'layout_family = font_spec$layout', fixed = TRUE)
  expect_match(forest_text, 'fontfamily = layout_family', fixed = TRUE)
  expect_false(grepl('draw_label\\([\\s\\S]*graphics_resolve_text_family', forest_text, perl = TRUE))
  expect_match(exploratory_text, 'plot_family <- graphics_resolve_font_spec("sans")$unified', fixed = TRUE)
  expect_match(ae_sidebyside_text, 'family = plot_family', fixed = TRUE)
})

