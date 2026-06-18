forest_normalize_result_schema <- function(df, mode, cols_map, on_missing = NULL) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) {
    return(NULL)
  }

  required_cols <- unlist(cols_map)
  missing_cols <- required_cols[!required_cols %in% names(df)]
  if (length(missing_cols) > 0) {
    if (is.function(on_missing)) {
      on_missing(missing_cols)
    }
    return(NULL)
  }

  normalized <- df
  numeric_cols <- unique(c(cols_map$estimate, cols_map$lower, cols_map$upper, "Estimate", "Lower", "Upper"))
  for (col in intersect(numeric_cols, names(normalized))) {
    normalized[[col]] <- suppressWarnings(as.numeric(normalized[[col]]))
  }

  normalized$forest_subgroup <- as.character(normalized[[cols_map$subgroup]])
  normalized$forest_label <- as.character(normalized[[cols_map$study]])
  normalized$forest_estimate <- normalized[[cols_map$estimate]]
  normalized$forest_lower <- normalized[[cols_map$lower]]
  normalized$forest_upper <- normalized[[cols_map$upper]]
  normalized$forest_source_mode <- mode

  if (!"original_row_id" %in% names(normalized)) {
    normalized$original_row_id <- seq_len(nrow(normalized))
  }

  normalized
}

forest_extract_model_result <- function(model, var, data, type = "cox", status_var = NULL, outcome_var = NULL) {
  if (inherits(model, "try-error")) return(NULL)

  summ <- summary(model)
  coefs <- summ$coefficients

  if (identical(type, "cox")) {
    conf <- summ$conf.int
    p_idx <- "Pr(>|z|)"
    est_col <- "exp(coef)"
    low_col <- "lower .95"
    upp_col <- "upper .95"
  } else {
    est <- coef(model)
    se <- coefs[, "Std. Error"]
    p_val <- coefs[, "Pr(>|z|)"]
    or <- exp(est)
    ci_low <- exp(est - 1.96 * se)
    ci_high <- exp(est + 1.96 * se)
    conf <- cbind(or, ci_low, ci_high)
    colnames(conf) <- c("OR", "2.5 %", "97.5 %")
    p_idx <- "Pr(>|z|)"
  }

  is_cat <- is.factor(data[[var]]) || is.character(data[[var]])

  if (is_cat) {
    lvls <- levels(as.factor(data[[var]]))
    n_lvls <- length(lvls)

    res <- data.frame(
      Variable = rep(var, n_lvls),
      Level = lvls,
      Estimate = NA,
      Lower = NA,
      Upper = NA,
      P_Value = NA,
      N = NA,
      Events = NA,
      stringsAsFactors = FALSE
    )

    res$Estimate[1] <- 1.0

    for (i in 2:n_lvls) {
      lvl <- lvls[i]
      term_pattern <- paste0(var, lvl)

      if (identical(type, "cox")) {
        idx <- which(rownames(coefs) == term_pattern)
        if (length(idx) == 0) idx <- grep(paste0(var, ".*", lvl), rownames(coefs))

        if (length(idx) > 0) {
          idx <- idx[1]
          res$Estimate[i] <- conf[idx, est_col]
          res$Lower[i] <- conf[idx, low_col]
          res$Upper[i] <- conf[idx, upp_col]
          res$P_Value[i] <- coefs[idx, p_idx]
        }
      } else {
        idx <- which(names(est) == term_pattern)
        if (length(idx) == 0) idx <- grep(paste0(var, ".*", lvl), names(est))

        if (length(idx) > 0) {
          idx <- idx[1]
          res$Estimate[i] <- or[idx]
          res$Lower[i] <- ci_low[idx]
          res$Upper[i] <- ci_high[idx]
          res$P_Value[i] <- p_val[idx]
        }
      }
    }

    for (i in seq_along(lvls)) {
      sub <- data[data[[var]] == lvls[i], ]
      res$N[i] <- nrow(sub)
      if (identical(type, "cox")) {
        res$Events[i] <- sum(sub[[status_var]] == 1, na.rm = TRUE)
      } else {
        res$Events[i] <- sum(sub[[outcome_var]] == 1, na.rm = TRUE)
      }
    }
    return(res)
  }

  res <- data.frame(
    Variable = var,
    Level = "Continuous",
    Estimate = NA, Lower = NA, Upper = NA, P_Value = NA, N = NA, Events = NA,
    stringsAsFactors = FALSE
  )

  if (identical(type, "cox")) {
    idx <- which(rownames(coefs) == var)
    if (length(idx) > 0) {
      res$Estimate <- conf[idx, est_col]
      res$Lower <- conf[idx, low_col]
      res$Upper <- conf[idx, upp_col]
      res$P_Value <- coefs[idx, p_idx]
    }
    res$N <- nrow(data[!is.na(data[[var]]), ])
    res$Events <- sum(data[!is.na(data[[var]]), ][[status_var]] == 1, na.rm = TRUE)
  } else {
    idx <- which(names(est) == var)
    if (length(idx) > 0) {
      res$Estimate <- or[idx]
      res$Lower <- ci_low[idx]
      res$Upper <- ci_high[idx]
      res$P_Value <- p_val[idx]
    }
    res$N <- nrow(data[!is.na(data[[var]]), ])
    res$Events <- sum(data[!is.na(data[[var]]), ][[outcome_var]] == 1, na.rm = TRUE)
  }

  res
}

forest_format_p_value_ama <- function(x) {
  if (exists("format_p_value_ama", mode = "function")) {
    return(format_p_value_ama(x))
  }
  if (is.character(x) && length(x) == 1 && (x == "NA" || x == "—" || x == "")) {
    return("—")
  }
  val <- suppressWarnings(as.numeric(x))
  if (is.na(val)) {
    return("—")
  }
  if (val < 0.001) {
    return("<0.001")
  }
  if (val > 0.99) {
    return(">0.99")
  }
  sprintf("%.3f", val)
}

forest_finalize_analysis_results <- function(final_list) {
  if (length(final_list) == 0) {
    return(NULL)
  }
  out <- do.call(rbind, final_list)
  out$P_Value_Raw <- out$P_Value
  out$P_Value_Str <- vapply(out$P_Value, forest_format_p_value_ama, character(1))
  out
}
