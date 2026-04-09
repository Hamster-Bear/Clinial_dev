args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

app_text <- paste(readLines(file.path(project_root, "app.R"), encoding = "UTF-8", warn = FALSE), collapse = "\n")

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(app_text, "return\\(sidebarMenu\\(", "未登录侧边栏应立即返回登录注册菜单")
expect_contains(app_text, "selected = \"login\"", "未登录侧边栏默认选中登录页")
expect_contains(app_text, "textInput\\(\"login_identity\", \"用户名或邮箱\"", "登录页支持用户名或邮箱")
expect_contains(app_text, "textInput\\(\"register_email\", \"邮箱\"", "注册页包含邮箱字段")
expect_contains(app_text, "top_right_user_panel", "右上角用户信息面板")
expect_contains(app_text, "#shiny-notification-panel", "通知面板位置样式")

cat("App auth layout guard passed.\n")
