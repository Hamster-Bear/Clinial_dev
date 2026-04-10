library(testthat)
library(shiny)

source(file.path("..", "modules", "common", "graphics_common.R"))
source(file.path("..", "modules", "common", "table_export.R"))
source(file.path("..", "modules", "statistical_graphics", "survival_analysis.R"))

test_that("分层标签解析保留比较符号并兼容反引号变量名", {
  expect_equal(
    .format_survival_group_label("age group=>=65", strata_var = "age group"),
    ">=65"
  )
  expect_equal(
    .format_survival_group_label("`age group`=<65", strata_var = "age group"),
    "<65"
  )
  expect_equal(
    .format_survival_group_label("age group=>=65", strata_var = "age group", strata_labels = list(">=65" = "Older")),
    "Older"
  )
  expect_equal(
    .format_survival_group_label("A=B", strata_var = "arm", strata_labels = list("A=B" = "Ref A=B")),
    "Ref A=B"
  )
})

test_that("风险表标签映射与总体标签走统一格式化链路", {
  labeler <- .build_survival_strata_labeler(
    strata_var = "age group",
    strata_labels = list(">=65" = "Older", "<65" = "Younger"),
    overall_label = "Overall"
  )
  expect_equal(
    unname(labeler(c("age group=>=65", "age group=<65", "all"))),
    c("Older", "Younger", "Overall")
  )
})

test_that("主图图例 breaks 与 labels 走统一解析", {
  fit_obj <- list(strata = c(3, 4))
  names(fit_obj$strata) <- c("age group=>=65", "age group=<65")
  expect_equal(
    .extract_survival_legend_breaks(fit_obj, strata_var = "age group"),
    c("age group=>=65", "age group=<65")
  )
  expect_equal(
    unname(.extract_survival_legend_labs(
      fit_obj,
      strata_var = "age group",
      strata_labels = list(">=65" = "Older", "<65" = "Younger")
    )),
    c("Older", "Younger")
  )
})

test_that("分层标签输入ID对特殊符号稳定", {
  input_id <- .survival_strata_label_input_id(">=65")
  expect_match(input_id, "^strata_label_[A-Za-z0-9]+$")
  expect_false(grepl("[<>]", input_id))
  expect_false(grepl("=", input_id, fixed = TRUE))
})

test_that("主图分组颜色映射稳定且可按 raw break 取值", {
  colors <- .build_survival_legend_colors(c("arm=A", "arm=B"), palette_name = "Set1")
  expect_named(colors, c("arm=A", "arm=B"))
  expect_length(unique(unname(colors)), 2)
})

test_that("删失图例颜色映射沿用主图分组颜色", {
  p <- ggplot2::ggplot(
    data.frame(x = c(1, 2), y = c(1, 0.8), grp = c("arm=A", "arm=B")),
    ggplot2::aes(x = x, y = y, colour = grp)
  ) +
    ggplot2::geom_line() +
    ggplot2::scale_colour_brewer(palette = "Set1")
  colors <- .resolve_survival_legend_colors(
    p,
    raw_breaks = c("arm=A", "arm=B"),
    display_breaks = c("Group A", "Group B")
  )
  expect_named(colors, c("Group A", "Group B"))
  expect_length(unique(unname(colors)), 2)
})

test_that("删失图例布局映射支持角落定位", {
  top_right <- .resolve_survival_censor_legend_layout("top-right")
  expect_equal(top_right$position, "inside_custom")
  expect_equal(top_right$anchor, graphics_resolve_inside_anchor(0.72, 0.58, 0.24, 0.22))
  expect_equal(.resolve_survival_censor_legend_layout("right")$position, "right")
  expect_equal(.resolve_survival_censor_legend_layout("none")$position, "none")
})

test_that("删失辅助图例仅使用显示标签与颜色", {
  legend_plot <- .build_survival_censor_legend_plot(
    labels = c("Group A", "Group B"),
    colors = c("Group A" = "#E41A1C", "Group B" = "#377EB8"),
    shape_value = 124,
    title = "Censor"
  )
  expect_s3_class(legend_plot, "ggplot")
  expect_equal(legend_plot$labels$title, "Censor")
  expect_equal(legend_plot$layers[[1]]$aes_params$shape, 124)
})

test_that("主图辅助图例仅使用显示标签与颜色", {
  legend_plot <- .build_survival_line_legend_plot(
    labels = c("Group A", "Group B"),
    colors = c("Group A" = "#E41A1C", "Group B" = "#377EB8"),
    title = "Arm",
    line_size = 0.8,
    line_type = "solid"
  )
  expect_s3_class(legend_plot, "ggplot")
  expect_equal(legend_plot$labels$title, "Arm")
})

test_that("辅助图例行间距收紧并稳定", {
  rows <- .build_survival_legend_rows(c("A", "B", "C"), row_gap = 0.55)
  expect_equal(rows$label, c("A", "B", "C"))
  expect_equal(diff(rows$y), c(-0.55, -0.55))
})

test_that("删失符号解析与静态图约定一致", {
  expect_equal(.resolve_survival_censor_shape_value("17"), 17)
  expect_equal(.resolve_survival_censor_shape_value(124), 124)
  expect_equal(.resolve_survival_censor_shape_value("bad"), 3)
})

test_that("生存分析P值展示遵循AMA格式", {
  expect_equal(.format_survival_p_value(0.0004), "<0.001")
  expect_equal(.format_survival_p_value(0.0344), "0.034")
  expect_equal(.format_survival_p_value(0.995), ">0.99")
  expect_equal(.compose_survival_p_text("Log-rank P", 0.0004), "Log-rank P <0.001")
  expect_equal(.compose_survival_p_text("Log-rank P", 0.0344), "Log-rank P = 0.034")
  expect_equal(.compose_survival_p_text("Log-rank 检验 P值", 0.0004, with_spaces = FALSE), "Log-rank 检验 P值<0.001")
})
