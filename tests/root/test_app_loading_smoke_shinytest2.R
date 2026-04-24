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

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

skip_if_loading_smoke_not_enabled <- function() {
  if (!identical(Sys.getenv("RUN_APP_LOADING_SMOKE", ""), "1")) {
    skip("未设置 RUN_APP_LOADING_SMOKE=1，跳过应用首屏 loading smoke test")
  }
}

wait_until <- function(check_fn, timeout = 20, interval = 0.5) {
  deadline <- Sys.time() + timeout
  last_value <- NULL
  repeat {
    last_value <- tryCatch(check_fn(), error = function(e) NULL)
    if (!is.null(last_value) && !identical(last_value, FALSE)) {
      return(last_value)
    }
    if (Sys.time() >= deadline) {
      return(NULL)
    }
    Sys.sleep(interval)
  }
}

test_that("应用首屏 loading 结构存在且最终进入登录页", {
  skip_if_not_installed("shinytest2")
  skip_if_loading_smoke_not_enabled()

  app <- shinytest2::AppDriver$new(
    app_dir = project_root,
    name = "app-loading-smoke",
    load_timeout = 30000,
    height = 1000,
    width = 1440
  )
  on.exit(app$stop(), add = TRUE)

  body_html <- wait_until(function() {
    html <- app$get_html("body")
    if (nzchar(html) && grepl("app-loading-overlay", html, fixed = TRUE)) {
      html
    } else {
      NULL
    }
  }, timeout = 20)
  expect_match(body_html %||% "", "app-loading-overlay", fixed = TRUE)
  expect_match(body_html %||% "", "应用加载中", fixed = TRUE)

  login_tab <- wait_until(function() {
    tab_value <- app$get_value(input = "tabs")
    if (identical(tab_value, "login")) {
      tab_value
    } else {
      NULL
    }
  }, timeout = 20)
  expect_identical(login_tab, "login")

  login_html <- wait_until(function() {
    html <- app$get_html("#shiny-tab-login")
    if (nzchar(html) && grepl("用户名或邮箱", html, fixed = TRUE)) {
      html
    } else {
      NULL
    }
  }, timeout = 20)
  expect_match(login_html %||% "", "用户名或邮箱", fixed = TRUE)
})
