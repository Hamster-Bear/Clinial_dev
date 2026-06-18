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

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

account_service_path <- file.path(project_root, "modules", "common", "auth", "account_service.R")
if (length(account_service_path) > 0 && file.exists(account_service_path)) {
  source(account_service_path)
} else {
  return(invisible(NULL))
}
account_service_text <- paste(readLines(account_service_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

test_that("管理员服务层对非法输入有防御", {
  expect_equal(service_normalize_workspace_name("  demo  "), "demo")
  expect_error(service_normalize_workspace_name("   "), "请输入数据空间名称")
  expect_equal(service_label_workspace_role("viewer"), "只读成员")
  expect_equal(service_label_invite_status("pending"), "待领取")
  expect_equal(service_label_user_status("inactive"), "停用")
  expect_equal(service_label_db_access_status(TRUE), "已开放")
  expect_equal(service_label_db_access_status(FALSE), "未开放")
  expect_equal(service_normalize_role("viewer"), "viewer")
  expect_error(service_normalize_role("bad_role"), "不支持的成员角色")
  expect_error(service_normalize_role("owner", allow_owner = FALSE), "不支持的成员角色")
  expect_error(service_create_workspace(NULL, "demo", ""), "缺少数据空间负责人")
  expect_error(service_delete_workspace(NULL, ""), "缺少数据空间信息")
  expect_error(service_assign_workspace_owner(NULL, "", ""), "缺少数据空间或负责人信息")
  expect_error(service_upsert_workspace_membership(NULL, "ws_1", "usr_1", "bad_role"), "不支持的成员角色")
  expect_error(service_set_user_status(NULL, "usr_1", "disabled"), "不支持的账号状态")
  expect_error(service_set_user_db_access(NULL, "", TRUE), "缺少用户信息")
})

test_that("预览表格字段使用面向界面的中文名称", {
  memberships <- data.frame(
    username = "alice",
    email = "alice@example.com",
    role = "editor",
    status = "active",
    created_at = "2026-04-10 12:00:00",
    stringsAsFactors = FALSE
  )
  invites <- data.frame(
    invited_email = "bob@example.com",
    target_role = "viewer",
    status = "pending",
    claimed_username = "",
    created_at = "2026-04-10 12:00:00",
    claimed_at = "",
    stringsAsFactors = FALSE
  )
  membership_preview <- service_membership_preview_df(memberships)
  invite_preview <- service_invite_preview_df(invites)
  expect_equal(names(membership_preview), c("成员账号", "联系邮箱", "协作权限", "账号状态", "加入时间"))
  expect_equal(names(invite_preview), c("受邀邮箱", "待授权限", "邀请状态", "领取账号", "发起时间", "领取时间"))
  expect_equal(membership_preview$协作权限[[1]], "可编辑成员")
  expect_equal(invite_preview$邀请状态[[1]], "待领取")
})

test_that("workspace 写权限角色只开放给可编辑成员与负责人", {
  expect_true(service_role_can_write_workspace("owner"))
  expect_true(service_role_can_write_workspace("editor"))
  expect_false(service_role_can_write_workspace("viewer"))
  expect_false(service_role_can_write_workspace(""))
  expect_false(service_role_can_write_workspace(NA_character_))
})

test_that("服务层守卫不再给管理员自动放开全部数据空间", {
  expect_match(account_service_text, "service_list_manageable_workspaces <- function")
  expect_match(account_service_text, "WHERE owner_user_id = \\$1")
  expect_false(grepl("return\\(service_list_workspaces\\(pool\\)\\)", account_service_text))
  expect_false(grepl("isTRUE\\(user\\$is_admin\\) \\|\\|", account_service_text))
  expect_match(account_service_text, "db_access_enabled")
  expect_match(account_service_text, "auth_with_transaction\\(")
})

