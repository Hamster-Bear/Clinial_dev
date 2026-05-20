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
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

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
expect_not_contains(landing_text, "当前已上线应用", "主 Landing 不出现项目进度口径")
expect_not_contains(landing_text, "© 2026", "主 Landing 不出现年份进度口径")
expect_not_contains(landing_text, "Hamster Analysis", "主 Landing 不再使用旧品牌")
expect_not_contains(landing_text, ">AutoTFL<", "主 Landing 不再直接展示旧产品名")
expect_not_contains(landing_text, "最短决策路径", "不再暴露内部架构逻辑词汇")
expect_not_contains(landing_text, "看介绍进子页", "不再暴露内部架构逻辑词汇")

expect_contains(autotfl_text, "<title>Medev</title>", "产品页标题")
expect_contains(autotfl_text, "用于医学数据分析的简洁工作台。", "产品页 Hero 主标题")
expect_contains(autotfl_text, "Medev 包含哪些内容", "产品页功能产出区")
expect_contains(autotfl_text, "第一次使用，从一条最短路径开始", "产品页使用指南区")
expect_contains(autotfl_text, "结果图片占位", "产品页图片占位区")
expect_contains(autotfl_text, "Landing 主展示图占位", "产品页保留图片占位")
expect_contains(autotfl_text, "href=\"/landing/index.html\"", "产品页保留返回主页入口")
expect_contains(autotfl_text, "href=\"/app/\"", "产品页保留应用入口")
expect_not_contains(autotfl_text, "当前已上线应用", "产品页不出现项目进度口径")
expect_not_contains(autotfl_text, "© 2026", "产品页不出现年份进度口径")
expect_not_contains(autotfl_text, "Hamster Analysis", "产品页不再使用旧品牌")
expect_not_contains(autotfl_text, ">AutoTFL<", "产品页不再直接展示旧产品名")
expect_not_contains(autotfl_text, "cdn.jsdelivr.net/npm/chart.js", "产品页不再引入虚构图表库")
expect_not_contains(autotfl_text, "canvas id=\"demoChart\"", "产品页不再展示伪图表示意")

expect_not_contains(landing_text, "商业智能分析", "未落地产品矩阵文案")
expect_not_contains(landing_text, "基因组数据分析", "未落地产品矩阵文案")
expect_not_contains(landing_text, "机器学习平台", "未落地产品矩阵文案")
expect_not_contains(landing_text, "用户满意度", "虚构运营指标")
expect_not_contains(landing_text, "系统可用性", "虚构运营指标")
expect_not_contains(landing_text, "HIPAA", "无证据合规承诺")
expect_not_contains(landing_text, "GDPR", "无证据合规承诺")
expect_not_contains(landing_text, "浏览器兼容性提示", "兼容性提示")
expect_not_contains(landing_text, "技术栈", "技术栈宣传")
expect_not_contains(landing_text, "平台层", "抽象分层文案")
expect_not_contains(landing_text, "应用层", "抽象分层文案")
expect_not_contains(autotfl_text, "技术栈", "AutoTFL 子页技术栈宣传")
expect_not_contains(autotfl_text, "平台层", "AutoTFL 子页抽象分层文案")
expect_not_contains(autotfl_text, "应用层", "AutoTFL 子页抽象分层文案")

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

cat("Landing copy guard passed.\n")

