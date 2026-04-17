forest_run_analysis_pipeline <- function(
  df,
  reg_type,
  method,
  covariates,
  time_var = NULL,
  status_var = NULL,
  outcome_var = NULL
) {
  prepared_df <- forest_prepare_analysis_dataframe(
    df = df,
    reg_type = reg_type,
    time_var = time_var,
    status_var = status_var,
    outcome_var = outcome_var
  )

  final_list <- list()

  if (identical(method, "univariate")) {
    for (cov in covariates) {
      formula <- forest_build_model_formula(
        reg_type = reg_type,
        covariates = cov,
        time_var = time_var,
        status_var = status_var,
        outcome_var = outcome_var
      )
      fit <- forest_fit_analysis_model(formula, data = prepared_df, reg_type = reg_type)
      res <- forest_extract_model_result(
        fit,
        cov,
        prepared_df,
        type = reg_type,
        status_var = status_var,
        outcome_var = outcome_var
      )
      if (!is.null(res)) final_list[[cov]] <- res
    }
  } else {
    formula <- forest_build_model_formula(
      reg_type = reg_type,
      covariates = covariates,
      time_var = time_var,
      status_var = status_var,
      outcome_var = outcome_var
    )
    fit <- forest_fit_analysis_model(formula, data = prepared_df, reg_type = reg_type)
    for (cov in covariates) {
      res <- forest_extract_model_result(
        fit,
        cov,
        prepared_df,
        type = reg_type,
        status_var = status_var,
        outcome_var = outcome_var
      )
      if (!is.null(res)) final_list[[cov]] <- res
    }
  }

  forest_finalize_analysis_results(final_list)
}
