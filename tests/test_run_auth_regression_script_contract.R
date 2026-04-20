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

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

test_that("run_auth_regression.ps1 会校验环境并串联关键测试", {
  script_path <- file.path(project_root, "run_auth_regression.ps1")
  txt <- read_text(script_path)

  expect_match(txt, "Load-EnvFile", fixed = TRUE)
  expect_match(txt, "Assert-RequiredEnvVars", fixed = TRUE)
  expect_match(txt, "Invoke-RTestScript", fixed = TRUE)
  expect_match(txt, 'APP_ADMIN_USERNAME')
  expect_match(txt, 'APP_ADMIN_EMAIL')
  expect_match(txt, 'APP_ADMIN_PASSWORD')
  expect_match(txt, 'AUTH_REQUIRE_EMAIL_VERIFICATION')
  expect_match(txt, 'EMAIL_DELIVERY_MODE')
  expect_match(txt, 'EMAIL_FROM_ADDRESS')
  expect_match(txt, 'SMTP_HOST')
  expect_match(txt, 'SMTP_PORT')
  expect_match(txt, 'AUTH_DEV_SHOW_EMAIL_CODE')
  expect_match(txt, 'AUTH_PASSWORD_RESET_EXPIRE_MINUTES')
  expect_match(txt, 'tests/test_email_service_helpers.R', fixed = TRUE)
  expect_match(txt, 'tests/test_auth_helpers.R', fixed = TRUE)
  expect_match(txt, 'tests/test_account_service_helpers.R', fixed = TRUE)
  expect_match(txt, 'tests/test_workspace_access_manager_guard.R', fixed = TRUE)
  expect_match(txt, 'tests/test_access_boundary_guard.R', fixed = TRUE)
  expect_match(txt, 'tests/test_project_docs_guard.R', fixed = TRUE)
  expect_match(txt, 'tests/test_auth_access_postgres_integration.R', fixed = TRUE)
  expect_match(txt, "账号模块回归测试全部通过。", fixed = TRUE)
})
