library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
root_dir <- if (length(script_path) > 0 && nzchar(script_path)) {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (basename(wd) == "tests") normalizePath(file.path(wd, ".."), winslash = "/", mustWork = TRUE) else wd
}

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
