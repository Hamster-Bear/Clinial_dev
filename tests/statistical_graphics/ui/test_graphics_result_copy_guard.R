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

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

copy_text <- read_utf8("modules", "common", "graphics", "graphics_result_copy.R")
survival_text <- read_utf8("modules", "statistical_graphics", "survival_analysis.R")
forest_text <- read_utf8("modules", "statistical_graphics", "forest_plot.R")
combo_text <- read_utf8("modules", "statistical_graphics", "combo_plot.R")
waterfall_text <- read_utf8("modules", "statistical_graphics", "waterfall_plot.R")
swimmer_text <- read_utf8("modules", "statistical_graphics", "swimmer_plot.R")
spider_text <- read_utf8("modules", "statistical_graphics", "spider_plot.R")

expect_contains(copy_text, "GRAPHICS_RESULT_COPY <- list", "统计图形结果区共享文案对象")
expect_contains(copy_text, "survival = list", "生存分析结果区共享文案")
expect_contains(copy_text, "forest = list", "森林图结果区共享文案")
expect_contains(copy_text, "combo = list", "组合图结果区共享文案")
expect_contains(copy_text, "waterfall = list", "瀑布图结果区共享文案")
expect_contains(copy_text, "swimmer = list", "泳道图结果区共享文案")
expect_contains(copy_text, "spider = list", "蜘蛛图结果区共享文案")

expect_contains(survival_text, "source\\(\"modules/common/graphics/graphics_result_copy.R\"\\)", "生存分析加载结果区共享文案")
expect_contains(survival_text, "copy <- GRAPHICS_RESULT_COPY\\$survival", "生存分析读取结果区共享文案")
expect_contains(survival_text, "subtitle = copy\\$result_card\\$subtitle", "生存分析结果卡副标题改为共享文案")
expect_contains(survival_text, "app_card_note\\(copy\\$result_card\\$note\\)", "生存分析结果卡说明改为共享文案")
expect_contains(survival_text, "note = copy\\$static_plot\\$note", "生存分析静态图说明改为共享文案")
expect_contains(survival_text, "note = copy\\$interactive_plot\\$note", "生存分析交互图说明改为共享文案")
expect_contains(survival_text, "note = copy\\$data_tab\\$note", "生存分析数据页说明改为共享文案")

expect_contains(forest_text, "source\\(\"modules/common/graphics/graphics_result_copy.R\"\\)", "森林图加载结果区共享文案")
expect_contains(forest_text, "copy <- GRAPHICS_RESULT_COPY\\$forest", "森林图读取结果区共享文案")
expect_contains(forest_text, "subtitle = copy\\$result_card\\$subtitle", "森林图结果卡副标题改为共享文案")
expect_contains(forest_text, "app_card_note\\(copy\\$result_card\\$note\\)", "森林图结果卡说明改为共享文案")
expect_contains(forest_text, "note = copy\\$static_plot\\$note", "森林图静态图说明改为共享文案")
expect_contains(forest_text, "note = copy\\$data_tab\\$note", "森林图数据页说明改为共享文案")

expect_contains(combo_text, "source\\(\"modules/common/graphics/graphics_result_copy.R\"\\)", "组合图加载结果区共享文案")
expect_contains(combo_text, "copy <- GRAPHICS_RESULT_COPY\\$combo", "组合图读取结果区共享文案")
expect_contains(combo_text, "subtitle = copy\\$result_card\\$subtitle", "组合图结果卡副标题改为共享文案")
expect_contains(combo_text, "app_card_note\\(copy\\$result_card\\$note\\)", "组合图结果卡说明改为共享文案")
expect_contains(combo_text, "note = copy\\$static_plot\\$note", "组合图静态图说明改为共享文案")
expect_contains(combo_text, "note = copy\\$interactive_plot\\$note", "组合图交互图说明改为共享文案")
expect_contains(combo_text, "note = copy\\$data_tab\\$note", "组合图数据页说明改为共享文案")

expect_contains(waterfall_text, "source\\(\"modules/common/graphics/graphics_result_copy.R\"\\)", "瀑布图加载结果区共享文案")
expect_contains(waterfall_text, "copy <- GRAPHICS_RESULT_COPY\\$waterfall", "瀑布图读取结果区共享文案")
expect_contains(waterfall_text, "subtitle = copy\\$result_card\\$subtitle", "瀑布图结果卡副标题改为共享文案")
expect_contains(waterfall_text, "app_card_note\\(copy\\$result_card\\$note\\)", "瀑布图结果卡说明改为共享文案")
expect_contains(waterfall_text, "note = copy\\$static_plot\\$note", "瀑布图静态图说明改为共享文案")
expect_contains(waterfall_text, "note = copy\\$interactive_plot\\$note", "瀑布图交互图说明改为共享文案")
expect_contains(waterfall_text, "note = copy\\$data_tab\\$note", "瀑布图数据页说明改为共享文案")

expect_contains(swimmer_text, "source\\(\"modules/common/graphics/graphics_result_copy.R\"\\)", "泳道图加载结果区共享文案")
expect_contains(swimmer_text, "copy <- GRAPHICS_RESULT_COPY\\$swimmer", "泳道图读取结果区共享文案")
expect_contains(swimmer_text, "subtitle = copy\\$result_card\\$subtitle", "泳道图结果卡副标题改为共享文案")
expect_contains(swimmer_text, "app_card_note\\(copy\\$result_card\\$note\\)", "泳道图结果卡说明改为共享文案")
expect_contains(swimmer_text, "note = copy\\$static_plot\\$note", "泳道图静态图说明改为共享文案")
expect_contains(swimmer_text, "note = copy\\$interactive_plot\\$note", "泳道图交互图说明改为共享文案")
expect_contains(swimmer_text, "note = copy\\$data_tab\\$note", "泳道图数据页说明改为共享文案")

expect_contains(spider_text, "source\\(\"modules/common/graphics/graphics_result_copy.R\"\\)", "蜘蛛图加载结果区共享文案")
expect_contains(spider_text, "copy <- GRAPHICS_RESULT_COPY\\$spider", "蜘蛛图读取结果区共享文案")
expect_contains(spider_text, "subtitle = copy\\$result_card\\$subtitle", "蜘蛛图结果卡副标题改为共享文案")
expect_contains(spider_text, "app_card_note\\(copy\\$result_card\\$note\\)", "蜘蛛图结果卡说明改为共享文案")
expect_contains(spider_text, "note = copy\\$static_plot\\$note", "蜘蛛图静态图说明改为共享文案")
expect_contains(spider_text, "note = copy\\$interactive_plot\\$note", "蜘蛛图交互图说明改为共享文案")
expect_contains(spider_text, "note = copy\\$data_tab\\$note", "蜘蛛图数据页说明改为共享文案")

cat("Graphics result copy guard passed.\n")
