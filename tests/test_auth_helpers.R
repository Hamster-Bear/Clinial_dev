library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

auth_path <- file.path(project_root, "modules", "common", "auth.R")
if (length(auth_path) > 0 && file.exists(auth_path)) {
  source(auth_path)
} else {
  return(invisible(NULL))
}
auth_source_text <- paste(readLines(auth_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("密码摘要可验证且错误密码无法通过", {
  salt <- auth_generate_salt()
  password_hash <- auth_hash_password("StrongPass123", salt)
  expect_true(auth_verify_password("StrongPass123", salt, password_hash))
  expect_false(auth_verify_password("WrongPass123", salt, password_hash))
})

test_that("用户名、邮箱与密码校验遵循最小规则", {
  expect_match(auth_validate_username(""), "请输入用户名")
  expect_match(auth_validate_username("AA"), "用户名仅支持")
  expect_null(auth_validate_username("user_01"))
  expect_match(auth_validate_email(""), "请输入邮箱")
  expect_match(auth_validate_email("user.example.com"), "邮箱格式不正确")
  expect_null(auth_validate_email("user@example.com"))
  expect_match(auth_validate_password("1234567"), "密码至少需要 8 位")
  expect_null(auth_validate_password("12345678"))
})

test_that("非管理员 registry 过滤仅保留授权 workspace", {
  reg <- list(
    workspaces = data.frame(
      id = c("ws_1", "ws_2"),
      name = c("A", "B"),
      owner_user_id = c("u1", "u2"),
      created_at = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    folders = data.frame(
      id = c("fd_1", "fd_2"),
      workspace_id = c("ws_1", "ws_2"),
      name = c("root-a", "root-b"),
      created_at = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    datasets = data.frame(
      id = c("ds_1", "ds_2"),
      workspace_id = c("ws_1", "ws_2"),
      folder_id = c(NA_character_, NA_character_),
      name = c("data-a", "data-b"),
      file_name = c("a.csv", "b.csv"),
      data_path = c("a.rds", "b.rds"),
      nrow = c(10, 20),
      ncol = c(3, 4),
      created_at = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
      stringsAsFactors = FALSE
    )
  )

  filtered <- auth_filter_registry(reg, workspace_ids = "ws_1", is_admin = FALSE)
  expect_equal(filtered$workspaces$id, "ws_1")
  expect_equal(filtered$folders$workspace_id, "ws_1")
  expect_equal(filtered$datasets$workspace_id, "ws_1")
})

test_that("用户载荷包含数据库管理开关", {
  payload <- auth_build_user_payload(data.frame(
    id = "u1",
    username = "demo",
    email = "demo@example.com",
    is_admin = FALSE,
    db_access_enabled = TRUE,
    stringsAsFactors = FALSE
  ))
  expect_true(isTRUE(payload$db_access_enabled))
  admin_payload <- auth_build_user_payload(data.frame(
    id = "u2",
    username = "admin",
    email = "admin@example.com",
    is_admin = TRUE,
    db_access_enabled = FALSE,
    stringsAsFactors = FALSE
  ))
  expect_true(isTRUE(admin_payload$db_access_enabled))
})

test_that("认证策略守卫收紧管理员初始化与workspace访问", {
  expect_match(auth_source_text, 'message = "注册成功，请登录"', fixed = TRUE)
  expect_false(grepl("当前账号已成为系统管理员", auth_source_text, fixed = TRUE))
  expect_match(
    auth_source_text,
    "if \\(!nzchar\\(username\\) \\|\\| !nzchar\\(email\\) \\|\\| !nzchar\\(password\\)\\)"
  )
  expect_false(grepl("if \\(isTRUE\\(is_admin\\)\\)", auth_source_text))
})
