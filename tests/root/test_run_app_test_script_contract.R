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
root_dir <- test_find_project_root()

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

test_that("run_app_test.ps1 启动前会清理目标端口", {
  script_path <- file.path(root_dir, "run_app_test.ps1")
  txt <- read_text(script_path)

  expect_match(txt, "function Resolve-ShinyPort", fixed = TRUE)
  expect_match(txt, "return 8109", fixed = TRUE)
  expect_match(txt, "Get-NetTCPConnection -LocalPort \\$Port -ErrorAction SilentlyContinue")
  expect_match(txt, "Stop-Process -Id \\$processId -Force -ErrorAction Stop")
  expect_match(txt, "Stop-ProcessesByPort -Port \\$shinyPort")
  expect_match(txt, "function Get-AdminBootstrapState", fixed = TRUE)
  expect_match(txt, "APP_ADMIN_USERNAME / APP_ADMIN_EMAIL / APP_ADMIN_PASSWORD 必须同时提供", fixed = TRUE)
  expect_match(txt, 'Write-Host \\("ADMIN_BOOTSTRAP=\\{0\\}" -f \\(Get-AdminBootstrapState\\)\\)')
  expect_match(txt, 'Write-Host "SHINY_PORT=\\$shinyPort"')
  expect_match(txt, "docker-compose.local.yml", fixed = TRUE)
  expect_match(txt, "docker-compose1.yml", fixed = TRUE)
  expect_match(txt, "POSTGRES_PORT 使用 5432", fixed = TRUE)
})



