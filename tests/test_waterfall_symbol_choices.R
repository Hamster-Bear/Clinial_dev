library(testthat)

source(file.path("..", "modules", "common", "graphics_common.R"))
source(file.path("..", "modules", "statistical_graphics", "waterfall_plot.R"))

test_that(".waterfall_symbol_choices 提供可选具体符号集合", {
  choices <- .waterfall_symbol_choices()
  expect_gte(length(choices), 8)
  expect_true(all(nzchar(unname(choices))))
  expect_equal(unname(choices)[[1]], "★")
})
