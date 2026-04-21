find_project_root <- function() {
  current <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  repeat {
    if (file.exists(file.path(current, "app.R")) &&
        dir.exists(file.path(current, "modules")) &&
        dir.exists(file.path(current, "tests"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      break
    }
    current <- parent
  }

  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- find_project_root()
setwd(project_root)

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("缺少 testthat，请先安装依赖。", call. = FALSE)
}

testthat::test_file(
  file.path(project_root, "tests", "root", "test_test_guide_index_contract.R"),
  reporter = "summary"
)
