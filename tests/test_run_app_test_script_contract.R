library(testthat)

root_dir <- normalizePath(file.path(".."), winslash = "/", mustWork = TRUE)

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
  expect_match(txt, 'Write-Host "SHINY_PORT=\\$shinyPort"')
})
