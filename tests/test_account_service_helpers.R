library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

source(file.path(project_root, "modules", "common", "auth.R"))
source(file.path(project_root, "modules", "common", "account_service.R"))

test_that("管理员服务层对非法输入有防御", {
  expect_error(service_assign_workspace_owner(NULL, "", ""), "缺少数据空间或负责人信息")
  expect_error(service_upsert_workspace_membership(NULL, "ws_1", "usr_1", "bad_role"), "不支持的成员角色")
  expect_error(service_set_user_status(NULL, "usr_1", "disabled"), "不支持的账号状态")
})
