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

module_text <- read_utf8("modules", "account_access", "user_profile.R")
if (!nzchar(module_text)) return(invisible(NULL))

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

expect_contains(module_text, "user_profile_ui <- function", "用户信息模块 UI 定义")
expect_contains(module_text, "user_profile_server <- function", "用户信息模块 server 定义")
expect_contains(module_text, "title = \"用户信息\"", "用户信息模块标题")
expect_contains(module_text, "subtitle = \"基础资料与少量信息变更\"", "用户信息模块副标题")
expect_contains(module_text, "uiOutput\\(ns\\(\"profile_notice\"\\)\\)", "用户信息模块说明输出")
expect_contains(module_text, "uiOutput\\(ns\\(\"profile_content\"\\)\\)", "用户信息模块主体输出")
expect_contains(module_text, "build_profile_content", "用户信息模块独立构建函数")
expect_contains(module_text, "基础信息", "用户信息模块基础信息分组")
expect_contains(module_text, "绑定邮箱", "用户信息模块绑定邮箱分组")
expect_contains(module_text, "邮箱换绑", "用户信息模块邮箱换绑分组")
expect_contains(module_text, "修改密码", "用户信息模块修改密码分组")
expect_contains(module_text, "textInput\\(session\\$ns\\(\"current_email_verify_code\"\\), \"验证码\"", "用户信息模块邮箱验证验证码输入")
expect_contains(module_text, "request_current_email_verify", "用户信息模块发送验证码动作")
expect_contains(module_text, "submit_current_email_verify", "用户信息模块确认验证动作")
expect_contains(module_text, "textInput\\(session\\$ns\\(\"change_email_new_email\"\\), \"新邮箱\"", "用户信息模块新邮箱输入")
expect_contains(module_text, "textInput\\(session\\$ns\\(\"change_email_code\"\\), \"换绑验证码\"", "用户信息模块换绑验证码输入")
expect_contains(module_text, "passwordInput\\(session\\$ns\\(\"password_change_current_password\"\\), \"当前密码\"", "用户信息模块修改密码当前密码输入")
expect_contains(module_text, "passwordInput\\(session\\$ns\\(\"password_change_new_password\"\\), \"新密码\"", "用户信息模块修改密码新密码输入")
expect_contains(module_text, "passwordInput\\(session\\$ns\\(\"password_change_confirm_password\"\\), \"确认新密码\"", "用户信息模块修改密码确认密码输入")
expect_contains(module_text, "auth_request_current_email_verification\\(", "用户信息模块通过 auth 请求邮箱验证")
expect_contains(module_text, "auth_verify_email_code\\(", "用户信息模块通过 auth 确认邮箱验证")
expect_contains(module_text, "auth_request_email_change\\(", "用户信息模块通过 auth 请求邮箱换绑")
expect_contains(module_text, "auth_confirm_email_change\\(", "用户信息模块通过 auth 确认邮箱换绑")
expect_contains(module_text, "auth_change_password\\(", "用户信息模块通过 auth 修改密码")
expect_contains(module_text, "service_claim_workspace_invites\\(", "用户信息模块邮箱换绑后认领邀请")
expect_contains(module_text, "用户信息区渲染失败", "用户信息模块异常兜底")
expect_not_contains(module_text, "isolate\\(current_user\\(\\)\\)", "用户信息模块不应隔离当前登录态")

cat("User profile guard passed.\n")
