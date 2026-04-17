args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

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

expect_contains(access_manager_text, "title = \"我的数据空间权限\"", "Owner 权限管理标题")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"target_email\"\\), \"协作者邮箱\"", "Owner 权限管理授权邮箱输入")
expect_contains(access_manager_text, "textInput\\(session\\$ns\\(\"owner_email\"\\), \"新负责人的邮箱\"", "Owner 权限管理迁移邮箱输入")
expect_contains(access_manager_text, "tabBox\\(", "Owner 权限管理预览使用标签页")
expect_contains(access_manager_text, "service_membership_preview_df\\(", "Owner 权限管理成员预览格式化")
expect_contains(access_manager_text, "service_invite_preview_df\\(", "Owner 权限管理邀请预览格式化")
expect_contains(access_manager_text, "service_grant_workspace_access_by_email\\(", "Owner 权限管理通过 service 授权")
expect_contains(access_manager_text, "service_revoke_workspace_access_by_email\\(", "Owner 权限管理通过 service 撤销")
expect_contains(access_manager_text, "service_transfer_workspace_owner_by_email\\(", "Owner 权限管理通过 service 迁移 owner")
expect_not_contains(access_manager_text, "selectInput\\(session\\$ns\\(\"target_user", "Owner 权限管理不允许用户下拉选人")

expect_contains(admin_manager_text, "title = \"系统管理入口\"", "管理员页标题")
expect_contains(admin_manager_text, "textInput\\(session\\$ns\\(\"owner_email\"\\), \"新负责人邮箱\"", "管理员 Owner 邮箱输入")
expect_contains(admin_manager_text, "textInput\\(session\\$ns\\(\"membership_email\"\\), \"协作者邮箱\"", "管理员 Membership 邮箱输入")
expect_contains(admin_manager_text, "tabBox\\(", "管理员协作预览使用标签页")
expect_contains(admin_manager_text, "service_membership_preview_df\\(", "管理员成员预览格式化")
expect_contains(admin_manager_text, "service_invite_preview_df\\(", "管理员邀请预览格式化")
expect_contains(admin_manager_text, "grant_db_access", "管理员页开放数据库管理按钮")
expect_contains(admin_manager_text, "revoke_db_access", "管理员页锁定数据库管理按钮")
expect_contains(admin_manager_text, "service_set_user_db_access_by_email\\(", "管理员页通过 service 调整数据库管理权限")
expect_contains(admin_manager_text, "service_list_manageable_workspaces\\(", "管理员页仅加载自己可管理的数据空间")
expect_contains(admin_manager_text, "service_transfer_workspace_owner_by_email\\(", "管理员通过 service 迁移 owner")
expect_contains(admin_manager_text, "service_grant_workspace_access_by_email\\(", "管理员通过 service 授权")
expect_contains(admin_manager_text, "service_revoke_workspace_access_by_email\\(", "管理员通过 service 撤销")
expect_not_contains(admin_manager_text, "selectInput\\(session\\$ns\\(\"membership_user", "管理员页不允许下拉选择目标用户")
expect_not_contains(admin_manager_text, "selectInput\\(session\\$ns\\(\"owner_user", "管理员页不允许下拉选择 owner 用户")
if (nzchar(data_prep_text)) {
  expect_contains(data_prep_text, "不会写入持久化数据空间", "数据准备页临时上传声明")
}

cat("Workspace access manager guard passed.\n")
