# 共享数据注册表管理
# 收录数据空间、文件夹、数据集的刷新和池初始化逻辑，
# 供 database_manager 和 data_preparation 共用

`%||%` <- function(x, y) if (is.null(x)) y else x

registry_init_pool <- function(pg_pool = NULL) {
  pool <- if (is.null(pg_pool)) auth_create_pool() else pg_pool
  if (is.null(pg_pool)) {
    shiny::onStop(function() {
      pool::poolClose(pool)
    })
  }
  auth_ensure_schema(pool)
  pool
}

registry_load <- function(pool, user) {
  if (is.null(pool) || is.null(user) || !is.list(user) || !nzchar(user$id %||% "")) {
    return(auth_empty_registry())
  }
  tryCatch(
    service_registry_load(pool, user = user),
    error = function(e) {
      warning("注册表加载失败，使用空注册表: ", conditionMessage(e))
      auth_empty_registry()
    }
  )
}

registry_refresh_workspace_choices <- function(session, pool, user, selected = character(0)) {
  if (is.null(pool) || is.null(user) || !is.list(user)) {
    updateSelectInput(session, "workspace_select", choices = character(0), selected = "")
    return("")
  }
  reg <- registry_load(pool, user)
  choices <- stats::setNames(reg$workspace_ids, reg$workspace_names)
  if (!nzchar(selected) || !selected %in% reg$workspace_ids) {
    selected <- if (length(reg$workspace_ids) > 0) reg$workspace_ids[[1]] else ""
  }
  updateSelectInput(session, "workspace_select", choices = choices, selected = selected)
  selected
}

registry_refresh_folder_choices <- function(session, pool, workspace_id, root_token = "__ROOT__",
                                             selected = character(0)) {
  if (!nzchar(workspace_id)) {
    updateSelectInput(session, "folder_select", choices = c("根目录" = root_token), selected = root_token)
    return(root_token)
  }
  folders <- tryCatch(
    DBI::dbGetQuery(pool, "SELECT id, name FROM folders WHERE workspace_id = $1 ORDER BY name",
                    params = list(workspace_id)),
    error = function(e) data.frame()
  )
  choices <- c("根目录" = root_token)
  if (nrow(folders) > 0) {
    choices <- c(choices, stats::setNames(folders$id, folders$name))
  }
  if (!nzchar(selected) || !selected %in% names(choices)) {
    selected <- root_token
  }
  updateSelectInput(session, "folder_select", choices = choices, selected = selected)
  selected
}

registry_refresh_dataset_choices <- function(session, pool, workspace_id, folder_id,
                                              root_token = "__ROOT__", selected = character(0)) {
  if (!nzchar(workspace_id) || is.null(pool)) {
    updateSelectInput(session, "dataset_select", choices = character(0), selected = "")
    return("")
  }
  folder_store <- if (is.null(folder_id) || folder_id == root_token || folder_id == "") NA else folder_id
  ds <- tryCatch(
    DBI::dbGetQuery(pool,
      "SELECT id, name, nrow, ncol FROM datasets WHERE workspace_id = $1 AND (folder_id = $2 OR ($2 IS NULL AND (folder_id IS NULL OR folder_id = ''))) ORDER BY name",
      params = list(workspace_id, folder_store)),
    error = function(e) data.frame()
  )
  if (nrow(ds) == 0) {
    updateSelectInput(session, "dataset_select", choices = character(0), selected = "")
    return("")
  }
  labels <- paste0(ds$name, " (", ds$nrow, "x", ds$ncol, ")")
  choices <- stats::setNames(ds$id, labels)
  if (!nzchar(selected) || !selected %in% ds$id) {
    selected <- ds$id[[1]]
  }
  updateSelectInput(session, "dataset_select", choices = choices, selected = selected)
  selected
}
