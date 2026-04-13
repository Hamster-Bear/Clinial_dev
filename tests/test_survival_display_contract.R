library(testthat)
library(shiny)

source(file.path("..", "modules", "common", "graphics_common.R"))
source(file.path("..", "modules", "statistical_graphics_ui", "common_ui_shell.R"))
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

test_that("生存分析 UI 可成功构建", {
  skip_if_not_installed("shinydashboard")
  library(shinydashboard)
  ui <- survival_analysis_ui("km")
  expect_true(inherits(ui, "shiny.tag.list") || inherits(ui, "list"))
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
  custom_anchor <- .resolve_survival_censor_legend_layout("inside_custom", inside_anchor = c(0.2, 0.3, 0.25, 0.2))
  expect_equal(custom_anchor$position, "inside_custom")
  expect_equal(custom_anchor$anchor, graphics_resolve_inside_anchor(0.2, 0.3, 0.25, 0.2))
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
  rows <- .build_survival_legend_rows(c("A", "B", "C"), row_gap = .survival_aux_legend_compact_spec$row_gap)
  expect_equal(rows$label, c("A", "B", "C"))
  expect_equal(diff(rows$y), c(-.survival_aux_legend_compact_spec$row_gap, -.survival_aux_legend_compact_spec$row_gap))
})

test_that("辅助图例紧凑布局常量保持收紧约束", {
  expect_equal(.survival_aux_legend_compact_spec$row_gap, 0.36)
  expect_equal(.survival_aux_legend_compact_spec$plot_margin_pt, c(1, 3, 1, 3))
  expect_equal(.survival_aux_legend_compact_spec$title_margin_bottom, 1)
  expect_equal(.survival_aux_legend_compact_spec$inter_legend_spacer, 0.03)
  expect_equal(.survival_aux_legend_compact_spec$secondary_rel_height, 0.68)
  expect_equal(.survival_aux_legend_compact_spec$default_inside_anchor, c(0.95, 0.85, 0.13, 0.14))
})

test_that("删失符号解析与静态图约定一致", {
  expect_equal(.resolve_survival_censor_shape_value("17"), 17)
  expect_equal(.resolve_survival_censor_shape_value(124), 124)
  expect_equal(.resolve_survival_censor_shape_value("bad"), 3)
})

test_that("删失点颜色优先复用主图最终 legend 颜色", {
  colors <- .resolve_survival_censor_point_colors(
    raw_strata = c("SEX=F", "SEX=M"),
    display_strata = c("F", "M"),
    main_legend_colors = c(F = "#E41A1C", M = "#377EB8"),
    fallback_colors = c("SEX=F" = "#4DAF4A", "SEX=M" = "#984EA3")
  )
  expect_equal(colors, c("#E41A1C", "#377EB8"))
})

test_that("中位生存时间文本默认使用 mPFS 并支持自由编辑", {
  expect_equal(.resolve_survival_median_label(NULL), "mPFS")
  expect_equal(.resolve_survival_median_label(""), "mPFS")
  expect_equal(.resolve_survival_median_label("Median Survival Time"), "Median Survival Time")
  expect_equal(
    .build_survival_median_summary_label("F", "mPFS", "12.30", "10.00", "15.00", overall_label = "all"),
    "F: mPFS: 12.30 (95%CI 10.00-15.00)"
  )
})

test_that("中位生存文本间距与 Cox 文本块风格对齐", {
  expect_equal(.survival_annotation_line_gap(), 0.055)
  expect_equal(.survival_median_text_hjust(), 0)
  y_positions <- .build_survival_annotation_y_positions(0.95, 3, 0.6)
  expect_equal(round(diff(y_positions), 3), c(-0.055, -0.055))
})

test_that("多组 log-rank 解释明确全局检验含义", {
  explanation <- .build_survival_logrank_interpretation(0.012, n_groups = 4)
  expect_length(explanation, 2)
  expect_match(explanation[[2]], "多组全局 Log-rank 检验")
  expect_match(explanation[[2]], "不代表所有两两组别均显著")
})

test_that("生存分析P值展示遵循AMA格式", {
  expect_equal(.format_survival_p_value(0.0004), "<0.001")
  expect_equal(.format_survival_p_value(0.0344), "0.034")
  expect_equal(.format_survival_p_value(0.995), ">0.99")
  expect_equal(.compose_survival_p_text("Log-rank P", 0.0004), "Log-rank P <0.001")
  expect_equal(.compose_survival_p_text("Log-rank P", 0.0344), "Log-rank P = 0.034")
  expect_equal(.compose_survival_p_text("Log-rank 检验 P值", 0.0004, with_spaces = FALSE), "Log-rank 检验 P值<0.001")
})
