forest_normalize_selected_columns <- function(selected_cols) {
  if (is.null(selected_cols)) {
    return(character(0))
  }
  if (is.list(selected_cols)) {
    selected_cols <- unlist(selected_cols, recursive = TRUE, use.names = FALSE)
  }
  if (length(selected_cols) == 0) {
    return(character(0))
  }
  selected_cols <- as.character(selected_cols)
  selected_cols <- selected_cols[!is.na(selected_cols) & nzchar(selected_cols)]
  unique(selected_cols)
}

forest_default_column_alignment <- function(col_name) {
  if (col_name %in% c("subgroup", "study", "Variable")) {
    return("left")
  }
  if (col_name %in% c("estimate", "lower", "upper", "n", "events", "Estimate")) {
    return("right")
  }
  "center"
}

forest_persist_selected_column_inputs <- function(input, selected_cols, display_names = list(), alignments = list()) {
  selected_cols <- forest_normalize_selected_columns(selected_cols)
  updated_display_names <- display_names %||% list()
  updated_alignments <- alignments %||% list()
  if (length(selected_cols) == 0) {
    return(list(display_names = updated_display_names, alignments = updated_alignments))
  }
  for (col in selected_cols) {
    name_input <- paste0("name_", col)
    align_input <- paste0("align_", col)
    if (!is.null(input[[name_input]]) && nzchar(input[[name_input]])) {
      updated_display_names[[col]] <- input[[name_input]]
    }
    if (!is.null(input[[align_input]])) {
      updated_alignments[[col]] <- input[[align_input]]
    }
  }
  list(display_names = updated_display_names, alignments = updated_alignments)
}

forest_collect_selected_column_state <- function(
  selected_cols,
  display_names = list(),
  alignments = list(),
  default_alignment_fn = forest_default_column_alignment
) {
  selected_cols <- forest_normalize_selected_columns(selected_cols)
  collected_alignments <- setNames(vector("list", length(selected_cols)), selected_cols)
  collected_display_names <- setNames(vector("list", length(selected_cols)), selected_cols)
  for (col in selected_cols) {
    collected_alignments[[col]] <- alignments[[col]] %||% default_alignment_fn(col)
    collected_display_names[[col]] <- display_names[[col]] %||% col
  }
  list(
    selected_cols = selected_cols,
    alignments = collected_alignments,
    display_names = collected_display_names
  )
}

forest_restore_selected_column_state <- function(
  session,
  extra_state,
  selection_input_id = "selected_table_cols",
  current_display_names = list(),
  current_alignments = list(),
  available_cols = NULL
) {
  saved_display_names <- if (is.list(extra_state$display_names)) extra_state$display_names else list()
  saved_alignments <- if (is.list(extra_state$alignments)) extra_state$alignments else list()
  saved_selected_cols <- forest_normalize_selected_columns(extra_state$selected_table_cols %||% character(0))

  merged_display_names <- if (length(saved_display_names) > 0) {
    utils::modifyList(current_display_names %||% list(), saved_display_names)
  } else {
    current_display_names %||% list()
  }
  merged_alignments <- if (length(saved_alignments) > 0) {
    utils::modifyList(current_alignments %||% list(), saved_alignments)
  } else {
    current_alignments %||% list()
  }

  valid_selected_cols <- if (is.null(available_cols)) {
    saved_selected_cols
  } else {
    intersect(saved_selected_cols, forest_normalize_selected_columns(available_cols))
  }

  if (!is.null(available_cols)) {
    updateSelectizeInput(
      session,
      selection_input_id,
      choices = unique(c(available_cols, saved_selected_cols)),
      selected = valid_selected_cols,
      server = TRUE
    )
  }

  list(
    selected_cols = valid_selected_cols,
    display_names = merged_display_names,
    alignments = merged_alignments
  )
}

forest_pick_valid_column <- function(
  saved_value = NULL,
  current_value = NULL,
  available_cols,
  preferred_cols = character(0),
  fallback_index = 1
) {
  available_cols <- forest_normalize_selected_columns(available_cols)
  if (length(available_cols) == 0) {
    return(NULL)
  }

  first_scalar <- function(value) {
    value <- forest_normalize_selected_columns(value)
    if (length(value) == 0) return(NULL)
    value[[1]]
  }

  saved_scalar <- first_scalar(saved_value)
  if (!is.null(saved_scalar) && saved_scalar %in% available_cols) {
    return(saved_scalar)
  }

  current_scalar <- first_scalar(current_value)
  if (!is.null(current_scalar) && current_scalar %in% available_cols) {
    return(current_scalar)
  }

  preferred_cols <- forest_normalize_selected_columns(preferred_cols)
  preferred_match <- intersect(preferred_cols, available_cols)
  if (length(preferred_match) > 0) {
    return(preferred_match[[1]])
  }

  fallback_index <- suppressWarnings(as.integer(fallback_index %||% 1L))
  if (length(fallback_index) == 0 || is.na(fallback_index) || fallback_index < 1) {
    fallback_index <- 1L
  }
  fallback_index <- min(fallback_index, length(available_cols))
  available_cols[[fallback_index]]
}

forest_can_restore_mapping_state <- function(mode = "precalculated", extra_state = list(), available_cols) {
  available_cols <- forest_normalize_selected_columns(available_cols)
  if (length(available_cols) == 0) {
    return(FALSE)
  }

  if (!identical(mode %||% "precalculated", "precalculated")) {
    return(TRUE)
  }

  required_saved_cols <- forest_normalize_selected_columns(c(
    extra_state$subgroup_col,
    extra_state$study_col,
    extra_state$estimate_col,
    extra_state$lower_col,
    extra_state$upper_col
  ))

  if (length(required_saved_cols) == 0) {
    return(TRUE)
  }

  all(required_saved_cols %in% available_cols)
}

forest_build_mapping_restore_plan <- function(
  available_cols,
  current_state = list(),
  extra_state = list(),
  mode = "precalculated"
) {
  available_cols <- forest_normalize_selected_columns(available_cols)
  if (length(available_cols) == 0) {
    return(list(
      ready = FALSE,
      subgroup_col = NULL,
      study_col = NULL,
      estimate_col = NULL,
      lower_col = NULL,
      upper_col = NULL,
      time_col = NULL,
      status_col = NULL,
      outcome_col = NULL,
      covariates = character(0)
    ))
  }

  time_candidates <- available_cols[grep("time|dur|os|pfs|rfs", tolower(available_cols))]
  status_candidates <- available_cols[grep("status|event|dead|death|censor", tolower(available_cols))]
  outcome_candidates <- available_cols[grep("response|outcome|recurrence|disease|event|status", tolower(available_cols))]

  list(
    ready = forest_can_restore_mapping_state(mode = mode, extra_state = extra_state, available_cols = available_cols),
    subgroup_col = forest_pick_valid_column(
      saved_value = extra_state$subgroup_col,
      current_value = current_state$subgroup_col,
      available_cols = available_cols,
      preferred_cols = "subgroup",
      fallback_index = 1
    ),
    study_col = forest_pick_valid_column(
      saved_value = extra_state$study_col,
      current_value = current_state$study_col,
      available_cols = available_cols,
      preferred_cols = "study",
      fallback_index = 2
    ),
    estimate_col = forest_pick_valid_column(
      saved_value = extra_state$estimate_col,
      current_value = current_state$estimate_col,
      available_cols = available_cols,
      preferred_cols = "estimate",
      fallback_index = 3
    ),
    lower_col = forest_pick_valid_column(
      saved_value = extra_state$lower_col,
      current_value = current_state$lower_col,
      available_cols = available_cols,
      preferred_cols = "lower",
      fallback_index = 4
    ),
    upper_col = forest_pick_valid_column(
      saved_value = extra_state$upper_col,
      current_value = current_state$upper_col,
      available_cols = available_cols,
      preferred_cols = "upper",
      fallback_index = 5
    ),
    time_col = forest_pick_valid_column(
      saved_value = extra_state$time_col,
      current_value = current_state$time_col,
      available_cols = available_cols,
      preferred_cols = time_candidates,
      fallback_index = 1
    ),
    status_col = forest_pick_valid_column(
      saved_value = extra_state$status_col,
      current_value = current_state$status_col,
      available_cols = available_cols,
      preferred_cols = status_candidates,
      fallback_index = min(2, length(available_cols))
    ),
    outcome_col = forest_pick_valid_column(
      saved_value = extra_state$outcome_col,
      current_value = current_state$outcome_col,
      available_cols = available_cols,
      preferred_cols = outcome_candidates,
      fallback_index = 1
    ),
    covariates = intersect(
      forest_normalize_selected_columns(extra_state$covariates %||% current_state$covariates),
      available_cols
    )
  )
}
