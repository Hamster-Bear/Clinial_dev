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

copy_guard_json <- file.path(project_root, "inst", "copy_guard_patterns.json")
if (!file.exists(copy_guard_json)) {
  stop("copy_guard_patterns.json 不存在: ", copy_guard_json, call. = FALSE)
}
copy_guard_data <- jsonlite::fromJSON(copy_guard_json, simplifyVector = TRUE)
landing_patterns <- copy_guard_data$categories$landing_integrity$patterns

landing_path <- file.path(project_root, "nginx", "landing", "index.html")
autotfl_path <- file.path(project_root, "nginx", "landing", "autotfl.html")
guide_path <- file.path(project_root, "docs", "main", "PROJECT_GUIDE.md")
spec_path <- file.path(project_root, "docs", "main", "PROJECT_SPEC.md")
deployment_path <- file.path(project_root, "docs", "deploy", "DEPLOY_GUIDE.md")

if (length(landing_path) == 0 || !file.exists(landing_path)) return("")

landing_lines <- readLines(landing_path, encoding = "UTF-8", warn = FALSE)
autotfl_lines <- readLines(autotfl_path, encoding = "UTF-8", warn = FALSE)
guide_lines <- readLines(guide_path, encoding = "UTF-8", warn = FALSE)
spec_lines <- readLines(spec_path, encoding = "UTF-8", warn = FALSE)
deployment_lines <- readLines(deployment_path, encoding = "UTF-8", warn = FALSE)

landing_text <- paste(landing_lines, collapse = "\n")
autotfl_text <- paste(autotfl_lines, collapse = "\n")
guide_text <- paste(guide_lines, collapse = "\n")
spec_text <- paste(spec_lines, collapse = "\n")
deployment_text <- paste(deployment_lines, collapse = "\n")

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("发现应移除内容: %s", label), call. = FALSE)
  }
}

expect_contains(landing_text, "<title>Medev</title>", "主 Landing 标题")
expect_contains(landing_text, "面向医学数据分析的简洁工作台。", "主 Landing Hero 主标题")
expect_contains(landing_text, "聚焦数据准备、统计分析、统计图形与 TFL 输出", "主 Landing 真实功能描述")
expect_contains(landing_text, "从入口开始，直接进入需要的页面。", "主 Landing 引导使用入口")
expect_contains(landing_text, "href=\"/landing/autotfl.html\"", "主 Landing 保留 AutoTFL 子页入口")
expect_contains(landing_text, "href=\"/app/\"", "主 Landing 保留主应用入口")

expect_contains(autotfl_text, "<title>Medev</title>", "产品页标题")
expect_contains(autotfl_text, "用于医学数据分析的简洁工作台。", "产品页 Hero 主标题")
expect_contains(autotfl_text, "Medev 包含哪些内容", "产品页功能产出区")
expect_contains(autotfl_text, "第一次使用，从一条最短路径开始", "产品页使用指南区")
expect_contains(autotfl_text, "结果图片占位", "产品页图片占位区")
expect_contains(autotfl_text, "Landing 主展示图占位", "产品页保留图片占位")
expect_contains(autotfl_text, "href=\"/landing/index.html\"", "产品页保留返回主页入口")
expect_contains(autotfl_text, "href=\"/app/\"", "产品页保留应用入口")

test_that("Landing 页面不得包含 JSON 中定义的 integrity 禁词", {
  for (pattern in landing_patterns) {
    expect_false(
      grepl(pattern, landing_text, fixed = TRUE),
      info = sprintf("主 Landing 包含禁词: %s", pattern)
    )
    expect_false(
      grepl(pattern, autotfl_text, fixed = TRUE),
      info = sprintf("AutoTFL 子页包含禁词: %s", pattern)
    )
  }
})

test_that("Landing 页面特定语义禁词（含特殊上下文）", {
  special_only_landing <- c(
    "当前已上线应用",
    "© 2026",
    "Hamster Analysis",
    ">AutoTFL<",
    "最短决策路径",
    "看介绍进子页",
    "商业智能分析",
    "基因组数据分析",
    "机器学习平台",
    "用户满意度",
    "系统可用性",
    "HIPAA",
    "GDPR",
    "浏览器兼容性提示"
  )
  for (pattern in special_only_landing) {
    expect_false(
      grepl(pattern, landing_text, fixed = TRUE),
      info = sprintf("主 Landing 特殊禁词: %s", pattern)
    )
  }

  special_autotfl_only <- c("cdn.jsdelivr.net/npm/chart.js", "canvas id=\"demoChart\"")
  for (pattern in special_autotfl_only) {
    expect_false(
      grepl(pattern, autotfl_text, fixed = TRUE),
      info = sprintf("AutoTFL 子页特殊禁词: %s", pattern)
    )
  }
})

expect_contains(guide_text, "Medev | Landing 对外名称", "PROJECT_GUIDE 名称约定同步")
expect_contains(guide_text, "Landing 页当前统一使用 Medev 对外口径", "PROJECT_GUIDE 入口规则同步")
expect_contains(guide_text, "`nginx/landing/index.html` 作为 Medev 首页", "PROJECT_GUIDE 主 Landing 职责同步")
expect_contains(guide_text, "`nginx/landing/autotfl.html` 作为 Medev 产品介绍子页", "PROJECT_GUIDE 产品页职责同步")
expect_contains(guide_text, "图片占位", "PROJECT_GUIDE 图片占位约束同步")
expect_contains(guide_text, "不插入虚构图表", "PROJECT_GUIDE 文案边界同步")

expect_contains(spec_text, "Landing 对外产品口径为 Medev", "PROJECT_SPEC Landing 命名同步")
expect_contains(spec_text, "Landing 页面只展示真实已落地能力，并为后续实际截图保留图片占位", "PROJECT_SPEC Landing 边界同步")

expect_contains(deployment_text, "Medev 首页", "DEPLOYMENT_GUIDE Landing 文件职责同步")
expect_contains(deployment_text, "Medev 产品介绍子页", "DEPLOYMENT_GUIDE 产品页职责同步")

test_that("Landing 禁词 JSON 数据源完整性", {
  expect_true(length(landing_patterns) >= 19,
    info = sprintf("landing_integrity patterns 数量异常: %d (预期 >= 19)", length(landing_patterns)))
})

cat("Landing copy guard passed.\n")
