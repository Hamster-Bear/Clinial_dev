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
library(testthat)
source(file.path(project_root, "modules", "common", "export", "table_export.R"))

# ---- format_p_value_ama ----

test_that("format_p_value_ama 极小 P 值", {
  expect_equal(format_p_value_ama(0.0001), "<0.001")
  expect_equal(format_p_value_ama(1e-10), "<0.001")
})

test_that("format_p_value_ama 极大 P 值", {
  expect_equal(format_p_value_ama(0.999), ">0.99")
  expect_equal(format_p_value_ama(1), ">0.99")
})

test_that("format_p_value_ama 正常值三位小数", {
  expect_equal(format_p_value_ama(0.025), "0.025")
  expect_equal(format_p_value_ama(0.5), "0.500")
})

test_that("format_p_value_ama NA 值", {
  expect_equal(format_p_value_ama(NA), "—")
  expect_equal(format_p_value_ama("NA"), "—")
  expect_equal(format_p_value_ama("—"), "—")
  expect_equal(format_p_value_ama(""), "—")
})

# ---- normalize_footnotes ----

test_that("normalize_footnotes NULL 返回空字符", {
  expect_equal(normalize_footnotes(NULL), character(0))
})

test_that("normalize_footnotes 去重去空", {
  result <- normalize_footnotes(c("  note1  ", "", "note1", "note2"))
  expect_equal(result, c("note1", "note2"))
})

# ---- build_table_export_filename ----

test_that("build_table_export_filename 默认格式", {
  fn <- build_table_export_filename("cox_result", "docx")
  expect_true(grepl("^cox_result_.*\\.docx$", fn))
})

test_that("build_table_export_filename 含时间戳", {
  fn <- build_table_export_filename("test", "png", include_time = TRUE)
  expect_true(grepl("^test_.*\\.png$", fn))
  # 含时间戳时应有 HHMMSS
  expect_true(grepl("\\d{8}_\\d{6}", fn))
})

# ---- extract_table_dataframe ----

test_that("extract_table_dataframe data.frame 直接返回", {
  df <- data.frame(a = 1:3, b = letters[1:3])
  result <- extract_table_dataframe(df)
  expect_equal(result, df)
})

test_that("extract_table_dataframe gt_tbl 提取数据", {
  skip_if_not_installed("gt")
  df <- data.frame(x = 1:3, y = c("a", "b", "c"))
  gt_obj <- gt::gt(df)
  result <- extract_table_dataframe(gt_obj)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)
})

# ---- markdown_to_doc_lines ----

test_that("markdown_to_doc_lines 去除标题标记", {
  lines <- markdown_to_doc_lines("## 标题\n正文内容")
  expect_false(any(grepl("^#", lines)))
  expect_true(any(grepl("标题", lines)))
})

test_that("markdown_to_doc_lines 转换列表标记", {
  lines <- markdown_to_doc_lines("- 项目1\n- 项目2")
  expect_true(any(grepl("• 项目1", lines, fixed = TRUE)))
})

test_that("markdown_to_doc_lines 空输入返回空", {
  expect_equal(markdown_to_doc_lines(NULL), character(0))
  expect_equal(markdown_to_doc_lines(""), character(0))
})

test_that("markdown_to_doc_lines 去除反引号", {
  lines <- markdown_to_doc_lines("使用 `lm()` 函数")
  expect_false(any(grepl("`", lines, fixed = TRUE)))
})

# ---- extract_table_for_export ----

test_that("extract_table_for_export 从 list 中提取 table", {
  obj <- list(table = data.frame(x = 1), other = "abc")
  result <- extract_table_for_export(obj)
  expect_true(is.data.frame(result))
})

test_that("extract_table_for_export 非 list 直接返回", {
  df <- data.frame(x = 1)
  result <- extract_table_for_export(df)
  expect_true(is.data.frame(result))
})
