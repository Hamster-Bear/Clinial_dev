library(testthat)

source(file.path("..", "modules", "common", "analysis_shared.R"))

test_that("compute_regression_context 正确解析 facet 与自定义总计列", {
  d <- data.frame(
    grp = factor(c("A", "B", "A", "C")),
    y = c(1, 0, 1, 0)
  )
  ctx <- compute_regression_context(
    df_in = d,
    facet_var = "grp",
    total_cols_settings = list(
      list(name = "AB总计", groups = c("A", "B")),
      list(name = "空", groups = c("X"))
    )
  )
  expect_true(all(c("facet_levels_all", "valid_total_settings", "facet_values_to_run") %in% names(ctx)))
  expect_true(all(c("A", "B", "C") %in% ctx$facet_levels_all))
  expect_equal(length(ctx$valid_total_settings), 1)
  expect_true(any(startsWith(ctx$facet_values_to_run, ".__TOTAL__")))
})

test_that("compute_regression_rows 能产出分类变量与 Reference 行", {
  d <- data.frame(
    y = c(1, 0, 1, 0),
    grp = factor(c("A", "B", "A", "B"), levels = c("A", "B"))
  )
  fit_tidy_fn <- function(sub_data, sval, fval) {
    data.frame(
      term = "grpB",
      estimate = 1.5,
      conf.low = 1.1,
      conf.high = 2.2,
      p.value = 0.02,
      stringsAsFactors = FALSE
    )
  }
  out <- compute_regression_rows(
    df_in = d,
    predictors = "grp",
    response_var_name = "y",
    strata_var = NULL,
    facet_var = NULL,
    strata_vals = "总体",
    facet_values_to_run = "__ALL__",
    valid_total_settings = list(),
    fit_tidy_fn = fit_tidy_fn,
    term_to_display_fn = function(term) sub("^grp", "", term),
    predictor_key_fn = function(term) "grp",
    count_effective_n_fn = function(df_sub) nrow(df_sub),
    format_estimate_fn = function(e, l, h) paste0(e, " (", l, ", ", h, ")"),
    format_p_fn = function(p) as.character(p),
    categorical_ref_map = c(grp = "A")
  )
  df <- out$final_df
  expect_true("预测变量" %in% names(df))
  expect_true(any(grepl("Reference", df$统计值, fixed = TRUE)))
  expect_true(any(grepl("A \\(Reference\\)", df$预测变量)))
  expect_true(any(grepl("B", df$预测变量)))
})

test_that("分步纯函数可串联并得到可渲染 payload", {
  d <- data.frame(
    y = c(1, 0, 1, 0, 1, 0),
    grp = factor(c("A", "B", "A", "B", "A", "B"), levels = c("A", "B")),
    sex = factor(c("M", "M", "F", "F", "M", "F"), levels = c("M", "F"))
  )
  fit_tidy_fn <- function(sub_data, sval, fval) {
    data.frame(
      term = "grpB",
      estimate = 1.2,
      conf.low = 0.8,
      conf.high = 1.7,
      p.value = 0.05,
      stringsAsFactors = FALSE
    )
  }
  ctx <- compute_regression_context(df_in = d, facet_var = NULL, total_cols_settings = list())
  rows_res <- compute_regression_rows(
    df_in = d,
    predictors = "grp",
    response_var_name = "y",
    strata_var = "sex",
    facet_var = NULL,
    strata_vals = c("M", "F"),
    facet_values_to_run = ctx$facet_values_to_run,
    valid_total_settings = ctx$valid_total_settings,
    fit_tidy_fn = fit_tidy_fn,
    term_to_display_fn = function(term) sub("^grp", "", term),
    predictor_key_fn = function(term) "grp",
    count_effective_n_fn = function(df_sub) nrow(df_sub),
    format_estimate_fn = function(e, l, h) paste0(e, " (", l, ", ", h, ")"),
    format_p_fn = function(p) as.character(p),
    categorical_ref_map = c(grp = "A")
  )
  df1 <- apply_regression_header_rows(
    final_df = rows_res$final_df,
    df_in = d,
    predictors = "grp",
    response_var_name = "y",
    strata_var = "sex",
    facet_var = NULL,
    strata_vals = c("M", "F"),
    facet_values_to_run = ctx$facet_values_to_run,
    valid_total_settings = ctx$valid_total_settings,
    count_effective_n_fn = function(df_sub) nrow(df_sub),
    categorical_ref_map = c(grp = "A")
  )
  df2 <- complete_regression_rows_grid(
    final_df = df1,
    strata_var = "sex",
    facet_var = NULL,
    strata_vals = c("M", "F"),
    facet_values_to_run = ctx$facet_values_to_run
  )
  df3 <- apply_interaction_p_values(
    final_df = df2,
    strata_var = "sex",
    facet_var = NULL,
    strata_vals = c("M", "F"),
    get_int_p_fn = function(int_map, pred_key, sval, facet_tag = "__ALL__") "0.123",
    int_p_map = character(0)
  )
  col_res <- compute_regression_columns(
    final_df = df3,
    df_in = d,
    facet_var = NULL,
    facet_levels_all = ctx$facet_levels_all,
    valid_total_settings = ctx$valid_total_settings,
    count_effective_n_fn = function(df_sub) nrow(df_sub),
    metric_label = "OR (95% CI)"
  )
  fin_res <- finalize_regression_display(
    final_df = col_res$final_df,
    label_map = col_res$label_map,
    strata_var = "sex",
    strata_vals = c("M", "F"),
    df_in = d
  )
  payload <- list(
    final_df = fin_res$final_df,
    label_map = fin_res$label_map,
    spanner_map = col_res$spanner_map,
    md_cols = grep("P值$", names(fin_res$final_df), value = TRUE),
    skipped_models = rows_res$skipped_models
  )
  gt_tbl <- render_clinical_table(payload, apply_style_fn = function(x) x)
  expect_true(inherits(gt_tbl, "gt_tbl"))
})
