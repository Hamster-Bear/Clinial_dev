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

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}
access_manager_text <- read_utf8("modules", "workspace_access_manager.R")
if (!nzchar(access_manager_text)) return(invisible(NULL))
admin_manager_text <- read_utf8("modules", "admin_manager.R")
if (!nzchar(admin_manager_text)) return(invisible(NULL))
data_prep_text <- read_utf8("modules", "data_preparation.R")

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

expect_contains(access_manager_text, "title = \"用户和权限\"", "用户和权限页标题")
expect_contains(access_manager_text, "title = \"用户信息\"", "用户和权限页用户信息卡片")
expect_contains(access_manager_text, "title = \"权限管理\"", "用户和权限页权限管理卡片")
expect_contains(access_manager_text, "title = \"我的已授权空间\"", "用户和权限页普通成员授权信息卡片")
expect_contains(access_manager_text, "title = \"协作权限预览\"", "用户和权限页协作预览卡片")
expect_contains(access_manager_text, "当前账号名下还没有可管理的数据空间", "用户和权限页无空间非空态说明")
expect_contains(access_manager_text, "权限管理数据加载失败", "用户和权限页权限查询失败兜底说明")
expect_contains(access_manager_text, "左侧用户信息仍可正常使用", "用户和权限页查询失败仍保留用户信息")
expect_contains(access_manager_text, "你当前暂无可管理空间，但右侧会展示已被授予访问权限的数据空间与当前角色", "用户和权限页被授权成员说明")
expect_contains(access_manager_text, "app_card_dependencies\\(\\)", "用户和权限页加载公共卡片依赖")
expect_contains(access_manager_text, "app_card_box\\(", "用户和权限页使用公共卡片壳")
expect_contains(access_manager_text, "app_card_panel\\(", "用户和权限页使用公共面板壳")
expect_contains(access_manager_text, "app_card_note\\(", "用户和权限页使用公共说明壳")
expect_contains(access_manager_text, "基础信息", "用户和权限页基础信息分组")
expect_contains(access_manager_text, "绑定邮箱", "用户和权限页绑定邮箱分组")
expect_contains(access_manager_text, "邮箱换绑", "用户和权限页邮箱换绑分组")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"current_email_verify_code\"\\), \"验证码\"", "用户和权限页邮箱验证验证码输入")
expect_contains(access_manager_text, "request_current_email_verify", "用户和权限页发送邮箱验证码动作")
expect_contains(access_manager_text, "submit_current_email_verify", "用户和权限页确认邮箱验证动作")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"change_email_new_email\"\\), \"新邮箱\"", "用户和权限页邮箱换绑新邮箱输入")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"change_email_code\"\\), \"换绑验证码\"", "用户和权限页邮箱换绑验证码输入")
expect_contains(access_manager_text, "request_email_change_code", "用户和权限页发送换绑验证码动作")
expect_contains(access_manager_text, "submit_email_change", "用户和权限页确认换绑动作")
expect_contains(access_manager_text, "passwordInput\\(session\\$ns\\(\"password_change_current_password\"\\), \"当前密码\"", "用户和权限页修改密码当前密码输入")
expect_contains(access_manager_text, "passwordInput\\(session\\$ns\\(\"password_change_new_password\"\\), \"新密码\"", "用户和权限页修改密码新密码输入")
expect_contains(access_manager_text, "passwordInput\\(session\\$ns\\(\"password_change_confirm_password\"\\), \"确认新密码\"", "用户和权限页修改密码确认输入")
expect_contains(access_manager_text, "submit_password_change", "用户和权限页修改密码动作")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"target_email\"\\), \"协作者邮箱\"", "Owner 权限管理授权邮箱输入")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"owner_email\"\\), \"新负责人的邮箱\"", "Owner 权限管理迁移邮箱输入")
expect_contains(access_manager_text, "tabBox\\(", "Owner 权限管理预览使用标签页")
expect_contains(access_manager_text, "service_membership_preview_df\\(", "Owner 权限管理成员预览格式化")
expect_contains(access_manager_text, "service_invite_preview_df\\(", "Owner 权限管理邀请预览格式化")
expect_contains(access_manager_text, "service_grant_workspace_access_by_email\\(", "Owner 权限管理通过 service 授权")
expect_contains(access_manager_text, "service_revoke_workspace_access_by_email\\(", "Owner 权限管理通过 service 撤销")
expect_contains(access_manager_text, "service_transfer_workspace_owner_by_email\\(", "Owner 权限管理通过 service 迁移 owner")
expect_contains(access_manager_text, "auth_request_current_email_verification\\(", "用户和权限页通过 auth 请求邮箱验证")
expect_contains(access_manager_text, "auth_verify_email_code\\(", "用户和权限页通过 auth 确认邮箱验证")
expect_contains(access_manager_text, "auth_request_email_change\\(", "用户和权限页通过 auth 请求邮箱换绑")
expect_contains(access_manager_text, "auth_confirm_email_change\\(", "用户和权限页通过 auth 确认邮箱换绑")
expect_contains(access_manager_text, "auth_change_password\\(", "用户和权限页通过 auth 修改密码")
expect_contains(access_manager_text, "service_list_accessible_workspaces\\(", "用户和权限页查询普通成员已授权空间")
expect_contains(access_manager_text, "accessible_workspace_table", "用户和权限页渲染已授权空间表格")
expect_not_contains(access_manager_text, "isolate\\(current_user\\(\\)\\)", "用户和权限页不应隔离当前登录态刷新")
expect_not_contains(access_manager_text, "selectInput\\(session\\$ns\\(\"target_user", "Owner 权限管理不允许用户下拉选人")

expect_contains(admin_manager_text, "title = \"系统管理入口\"", "管理员页标题")
expect_contains(admin_manager_text, "app_card_dependencies\\(\\)", "管理员页加载公共卡片依赖")
expect_contains(admin_manager_text, "app_card_box\\(", "管理员页使用公共卡片 helper")
expect_contains(admin_manager_text, "app_card_note\\(", "管理员页使用公共说明块")
expect_contains(admin_manager_text, "app_card_panel\\(", "管理员页使用公共信息面板")
expect_contains(admin_manager_text, "app_stat_card\\(", "管理员页使用公共摘要卡")
expect_contains(admin_manager_text, "textInput\\(session\\$ns\\(\"owner_email\"\\), \"新负责人邮箱\"", "管理员 Owner 邮箱输入")
expect_contains(admin_manager_text, "textInput\\(session\\$ns\\(\"membership_email\"\\), \"协作者邮箱\"", "管理员 Membership 邮箱输入")
expect_contains(admin_manager_text, "tabBox\\(", "管理员协作预览使用标签页")
expect_contains(admin_manager_text, "service_membership_preview_df\\(", "管理员成员预览格式化")
expect_contains(admin_manager_text, "service_invite_preview_df\\(", "管理员邀请预览格式化")
expect_contains(admin_manager_text, "grant_db_access", "管理员页开放数据库管理按钮")
expect_contains(admin_manager_text, "revoke_db_access", "管理员页锁定数据库管理按钮")
expect_contains(admin_manager_text, "service_set_user_db_access\\(", "管理员页通过 service 调整数据库管理权限")
expect_contains(admin_manager_text, "service_list_manageable_workspaces\\(", "管理员页仅加载自己可管理的数据空间")
expect_contains(admin_manager_text, "title = \"系统概览\"", "管理员页系统概览区块")
expect_contains(admin_manager_text, "title = \"运行环境\"", "管理员页运行环境区块")
expect_contains(admin_manager_text, "title = \"SMTP 连通性测试\"", "管理员页 SMTP 探针区块")
expect_contains(admin_manager_text, "title = \"异常态势摘要\"", "管理员页异常态势摘要区块")
expect_contains(admin_manager_text, "title = \"所有注册账号总览\"", "管理员页所有注册账号总览区块")
expect_contains(admin_manager_text, "title = \"我名下数据空间概览\"", "管理员页名下空间概览区块")
expect_contains(admin_manager_text, "admin_user_meta_card", "管理员页目标账号完整状态卡片")
expect_contains(admin_manager_text, "admin_action_hint", "管理员页操作影响预览")
expect_contains(admin_manager_text, "admin_runtime_meta", "管理员页运行环境摘要")
expect_contains(admin_manager_text, "admin_smtp_probe_meta", "管理员页 SMTP 探针摘要")
expect_contains(admin_manager_text, "admin_smtp_probe_last_result", "管理员页 SMTP 探针最近结果摘要")
expect_contains(admin_manager_text, "smtp_probe_email", "管理员页 SMTP 探针邮箱输入")
expect_contains(admin_manager_text, "smtp_probe_send", "管理员页 SMTP 探针发送按钮")
expect_contains(admin_manager_text, "email_service_probe_summary\\(", "管理员页 SMTP 探针摘要 helper")
expect_contains(admin_manager_text, "email_service_send_probe\\(", "管理员页 SMTP 探针发送 helper")
expect_contains(admin_manager_text, "最近一次探针状态", "管理员页 SMTP 探针最近状态文案")
expect_contains(admin_manager_text, "smtp_probe_last_result <- reactiveVal", "管理员页 SMTP 探针结果状态保存")
expect_contains(admin_manager_text, "admin_risk_overview", "管理员页异常态势摘要输出")
expect_contains(admin_manager_text, "admin_user_registry_summary", "管理员页注册账号总览摘要卡")
expect_contains(admin_manager_text, "admin_user_registry_filters", "管理员页注册账号总览预设筛选")
expect_contains(admin_manager_text, "admin_user_registry_filter_note", "管理员页注册账号总览当前筛选提示")
expect_contains(admin_manager_text, "admin_user_registry_table", "管理员页所有注册账号总览表")
expect_contains(admin_manager_text, "admin_workspace_summary_table", "管理员页名下空间概览表")
expect_contains(admin_manager_text, "filter = \"top\"", "管理员页所有注册账号总览按列筛查")
expect_contains(admin_manager_text, "registry_filter_all", "管理员页注册账号总览全部账号筛选")
expect_contains(admin_manager_text, "registry_filter_admin", "管理员页注册账号总览管理员筛选")
expect_contains(admin_manager_text, "registry_filter_inactive", "管理员页注册账号总览停用账号筛选")
expect_contains(admin_manager_text, "registry_filter_no_email", "管理员页注册账号总览未设置邮箱筛选")
expect_contains(admin_manager_text, "registry_filter_db_locked", "管理员页注册账号总览未开通数据空间功能筛选")
expect_contains(admin_manager_text, "registry_filter_pending", "管理员页注册账号总览待领取邀请筛选")
expect_contains(admin_manager_text, "停用账号", "管理员页异常态势摘要停用账号统计")
expect_contains(admin_manager_text, "未设置邮箱账号", "管理员页异常态势摘要邮箱统计")
expect_contains(admin_manager_text, "未注册邀请邮箱", "管理员页异常态势摘要未注册邀请邮箱统计")
expect_contains(admin_manager_text, "当前可访问空间", "管理员页所有注册账号总览可访问空间统计")
expect_contains(admin_manager_text, "待领取邀请", "管理员页所有注册账号总览待领取邀请统计")
expect_contains(admin_manager_text, "注册账号总数", "管理员页注册账号总览摘要总数")
expect_contains(admin_manager_text, "只看未开通数据空间功能", "管理员页注册账号总览预设筛选文案")
expect_contains(admin_manager_text, "jump_account_admin", "管理员页异常态势摘要账号状态快捷跳转")
expect_contains(admin_manager_text, "jump_owner_admin", "管理员页异常态势摘要负责人调整快捷跳转")
expect_contains(admin_manager_text, "jump_membership_admin", "管理员页异常态势摘要协作授权快捷跳转")
expect_contains(admin_manager_text, "jump_workspace_summary", "管理员页异常态势摘要空间概览快捷跳转")
expect_contains(admin_manager_text, "admin_account_section", "管理员页账号状态锚点")
expect_contains(admin_manager_text, "admin_owner_section", "管理员页负责人调整锚点")
expect_contains(admin_manager_text, "admin_membership_section", "管理员页协作授权锚点")
expect_contains(admin_manager_text, "admin_workspace_summary_section", "管理员页空间概览锚点")
expect_contains(admin_manager_text, "scrollIntoView", "管理员页异常态势摘要页内跳转行为")
expect_contains(admin_manager_text, "admin_user_registry_table", "管理员页异常态势摘要账号状态聚焦账号总览表")
expect_contains(admin_manager_text, "owner_email", "管理员页异常态势摘要负责人调整聚焦输入框")
expect_contains(admin_manager_text, "membership_email", "管理员页异常态势摘要协作授权聚焦输入框")
expect_contains(admin_manager_text, "updateTabsetPanel\\(session, session\\$ns\\(\"admin_preview_tabs\"\\), selected = \"待领取邀请\"\\)", "管理员页异常态势摘要协作授权切换待领取邀请预览")
expect_contains(admin_manager_text, "updateTabsetPanel\\(session, session\\$ns\\(\"admin_preview_tabs\"\\), selected = \"当前成员\"\\)", "管理员页异常态势摘要空间概览切换当前成员预览")
expect_contains(admin_manager_text, "service_transfer_workspace_owner_by_email\\(", "管理员通过 service 迁移 owner")
expect_contains(admin_manager_text, "service_grant_workspace_access_by_email\\(", "管理员通过 service 授权")
expect_contains(admin_manager_text, "service_revoke_workspace_access_by_email\\(", "管理员通过 service 撤销")
expect_contains(admin_manager_text, "admin_user_registry_table_rows_selected", "管理员页账号状态管理通过账号总览行选择联动")
expect_contains(admin_manager_text, "service_set_user_status\\(", "管理员页通过 user_id 调整账号状态")
expect_contains(admin_manager_text, "service_set_user_db_access\\(", "管理员页通过 user_id 调整数据库管理权限")
expect_not_contains(admin_manager_text, "admin-summary-card", "管理员页不再保留模块内摘要卡样式")
expect_not_contains(admin_manager_text, "admin-form-note", "管理员页不再保留模块内说明块样式")
expect_not_contains(admin_manager_text, "admin-section-note", "管理员页不再保留模块内区块说明样式")
expect_not_contains(admin_manager_text, "selectInput\\(session\\$ns\\(\"membership_user", "管理员页不允许下拉选择目标用户")
expect_not_contains(admin_manager_text, "selectInput\\(session\\$ns\\(\"owner_user", "管理员页不允许下拉选择 owner 用户")
expect_not_contains(admin_manager_text, "textInput\\(session\\$ns\\(\"admin_user_email\"", "管理员页不再通过邮箱输入定位账号")
if (nzchar(data_prep_text)) {
  expect_contains(data_prep_text, "不会写入持久化数据空间", "数据准备页临时上传声明")
}

cat("Workspace access manager guard passed.\n")

