args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

landing_path <- file.path(project_root, "nginx", "landing", "index.html")
autotfl_path <- file.path(project_root, "nginx", "landing", "autotfl.html")
guide_path <- file.path(project_root, "PROJECT_GUIDE.md")

landing_lines <- readLines(landing_path, encoding = "UTF-8", warn = FALSE)
autotfl_lines <- readLines(autotfl_path, encoding = "UTF-8", warn = FALSE)
guide_lines <- readLines(guide_path, encoding = "UTF-8", warn = FALSE)

landing_text <- paste(landing_lines, collapse = "\n")
autotfl_text <- paste(autotfl_lines, collapse = "\n")
guide_text <- paste(guide_lines, collapse = "\n")

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

expect_contains(landing_text, "<title>Hamster Analysis</title>", "主 Landing 标题")
expect_contains(landing_text, "专业的医学数据分析平台。", "主 Landing Hero 主标题")
expect_contains(landing_text, "专为临床研究打造的在线统计工作台", "主 Landing 客客气气面向客户的文案")
expect_contains(landing_text, "准备好提升分析效率了吗", "主 Landing 引导使用入口")
expect_contains(landing_text, "href=\"/landing/autotfl.html\"", "主 Landing 保留 AutoTFL 子页入口")
expect_contains(landing_text, "href=\"/app/\"", "主 Landing 保留主应用入口")
expect_not_contains(landing_text, "AutoTFL 最终产出什么", "主 Landing 不展开功能产出区")
expect_not_contains(landing_text, "第一次使用，先跑出一版结果", "主 Landing 不展开使用指南区")
expect_not_contains(landing_text, "最短决策路径", "不再暴露内部架构逻辑词汇")
expect_not_contains(landing_text, "看介绍进子页", "不再暴露内部架构逻辑词汇")

expect_contains(autotfl_text, "<title>Hamster Analysis · AutoTFL</title>", "AutoTFL 子页标题")
expect_contains(autotfl_text, "表、图、TFL，在 AutoTFL 里串成一条可交付路径。", "AutoTFL 子页 Hero 主标题")
expect_contains(autotfl_text, "AutoTFL 最终产出什么", "AutoTFL 子页功能产出区")
expect_contains(autotfl_text, "第一次使用，先跑出一版结果", "AutoTFL 子页使用指南区")
expect_contains(autotfl_text, "先看结果样子", "AutoTFL 子页结果示意区")
expect_contains(autotfl_text, "href=\"/landing/index.html\"", "AutoTFL 子页保留返回主页入口")
expect_contains(autotfl_text, "href=\"/app/\"", "AutoTFL 子页保留应用入口")

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

expect_contains(guide_text, "Hamster Analysis | 平台级命名", "PROJECT_GUIDE 名称约定同步")
expect_contains(guide_text, "AutoTFL 作为当前已上线应用，通过 `/app/` 提供实际分析能力。", "PROJECT_GUIDE 入口规则同步")
expect_contains(guide_text, "`nginx/landing/index.html` 只保留平台入口与最短访问路径", "PROJECT_GUIDE 主 Landing 职责同步")
expect_contains(guide_text, "`nginx/landing/autotfl.html` 单独承接 AutoTFL 的功能产出、使用指南与结果示意", "PROJECT_GUIDE AutoTFL 子页职责同步")
expect_contains(guide_text, "少字、高识别", "PROJECT_GUIDE 精简文案方向同步")
expect_contains(guide_text, "Hamster Analysis · AutoTFL", "PROJECT_GUIDE 标题统一同步")

cat("Landing copy guard passed.\n")
