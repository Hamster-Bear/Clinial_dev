library(testthat)

root_dir <- normalizePath(file.path(".."), winslash = "/", mustWork = TRUE)

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

read_bytes <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, what = "raw", n = file.info(path)$size)
}

test_that("deploy_from_tar.sh 支持 apps 目录回退", {
  script_path <- file.path(root_dir, "deploy", "alicloud", "scripts", "deploy_from_tar.sh")
  txt <- read_text(script_path)

  expect_match(txt, 'APPS_DIR="\\$\\{APPS_DIR:-\\$ROOT_DIR/apps\\}"')
  expect_match(txt, 'find "\\$APPS_DIR" -maxdepth 1 -type f -name "\\*\\.tar"')
  expect_match(txt, 'if \\[\\[ -f "\\$APPS_DIR/\\$input" \\]\\]')
})

test_that("init_env.sh 会初始化 apps 目录", {
  script_path <- file.path(root_dir, "deploy", "alicloud", "scripts", "init_env.sh")
  txt <- read_text(script_path)

  expect_match(txt, 'APPS_DIR="\\$ROOT_DIR/apps"')
  expect_match(txt, 'mkdir -p "\\$APPS_DIR"')
})

test_that("publish_release.sh 串联构建、导出、上传和远端部署", {
  script_path <- file.path(root_dir, "deploy", "alicloud", "scripts", "publish_release.sh")
  txt <- read_text(script_path)

  expect_match(txt, 'LOCAL_APPS_DIR="\\$\\{LOCAL_APPS_DIR:-\\$ROOT_DIR/apps\\}"')
  expect_match(txt, 'REMOTE_APPS_DIR="\\$\\{REMOTE_APPS_DIR:-\\$REMOTE_ROOT/apps\\}"')
  expect_match(txt, 'docker build -t "\\$IMAGE_NAME" "\\$ROOT_DIR"')
  expect_match(txt, 'docker save -o "\\$BUNDLE_PATH" "\\$IMAGE_NAME"')
  expect_match(txt, 'scp "\\$BUNDLE_PATH" "\\$SHA_PATH" "\\$SUMMARY_PATH"')
  expect_match(txt, 'bash deploy/alicloud/scripts/deploy_from_tar.sh')
})

test_that("部署文档与快速入口文档引用 apps 路径和发布脚本", {
  deployment_path <- file.path(root_dir, "DEPLOYMENT_GUIDE.md")
  quick_path <- file.path(root_dir, "deploy", "alicloud", "README.md")

  deployment_txt <- read_text(deployment_path)
  quick_txt <- read_text(quick_path)

  expect_match(deployment_txt, "/opt/hamster-analysis/current/apps", fixed = TRUE)
  expect_match(deployment_txt, "publish_release.sh", fixed = TRUE)
  expect_match(quick_txt, "/opt/hamster-analysis/current/apps", fixed = TRUE)
  expect_match(quick_txt, "publish_release.sh", fixed = TRUE)
})

test_that("Linux Bash 脚本统一使用 LF 换行", {
  script_paths <- c(
    file.path(root_dir, "deploy", "alicloud", "scripts", "init_env.sh"),
    file.path(root_dir, "deploy", "alicloud", "scripts", "deploy_from_tar.sh"),
    file.path(root_dir, "deploy", "alicloud", "scripts", "publish_release.sh"),
    file.path(root_dir, "deploy", "alicloud", "scripts", "setup_docker_mirror.sh")
  )

  for (script_path in script_paths) {
    bytes <- read_bytes(script_path)
    expect_false(
      as.raw(13) %in% bytes,
      info = paste("脚本存在 CR 字节，可能导致 Linux Bash 执行异常:", basename(script_path))
    )
  }
})
