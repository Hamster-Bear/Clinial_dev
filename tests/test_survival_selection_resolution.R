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
