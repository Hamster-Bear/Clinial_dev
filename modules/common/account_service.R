service_registry_load <- function(pool, user = NULL) {
  if (is.null(user)) {
    return(auth_empty_registry())
  }
  auth_load_registry(pool, user_id = user$id, is_admin = isTRUE(user$is_admin))
}

service_list_users <- function(pool) {
  DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, username, email, is_admin, status, created_at",
      "FROM users",
      "ORDER BY created_at ASC"
    )
  )
}

service_list_workspaces <- function(pool) {
  DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, name, owner_user_id, created_at",
      "FROM workspaces",
      "ORDER BY created_at DESC"
    )
  )
}

service_list_workspace_memberships <- function(pool, workspace_id = "") {
  sql <- paste(
    "SELECT wm.id, wm.workspace_id, wm.user_id, wm.role, wm.created_at,",
    "u.username, u.email, u.status",
    "FROM workspace_memberships wm",
    "JOIN users u ON u.id = wm.user_id"
  )
  if (nzchar(workspace_id %||% "")) {
    sql <- paste(sql, "WHERE wm.workspace_id = $1 ORDER BY wm.created_at ASC")
    return(DBI::dbGetQuery(pool, sql, params = list(workspace_id)))
  }
  DBI::dbGetQuery(pool, paste(sql, "ORDER BY wm.created_at ASC"))
}

service_assign_workspace_owner <- function(pool, workspace_id, owner_user_id) {
  if (!nzchar(workspace_id %||% "") || !nzchar(owner_user_id %||% "")) {
    stop("缺少数据空间或负责人信息")
  }
  DBI::dbExecute(
    pool,
    "UPDATE workspaces SET owner_user_id = $1 WHERE id = $2",
    params = list(owner_user_id, workspace_id)
  )
  auth_ensure_workspace_membership(pool, workspace_id, owner_user_id, role = "owner")
  invisible(TRUE)
}

service_upsert_workspace_membership <- function(pool, workspace_id, user_id, role) {
  if (!nzchar(workspace_id %||% "") || !nzchar(user_id %||% "")) {
    stop("缺少数据空间或用户信息")
  }
  role <- trimws(role %||% "viewer")
  if (!(role %in% c("owner", "editor", "viewer"))) {
    stop("不支持的成员角色")
  }
  auth_ensure_workspace_membership(pool, workspace_id, user_id, role = role)
  if (identical(role, "owner")) {
    DBI::dbExecute(
      pool,
      "UPDATE workspaces SET owner_user_id = $1 WHERE id = $2",
      params = list(user_id, workspace_id)
    )
  }
  invisible(TRUE)
}

service_set_user_status <- function(pool, user_id, status) {
  status <- trimws(status %||% "")
  if (!(status %in% c("active", "inactive"))) {
    stop("不支持的账号状态")
  }
  DBI::dbExecute(
    pool,
    "UPDATE users SET status = $1 WHERE id = $2",
    params = list(status, user_id)
  )
  invisible(TRUE)
}
