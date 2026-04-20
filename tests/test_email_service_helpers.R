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

email_service_path <- file.path(project_root, "modules", "common", "email_service.R")
if (file.exists(email_service_path)) {
  source(email_service_path, local = TRUE)
} else {
  return(invisible(NULL))
}
email_service_text <- paste(readLines(email_service_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

with_env_vars <- function(vars, code) {
  old_values <- Sys.getenv(names(vars), unset = NA_character_)
  on.exit({
    for (key in names(old_values)) {
      old_value <- old_values[[key]]
      if (is.na(old_value)) {
        Sys.unsetenv(key)
      } else {
        do.call(Sys.setenv, stats::setNames(list(old_value), key))
      }
    }
  }, add = TRUE)
  for (key in names(vars)) {
    do.call(Sys.setenv, stats::setNames(list(as.character(vars[[key]] %||% "")), key))
  }
  force(code)
}

test_that("email_service 支持 console 和 smtp 配置解析", {
  with_env_vars(
    c(
      EMAIL_DELIVERY_MODE = "smtp",
      EMAIL_FROM_ADDRESS = "noreply@example.com",
      EMAIL_FROM_LABEL = "AutoTFL",
      SMTP_HOST = "smtp.example.com",
      SMTP_PORT = "587",
      SMTP_USERNAME = "mailer",
      SMTP_PASSWORD = "secret",
      SMTP_USE_SSL = "try"
    ),
    {
      expect_identical(email_service_mode(), "smtp")
      validation <- email_service_validate_smtp_config()
      expect_true(isTRUE(validation$valid))
      msg <- rawToChar(email_service_compose_message("user@example.com", "Test", "Hello"))
      expect_match(msg, "Subject: Test", fixed = TRUE)
      expect_match(msg, "Hello", fixed = TRUE)
    }
  )
})

test_that("email_service 在 console 和 disabled 模式下保持可测试行为", {
  with_env_vars(
    c(EMAIL_DELIVERY_MODE = "console", EMAIL_FROM_ADDRESS = "noreply@example.com"),
    {
      result <- email_service_send("user@example.com", "Subject", "Body")
      expect_true(isTRUE(result$success))
      expect_identical(result$mode, "console")
      probe <- email_service_send_probe("user@example.com")
      expect_true(isTRUE(probe$success))
      summary_text <- email_service_probe_summary()
      expect_match(summary_text, "邮件模式: console", fixed = TRUE)
    }
  )
  with_env_vars(
    c(EMAIL_DELIVERY_MODE = "disabled"),
    {
      result <- email_service_send("user@example.com", "Subject", "Body")
      expect_true(isTRUE(result$success))
      expect_identical(result$mode, "disabled")
    }
  )
})

test_that("email_service 守卫真实发信配置入口", {
  expect_match(email_service_text, "email_service_send <- function")
  expect_match(email_service_text, "email_service_send_probe <- function")
  expect_match(email_service_text, "email_service_probe_summary <- function")
  expect_match(email_service_text, "EMAIL_DELIVERY_MODE")
  expect_match(email_service_text, "SMTP_HOST")
  expect_match(email_service_text, "curl::send_mail")
  expect_match(email_service_text, "EMAIL_FROM_ADDRESS")
})
