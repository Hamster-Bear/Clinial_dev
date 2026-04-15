library(testthat)
library(shiny)

source(file.path("..", "modules", "common", "graphics_common.R"))
source(file.path("..", "modules", "statistical_graphics", "survival_analysis.R"))

test_that("未点击生成时切换筛选后下拉不闪回", {
  d1 <- data.frame(
    time_a = c(5, 8, 12, 20),
    time_b = c(6, 9, 13, 21),
    status = c(1, 0, 1, 0),
    grp = factor(c("A", "B", "A", "B")),
    stringsAsFactors = FALSE
  )
  data_rv <- reactiveVal(d1)
  testServer(
    function(input, output, session) {
      survival_analysis_server(input, output, session, data = reactive(data_rv()))
    },
    {
      session$setInputs(km_time = "time_b", km_status = "status", strata_var = "grp", facet_var = "None")
      session$flushReact()
      expect_equal(input$km_time, "time_b")
      expect_equal(input$km_status, "status")
      d2 <- d1
      d2$time_a <- d2$time_a + 1
      d2$time_b <- d2$time_b + 1
      data_rv(d2)
      session$flushReact()
      expect_equal(input$km_time, "time_b")
      expect_equal(input$km_status, "status")
      session$setInputs(strata_var = "None", facet_var = "None")
      session$flushReact()
      session$setInputs(overall_group_label = "Overall", line_type = "dashed", line_size = 1.2, km_censor_value = "0", render_km_plot = 1)
      session$flushReact()
      expect_equal(input$line_type, "dashed")
      expect_equal(input$overall_group_label, "Overall")
      session$setInputs(facet_var = "grp", facet_value = "missing", render_km_plot = 2)
      session$flushReact()
      expect_equal(input$overall_group_label, "Overall")
    }
  )
})

test_that("时间范围滑轴选中值解析遵循公共规则", {
  expect_equal(
    graphics_resolve_time_range_slider_value(c(0, 12), time_range_max = 50, min_value = 0),
    c(0, 12)
  )
  expect_equal(
    graphics_resolve_time_range_slider_value(c(20, 5), time_range_max = 50, min_value = 0),
    c(5, 20)
  )
  expect_equal(
    graphics_resolve_time_range_slider_value(c(-5, 80), time_range_max = 50, min_value = 0),
    c(0, 50)
  )
  expect_equal(
    graphics_resolve_time_range_slider_value(NULL, time_range_max = 50, min_value = 0),
    c(0, 50)
  )
})
