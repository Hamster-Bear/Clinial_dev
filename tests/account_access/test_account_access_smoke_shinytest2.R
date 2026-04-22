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

load_env_file <- function(file_path) {
  if (!file.exists(file_path)) {
    return(invisible(FALSE))
  }
  lines <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
  for (line in lines) {
    trimmed <- trimws(line)
    if (!nzchar(trimmed) || startsWith(trimmed, "#")) {
      next
    }
    idx <- regexpr("=", trimmed, fixed = TRUE)[[1]]
    if (idx <= 1) {
      next
    }
    key <- trimws(substr(trimmed, 1, idx - 1))
    value <- trimws(substr(trimmed, idx + 1, nchar(trimmed)))
    do.call(Sys.setenv, stats::setNames(list(value), key))
  }
  invisible(TRUE)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

wait_until <- function(check_fn, timeout = 20, interval = 0.5) {
  deadline <- Sys.time() + timeout
  repeat {
    value <- tryCatch(check_fn(), error = function(e) NULL)
    if (!is.null(value) && !identical(value, FALSE)) {
      return(value)
    }
    if (Sys.time() >= deadline) {
      return(NULL)
    }
    Sys.sleep(interval)
  }
}

skip_if_account_access_smoke_not_enabled <- function() {
  if (!identical(Sys.getenv("RUN_ACCOUNT_ACCESS_SMOKE", ""), "1")) {
    skip("未设置 RUN_ACCOUNT_ACCESS_SMOKE=1，跳过账号页 shinytest2 smoke test")
  }
}

skip_if_missing_env <- function() {
  required_env <- c(
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "ACCOUNT_SMOKE_USERNAME",
    "ACCOUNT_SMOKE_PASSWORD"
  )
  values <- Sys.getenv(required_env, "")
  if (any(!nzchar(values))) {
    skip("缺少账号页 smoke test 所需环境变量，跳过验证")
  }
}

load_env_file(file.path(project_root, ".env.test"))

test_that("普通用户可切换到聚合后的用户信息与权限管理页", {
  skip_if_not_installed("shinytest2")
  skip_if_account_access_smoke_not_enabled()
  skip_if_missing_env()

  app <- shinytest2::AppDriver$new(
    app_dir = project_root,
    name = "account-access-smoke",
    load_timeout = 30000,
    height = 1200,
    width = 1600
  )
  on.exit(app$stop(), add = TRUE)

  app$set_inputs(
    `auth-login_identity` = Sys.getenv("ACCOUNT_SMOKE_USERNAME"),
    `auth-login_password` = Sys.getenv("ACCOUNT_SMOKE_PASSWORD")
  )
  app$click("auth-login_submit")

  logged_in_tab <- wait_until(function() {
    tab_value <- app$get_value(input = "tabs")
    if (identical(tab_value, "db_manage") || identical(tab_value, "data_prep")) {
      tab_value
    } else {
      NULL
    }
  }, timeout = 30)
  expect_true(!is.null(logged_in_tab))

  app$set_inputs(tabs = "user_profile")
  profile_tab <- wait_until(function() {
    tab_value <- app$get_value(input = "tabs")
    if (identical(tab_value, "user_profile")) tab_value else NULL
  }, timeout = 15)
  expect_identical(profile_tab, "user_profile")

  profile_html <- wait_until(function() {
    html <- app$get_html("#shiny-tab-user_profile")
    if (nzchar(html) && grepl("账号概览", html, fixed = TRUE) && grepl("安全与验证", html, fixed = TRUE)) {
      html
    } else {
      NULL
    }
  }, timeout = 20)
  expect_match(profile_html %||% "", "账号概览", fixed = TRUE)
  expect_match(profile_html %||% "", "安全与验证", fixed = TRUE)
  expect_true(
    grepl("验证邮箱", profile_html %||% "", fixed = TRUE) ||
      grepl("邮箱换绑", profile_html %||% "", fixed = TRUE) ||
      grepl("修改密码", profile_html %||% "", fixed = TRUE)
  )

  app$set_inputs(tabs = "access_permissions")
  permission_tab <- wait_until(function() {
    tab_value <- app$get_value(input = "tabs")
    if (identical(tab_value, "access_permissions")) tab_value else NULL
  }, timeout = 15)
  expect_identical(permission_tab, "access_permissions")

  permission_html <- wait_until(function() {
    html <- app$get_html("#shiny-tab-access_permissions")
    if (nzchar(html) && (
      grepl("协作工作台", html, fixed = TRUE) ||
      grepl("我的已授权空间", html, fixed = TRUE) ||
      grepl("当前暂无可管理空间或已授权空间", html, fixed = TRUE)
    )) {
      html
    } else {
      NULL
    }
  }, timeout = 20)
  expect_true(nzchar(permission_html %||% ""))
  expect_true(
    grepl("协作工作台", permission_html %||% "", fixed = TRUE) ||
      grepl("我的已授权空间", permission_html %||% "", fixed = TRUE) ||
      grepl("当前暂无可管理空间或已授权空间", permission_html %||% "", fixed = TRUE)
  )
})
