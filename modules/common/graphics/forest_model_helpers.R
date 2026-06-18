if (!exists("analysis_build_formula", mode = "function") || !exists("analysis_build_surv_formula", mode = "function")) {
  if (file.exists("modules/common/analysis/analysis_shared.R")) {
    source("modules/common/analysis/analysis_shared.R")
  } else {
    source(file.path("..", "modules", "common", "analysis", "analysis_shared.R"))
  }
}

forest_prepare_analysis_dataframe <- function(df, reg_type, time_var = NULL, status_var = NULL, outcome_var = NULL) {
  prepared <- df
  if (identical(reg_type, "cox")) {
    prepared[[time_var]] <- as.numeric(prepared[[time_var]])
    if (is.character(prepared[[status_var]]) || is.factor(prepared[[status_var]])) {
      lvls <- levels(as.factor(prepared[[status_var]]))
      if (length(lvls) == 2) {
        prepared[[status_var]] <- as.numeric(as.factor(prepared[[status_var]])) - 1
      }
    }
    prepared[[status_var]] <- as.numeric(prepared[[status_var]])
    return(prepared)
  }

  if (is.character(prepared[[outcome_var]]) || is.factor(prepared[[outcome_var]])) {
    lvls <- levels(as.factor(prepared[[outcome_var]]))
    if (length(lvls) == 2) {
      prepared[[outcome_var]] <- as.numeric(as.factor(prepared[[outcome_var]])) - 1
    }
  }
  prepared[[outcome_var]] <- as.numeric(prepared[[outcome_var]])
  prepared
}

forest_build_model_formula <- function(reg_type, covariates, time_var = NULL, status_var = NULL, outcome_var = NULL) {
  if (identical(reg_type, "cox")) {
    return(analysis_build_surv_formula(time_var, status_var, terms = covariates))
  }
  analysis_build_formula(outcome_var, covariates)
}

forest_fit_analysis_model <- function(formula, data, reg_type) {
  if (identical(reg_type, "cox")) {
    return(try(coxph(formula, data = data), silent = TRUE))
  }
  try(glm(formula, data = data, family = binomial), silent = TRUE)
}
