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

auth_path <- file.path(project_root, "modules", "common", "auth", "auth.R")
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

test_that("邮箱验证配置与验证码 helper 可用", {
  old_required <- Sys.getenv("AUTH_REQUIRE_EMAIL_VERIFICATION", unset = NA_character_)
  old_show <- Sys.getenv("AUTH_DEV_SHOW_EMAIL_CODE", unset = NA_character_)
  old_mode <- Sys.getenv("EMAIL_DELIVERY_MODE", unset = NA_character_)
  on.exit({
    if (is.na(old_required)) Sys.unsetenv("AUTH_REQUIRE_EMAIL_VERIFICATION") else Sys.setenv(AUTH_REQUIRE_EMAIL_VERIFICATION = old_required)
    if (is.na(old_show)) Sys.unsetenv("AUTH_DEV_SHOW_EMAIL_CODE") else Sys.setenv(AUTH_DEV_SHOW_EMAIL_CODE = old_show)
    if (is.na(old_mode)) Sys.unsetenv("EMAIL_DELIVERY_MODE") else Sys.setenv(EMAIL_DELIVERY_MODE = old_mode)
  }, add = TRUE)

  Sys.setenv(AUTH_REQUIRE_EMAIL_VERIFICATION = "0", AUTH_DEV_SHOW_EMAIL_CODE = "1", EMAIL_DELIVERY_MODE = "console")
  expect_false(auth_email_verification_required())
  expect_true(auth_dev_show_email_code())
  code <- auth_generate_verification_code()
  expect_match(code, "^[0-9]{6}$")
  expect_identical(auth_hash_token("123456"), auth_hash_token("123456"))
  delivery <- auth_deliver_email_verification("demo@example.com", code, purpose = "register")
  expect_true(isTRUE(delivery$success))
  expect_identical(delivery$preview_code, code)
  reset_delivery <- auth_deliver_password_reset("demo@example.com", code)
  expect_true(isTRUE(reset_delivery$success))
  expect_identical(reset_delivery$preview_code, code)
})

test_that("SMTP 投递模式不会在界面消息中泄露验证码", {
  old_show <- Sys.getenv("AUTH_DEV_SHOW_EMAIL_CODE", unset = NA_character_)
  old_mode <- Sys.getenv("EMAIL_DELIVERY_MODE", unset = NA_character_)
  old_sender <- if (exists("email_service_send", mode = "function")) get("email_service_send") else NULL
  on.exit({
    if (is.na(old_show)) Sys.unsetenv("AUTH_DEV_SHOW_EMAIL_CODE") else Sys.setenv(AUTH_DEV_SHOW_EMAIL_CODE = old_show)
    if (is.na(old_mode)) Sys.unsetenv("EMAIL_DELIVERY_MODE") else Sys.setenv(EMAIL_DELIVERY_MODE = old_mode)
    if (!is.null(old_sender)) assign("email_service_send", old_sender, envir = .GlobalEnv)
  }, add = TRUE)

  assign("email_service_send", function(...) list(success = TRUE, message = "sent"), envir = .GlobalEnv)
  Sys.setenv(AUTH_DEV_SHOW_EMAIL_CODE = "0", EMAIL_DELIVERY_MODE = "smtp")
  code <- "123456"

  delivery <- auth_deliver_email_verification("demo@example.com", code, purpose = "register")
  expect_true(isTRUE(delivery$success))
  expect_identical(delivery$delivery_mode, "smtp")
  expect_null(delivery$preview_code)
  expect_false(grepl(code, delivery$message, fixed = TRUE))

  reset_delivery <- auth_deliver_password_reset("demo@example.com", code)
  expect_true(isTRUE(reset_delivery$success))
  expect_identical(reset_delivery$delivery_mode, "smtp")
  expect_null(reset_delivery$preview_code)
  expect_false(grepl(code, reset_delivery$message, fixed = TRUE))
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
    email_verified_at = as.POSIXct("2024-01-01", tz = "UTC"),
    is_admin = FALSE,
    db_access_enabled = TRUE,
    stringsAsFactors = FALSE
  ))
  expect_true(isTRUE(payload$db_access_enabled))
  expect_true(isTRUE(payload$email_verified))
  admin_payload <- auth_build_user_payload(data.frame(
    id = "u2",
    username = "admin",
    email = "admin@example.com",
    email_verified_at = as.POSIXct(NA),
    is_admin = TRUE,
    db_access_enabled = FALSE,
    stringsAsFactors = FALSE
  ))
  expect_true(isTRUE(admin_payload$db_access_enabled))
  expect_false(isTRUE(admin_payload$email_verified))
})

test_that("认证策略守卫收紧管理员初始化与workspace访问", {
  expect_match(auth_source_text, 'message = "注册成功，请登录。登录后可在用户信息中自行验证邮箱。"', fixed = TRUE)
  expect_false(grepl("当前账号已成为系统管理员", auth_source_text, fixed = TRUE))
  expect_match(auth_source_text, "auth_with_transaction <- function")
  expect_match(auth_source_text, "pool::poolWithTransaction")
  expect_match(auth_source_text, "auth_resolve_bootstrap_admin_env <- function")
  expect_match(auth_source_text, "auth_issue_email_verification <- function")
  expect_match(auth_source_text, "auth_verify_email_code <- function")
  expect_match(auth_source_text, "auth_request_current_email_verification <- function")
  expect_match(auth_source_text, "auth_request_password_reset <- function")
  expect_match(auth_source_text, "auth_reset_password <- function")
  expect_match(auth_source_text, "auth_change_password <- function")
  expect_match(auth_source_text, "auth_request_email_change <- function")
  expect_match(auth_source_text, "auth_confirm_email_change <- function")
  expect_match(auth_source_text, "email_service_send")
  expect_match(auth_source_text, "AUTH_REQUIRE_EMAIL_VERIFICATION")
  expect_match(auth_source_text, "AUTH_PASSWORD_RESET_EXPIRE_MINUTES")
  expect_match(auth_source_text, "APP_ADMIN_USERNAME、APP_ADMIN_EMAIL 和 APP_ADMIN_PASSWORD")
  expect_match(auth_source_text, "APP_ADMIN_EMAIL 与 APP_ADMIN_USERNAME 分别命中不同账号")
  expect_match(
    auth_source_text,
    "if \\(provided_count == 0\\)"
  )
  expect_false(grepl("if \\(isTRUE\\(is_admin\\)\\)", auth_source_text))
})

