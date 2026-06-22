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
library(ggplot2)

source(file.path("..", "modules", "common", "graphics", "graphics_common.R"))

# -- 辅助：模拟 app.R 中的字体注册 + PostScript 数据库同步 --
.setup_font_env <- function() {
  if (requireNamespace("showtext", quietly = TRUE) &&
      requireNamespace("sysfonts", quietly = TRUE)) {
    # 注册 Noto Sans SC（优先用本地字体文件，无则跳过）
    font_candidates <- c(
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
      "/usr/share/fonts/opentype/noto/NotoSansCJKsc-Regular.otf",
      "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
      "C:/Windows/Fonts/msyh.ttc",
      "C:/Windows/Fonts/simhei.ttf"
    )
    font_file <- font_candidates[file.exists(font_candidates)]
    if (length(font_file) > 0 && !"Noto Sans SC" %in% sysfonts::font_families()) {
      tryCatch(
        sysfonts::font_add("Noto Sans SC", regular = font_file[[1]]),
        error = function(e) NULL
      )
    }
    showtext::showtext_auto()
    showtext::showtext_opts(dpi = 96, regular.warn = FALSE)

    # 同步到 R 内置字体数据库（与 app.R 一致：复制 Type1Font 模板）
    .sync <- function(family, builtin) {
      tryCatch({
        pf <- grDevices::postscriptFonts()
        template <- pf[["sans"]]
        if (!is.null(template)) {
          template$family <- builtin
          do.call(grDevices::postscriptFonts, stats::setNames(list(template), family))
        }
      }, error = function(e) NULL)
      tryCatch({
        pdf_f <- grDevices::pdfFonts()
        template <- pdf_f[["sans"]]
        if (!is.null(template)) {
          template$family <- builtin
          do.call(grDevices::pdfFonts, stats::setNames(list(template), family))
        }
      }, error = function(e) NULL)
      if (.Platform$OS.type == "windows") {
        win_builtin <- if (identical(builtin, "Helvetica")) "Arial" else builtin
        tryCatch(
          do.call(grDevices::windowsFonts, stats::setNames(list(grDevices::windowsFont(win_builtin)), family)),
          error = function(e) NULL
        )
      }
    }
    .sync("Noto Sans SC", "Helvetica")
    .sync("Arial", "Helvetica")
    .sync("Courier", "Courier")
  }
  invisible(NULL)
}

# -- 测试 --

test_that("Noto Sans SC 已同步到 PostScript 字体数据库，C_stringMetric 不报警", {
  skip_if_not_installed("showtext")
  skip_if_not_installed("sysfonts")

  .setup_font_env()

  # 收集所有警告
  w <- list()
  withCallingHandlers(
    tryCatch({
      # 用 Noto Sans SC 渲染一段中文文本到 null device
      p <- ggplot(data.frame(x = 1, y = 1, label = "中文测试"),
                  aes(x, y, label = label)) +
        geom_text(family = "Noto Sans SC", size = 5) +
        theme_void(base_family = "Noto Sans SC")

      pdf(NULL)  # null PDF device
      on.exit(dev.off(), add = TRUE)
      print(p)
    }, error = function(e) NULL),
    warning = function(w) {
      # 仅捕获 PostScript 字体相关警告
      if (grepl("PostScript", conditionMessage(w), ignore.case = TRUE) ||
          grepl("字体数据库", conditionMessage(w), fixed = TRUE)) {
        w <<- c(w, list(w))
      }
    }
  )

  expect_equal(length(w), 0,
    label = "PostScript 字体警告数量")
})

test_that("生存分析默认参数符合预期（防回归）", {
  skip_if_not_installed("shinydashboard")
  library(shinydashboard)

  ui_text <- paste(
    readLines(file.path("..", "modules", "statistical_graphics", "survival_analysis.R"),
              encoding = "UTF-8"),
    collapse = "\n"
  )

  # 坐标轴样式默认 classic（不带箭头）
  expect_match(ui_text, 'axis_style.*selected = "classic"', all = FALSE)
  # 网格线默认勾选
  expect_match(ui_text, 'show_grid.*value = TRUE', all = FALSE)
  # 中位生存辅助线默认 hv
  expect_match(ui_text, 'surv_median_line.*selected = "hv"', all = FALSE)
  # Y轴百分比默认勾选
  expect_match(ui_text, 'y_as_percent.*value = TRUE', all = FALSE)
  # Y轴小数位默认 0
  expect_match(ui_text, 'y_decimals.*value = 0', all = FALSE)
  # 图例位置默认 inside_custom（server + UI 双侧）
  expect_match(ui_text, 'legend_position = "inside_custom"', all = FALSE)
  expect_match(ui_text, 'default_position = "inside_custom"', all = FALSE)
})

test_that("生存分析 Y 轴标题动态间距防重叠", {
  skip_if_not_installed("shinydashboard")
  library(shinydashboard)

  surv_text <- paste(
    readLines(file.path("..", "modules", "statistical_graphics", "survival_analysis.R"),
              encoding = "UTF-8"),
    collapse = "\n"
  )

  # Y 轴标题必须有动态 margin 计算
  expect_match(surv_text, 'max_label_chars.*axis_font_size_pt',
    label = "Y 轴标题动态 margin 计算")
  expect_match(surv_text, 'axis\\.title\\.y\\.left.*margin.*y_title_margin_r',
    label = "Y 轴标题应用动态 margin")
})
