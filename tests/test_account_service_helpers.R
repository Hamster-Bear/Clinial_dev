library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- if (length(script_path) > 0 && nzchar(script_path)) {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (basename(wd) == "tests") normalizePath(file.path(wd, ".."), winslash = "/", mustWork = TRUE) else wd
}

account_service_path <- file.path(project_root, "modules", "common", "account_service.R")
if (length(account_service_path) > 0 && file.exists(account_service_path)) {
  source(account_service_path)
} else {
  return(invisible(NULL))
}

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

test_that("分析状态辅助函数规范化 scope 与 payload", {
  expect_equal(service_normalize_analysis_state_scope("graphics"), "graphics")
  expect_error(service_normalize_analysis_state_scope("tables"), "不支持的分析状态范围")
  expect_equal(service_normalize_analysis_state_name("  km-default  "), "km-default")
  expect_error(service_normalize_analysis_state_name("   "), "请输入任务名称")
  expect_null(service_normalize_analysis_state_note(NULL))
  expect_null(service_normalize_analysis_state_note("   "))
  expect_equal(service_normalize_analysis_state_note("  need review  "), "need review")
  expect_equal(service_analysis_state_db_scalar(NULL), NA_character_)
  expect_equal(service_analysis_state_db_scalar(character(0)), NA_character_)
  expect_equal(service_analysis_state_db_scalar("note"), "note")
  expect_null(service_normalize_analysis_state_workspace_id(NULL))
  expect_null(service_normalize_analysis_state_workspace_id(character(0)))
  expect_null(service_normalize_analysis_state_workspace_id(""))
  expect_equal(service_normalize_analysis_state_workspace_id(c("ws_1", "ws_2")), "ws_1")

  payload_json <- service_normalize_analysis_state_payload(list(time_var = "AVAL", x_break_step = 4))
  payload <- service_parse_analysis_state_payload(payload_json)
  expect_equal(payload$time_var, "AVAL")
  expect_equal(payload$x_break_step, 4)
})

test_that("分析状态插入规格在个人任务场景下不绑定 workspace 参数", {
  personal_spec <- service_build_analysis_state_insert_spec(
    state_id = "ast_1",
    user_id = "usr_1",
    workspace_id = NULL,
    scope = "graphics",
    module_type = "km",
    state_name = "demo-task",
    state_note = "note-a",
    state_payload = "{\"a\":1}"
  )
  expect_match(personal_spec$sql, "VALUES \\(\\$1, \\$2, NULL, \\$3, \\$4, \\$5, \\$6, \\$7, NOW\\(\\), NOW\\(\\)\\)")
  expect_length(personal_spec$params, 7)
  expect_false(any(vapply(personal_spec$params, is.null, logical(1))))
  expect_equal(personal_spec$params[[6]], "note-a")

  personal_spec_empty_note <- service_build_analysis_state_insert_spec(
    state_id = "ast_3",
    user_id = "usr_1",
    workspace_id = NULL,
    scope = "graphics",
    module_type = "km",
    state_name = "demo-task",
    state_note = NULL,
    state_payload = "{\"a\":1}"
  )
  expect_length(personal_spec_empty_note$params, 7)
  expect_true(is.na(personal_spec_empty_note$params[[6]]))

  workspace_spec <- service_build_analysis_state_insert_spec(
    state_id = "ast_2",
    user_id = "usr_1",
    workspace_id = c("ws_1", "ws_2"),
    scope = "graphics",
    module_type = "km",
    state_name = "demo-task",
    state_note = "note-b",
    state_payload = "{\"a\":1}"
  )
  expect_match(workspace_spec$sql, "VALUES \\(\\$1, \\$2, \\$3, \\$4, \\$5, \\$6, \\$7, \\$8, NOW\\(\\), NOW\\(\\)\\)")
  expect_length(workspace_spec$params, 8)
  expect_equal(workspace_spec$params[[3]], "ws_1")
  expect_equal(workspace_spec$params[[7]], "note-b")
})
