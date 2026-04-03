library(testthat)

source(file.path("..", "modules", "statistical_graphics", "survival_analysis.R"))

test_that(".resolve_survival_choice 优先保留当前输入值", {
  choices <- c("time", "status", "age")
  out <- .resolve_survival_choice(
    input_value = "status",
    state_value = "time",
    choices = choices,
    default_value = "age"
  )
  expect_equal(out, "status")
})

test_that(".resolve_survival_choice 在输入无效时回退 state/default", {
  choices <- c("time", "status")
  out_state <- .resolve_survival_choice(
    input_value = "invalid",
    state_value = "status",
    choices = choices,
    default_value = "time"
  )
  expect_equal(out_state, "status")
  out_default <- .resolve_survival_choice(
    input_value = "invalid",
    state_value = "missing",
    choices = choices,
    default_value = "time"
  )
  expect_equal(out_default, "time")
})

test_that(".resolve_survival_choice 在无选项时回退默认值", {
  out <- .resolve_survival_choice(
    input_value = "a",
    state_value = "b",
    choices = character(0),
    default_value = "c"
  )
  expect_equal(out, "c")
  out_null <- .resolve_survival_choice(
    input_value = "a",
    state_value = "b",
    choices = character(0),
    default_value = NULL
  )
  expect_null(out_null)
})

test_that("总体标签与图例标签解析一致", {
  expect_equal(
    .format_survival_group_label("all", overall_label = "Overall"),
    "Overall"
  )
  expect_equal(
    .format_survival_group_label("arm=A", strata_var = "arm", strata_labels = list(A = "Treatment A"), overall_label = "Overall"),
    "Treatment A"
  )
  expect_equal(
    .extract_survival_legend_labs(list(strata = NULL), overall_label = "Overall"),
    "Overall"
  )
})

test_that("线条样式应用到现有生存曲线图层", {
  p <- ggplot2::ggplot(data.frame(x = c(0, 1), y = c(1, 0.8)), ggplot2::aes(x, y)) +
    ggplot2::geom_step()
  out <- .apply_survival_line_style(p, line_size = 1.4, line_type = "dashed")
  expect_equal(out$layers[[1]]$aes_params$linetype, "dashed")
  expect_equal(out$layers[[1]]$aes_params$linewidth, 1.4)
})
