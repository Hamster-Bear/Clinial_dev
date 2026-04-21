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
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

test_that("run_auth_regression.ps1 会校验环境并串联关键测试", {
  script_path <- file.path(project_root, "run_auth_regression.ps1")
  txt <- read_text(script_path)
  manifest_path <- file.path(project_root, "tests", "common", "auth", "auth_regression_manifest.json")
  manifest_txt <- read_text(manifest_path)

  expect_match(txt, "Load-EnvFile", fixed = TRUE)
  expect_match(txt, "Assert-RequiredEnvVars", fixed = TRUE)
  expect_match(txt, "Invoke-RTestScript", fixed = TRUE)
  expect_match(txt, "Get-TestScriptsFromManifest", fixed = TRUE)
  expect_match(txt, "ConvertFrom-Json", fixed = TRUE)
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
  expect_match(txt, 'auth_regression_manifest.json', fixed = TRUE)
  expect_match(txt, 'AUTH_REGRESSION_MANIFEST', fixed = TRUE)
  expect_match(manifest_txt, 'tests/common/auth/test_email_service_helpers.R', fixed = TRUE)
  expect_match(manifest_txt, 'tests/common/auth/test_auth_helpers.R', fixed = TRUE)
  expect_match(manifest_txt, 'tests/common/auth/test_account_service_helpers.R', fixed = TRUE)
  expect_match(manifest_txt, 'tests/workspace_access_manager/test_workspace_access_manager_guard.R', fixed = TRUE)
  expect_match(manifest_txt, 'tests/root/test_access_boundary_guard.R', fixed = TRUE)
  expect_match(manifest_txt, 'tests/root/test_project_docs_guard.R', fixed = TRUE)
  expect_match(manifest_txt, 'tests/common/auth/test_auth_access_postgres_integration.R', fixed = TRUE)
  expect_match(txt, "账号模块回归测试全部通过。", fixed = TRUE)
})




