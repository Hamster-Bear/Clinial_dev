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

root_dir <- normalizePath(file.path(".."), winslash = "/", mustWork = TRUE)

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

source(file.path(root_dir, "config", "required_packages.R"))

test_that("依赖清单是安装和离线下载脚本的唯一来源", {
  install_text <- read_text(file.path(root_dir, "install_dependencies.R"))
  offline_text <- read_text(file.path(root_dir, "download_offline_packages.R"))
  binary_text <- read_text(file.path(root_dir, "download_binary_packages.R"))

  expect_match(install_text, "config/required_packages.R", fixed = TRUE)
  expect_match(offline_text, "config/required_packages.R", fixed = TRUE)
  expect_match(binary_text, "config/required_packages.R", fixed = TRUE)
  expect_match(install_text, "required_packages <- REQUIRED_PACKAGES", fixed = TRUE)
  expect_match(binary_text, "required_packages <- REQUIRED_PACKAGES", fixed = TRUE)
})

test_that("依赖清单包含当前安装链路需要的包且无重复", {
  expect_true(is.character(REQUIRED_PACKAGES))
  expect_gt(length(REQUIRED_PACKAGES), 50)
  expect_equal(REQUIRED_PACKAGES, unique(REQUIRED_PACKAGES))
  expect_true(all(c("testthat", "shinytest2", "shinyFiles", "rlang") %in% REQUIRED_PACKAGES))
})

test_that("Docker 构建在运行安装脚本前复制依赖清单目录", {
  docker_text <- read_text(file.path(root_dir, "Dockerfile"))
  expect_match(docker_text, "COPY config /app/config", fixed = TRUE)
  expect_lt(
    regexpr("COPY config /app/config", docker_text, fixed = TRUE)[[1]],
    regexpr("Rscript /app/install_dependencies.R", docker_text, fixed = TRUE)[[1]]
  )
})

test_that("Docker 构建上下文包含依赖清单目录", {
  dockerignore_text <- read_text(file.path(root_dir, ".dockerignore"))
  dockerignore_lines <- trimws(strsplit(dockerignore_text, "\n", fixed = TRUE)[[1]])
  dockerignore_lines <- dockerignore_lines[nzchar(dockerignore_lines)]
  dockerignore_lines <- dockerignore_lines[!startsWith(dockerignore_lines, "#")]

  expect_false("config/" %in% dockerignore_lines)
  expect_false("config" %in% dockerignore_lines)
  expect_true("required_packages.R" %in% list.files(file.path(root_dir, "config"), full.names = FALSE))
})
