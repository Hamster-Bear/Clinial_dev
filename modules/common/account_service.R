service_registry_load <- function(pool, user = NULL) {
  if (is.null(user)) {
    return(auth_empty_registry())
  }
  auth_load_registry(pool, user_id = user$id, is_admin = isTRUE(user$is_admin))
}

service_normalize_workspace_name <- function(workspace_name) {
  workspace_name <- trimws(workspace_name %||% "")
  if (!nzchar(workspace_name)) {
    stop("请输入数据空间名称")
  }
  workspace_name
}

service_label_workspace_role <- function(role) {
  labels <- c(
    viewer = "只读成员",
    editor = "可编辑成员",
    owner = "空间负责人"
  )
  labels[[trimws(role %||% "")]] %||% (role %||% "")
}

service_label_invite_status <- function(status) {
  labels <- c(
    pending = "待领取",
    accepted = "已接受",
    revoked = "已撤销"
  )
  labels[[trimws(status %||% "")]] %||% (status %||% "")
}

service_label_user_status <- function(status) {
  labels <- c(
    active = "正常",
    inactive = "停用"
  )
  labels[[trimws(status %||% "")]] %||% (status %||% "")
}

service_label_db_access_status <- function(enabled) {
  if (isTRUE(enabled)) {
    return("已开放")
  }
  "未开放"
}

service_format_datetime <- function(x) {
  values <- as.character(x %||% character(0))
  values[is.na(values) | !nzchar(values)] <- ""
  values
}

service_membership_preview_df <- function(memberships) {
  if (is.null(memberships) || !is.data.frame(memberships) || nrow(memberships) == 0) {
    return(data.frame(
      成员账号 = character(0),
      联系邮箱 = character(0),
      协作权限 = character(0),
      账号状态 = character(0),
      加入时间 = character(0),
      check.names = FALSE
    ))
  }
  data.frame(
    成员账号 = memberships$username %||% "",
    联系邮箱 = memberships$email %||% "",
    协作权限 = vapply(memberships$role %||% character(0), service_label_workspace_role, character(1)),
    账号状态 = vapply(memberships$status %||% character(0), service_label_user_status, character(1)),
    加入时间 = service_format_datetime(memberships$created_at),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

service_invite_preview_df <- function(invites) {
  if (is.null(invites) || !is.data.frame(invites) || nrow(invites) == 0) {
    return(data.frame(
      受邀邮箱 = character(0),
      待授权限 = character(0),
      邀请状态 = character(0),
      领取账号 = character(0),
      发起时间 = character(0),
      领取时间 = character(0),
      check.names = FALSE
    ))
  }
  data.frame(
    受邀邮箱 = invites$invited_email %||% "",
    待授权限 = vapply(invites$target_role %||% character(0), service_label_workspace_role, character(1)),
    邀请状态 = vapply(invites$status %||% character(0), service_label_invite_status, character(1)),
    领取账号 = invites$claimed_username %||% "",
    发起时间 = service_format_datetime(invites$created_at),
    领取时间 = service_format_datetime(invites$claimed_at),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

service_normalize_role <- function(role, allow_owner = TRUE) {
  role <- trimws(role %||% "viewer")
  allowed_roles <- c("viewer", "editor", if (isTRUE(allow_owner)) "owner")
  if (!(role %in% allowed_roles)) {
    stop("不支持的成员角色")
  }
  role
}

service_get_workspace <- function(pool, workspace_id) {
  if (!nzchar(workspace_id %||% "")) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT id, name, owner_user_id, created_at FROM workspaces WHERE id = $1 LIMIT 1",
    params = list(workspace_id)
  )
}

service_get_workspace_by_name <- function(pool, workspace_name) {
  workspace_name <- trimws(workspace_name %||% "")
  if (!nzchar(workspace_name)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT id, name, owner_user_id, created_at FROM workspaces WHERE name = $1 LIMIT 1",
    params = list(workspace_name)
  )
}

service_get_user_by_email <- function(pool, email) {
  normalized_email <- auth_normalize_email(email)
  if (!nzchar(normalized_email)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, username, email, is_admin, status, created_at",
      "FROM users WHERE email = $1 LIMIT 1"
    ),
    params = list(normalized_email)
  )
}

service_get_user_by_id <- function(pool, user_id) {
  if (!nzchar(user_id %||% "")) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, username, email, is_admin, status, created_at",
      "FROM users WHERE id = $1 LIMIT 1"
    ),
    params = list(user_id)
  )
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

service_list_manageable_workspaces <- function(pool, user) {
  if (is.null(user)) {
    return(data.frame())
  }
  if (isTRUE(user$is_admin)) {
    return(service_list_workspaces(pool))
  }
  DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, name, owner_user_id, created_at",
      "FROM workspaces",
      "WHERE owner_user_id = $1",
      "ORDER BY created_at DESC"
    ),
    params = list(user$id)
  )
}

service_can_manage_workspace <- function(pool, workspace_id, user) {
  if (is.null(user) || !nzchar(workspace_id %||% "")) {
    return(FALSE)
  }
  workspace_row <- service_get_workspace(pool, workspace_id)
  if (nrow(workspace_row) == 0) {
    return(FALSE)
  }
  isTRUE(user$is_admin) || identical(workspace_row$owner_user_id[[1]] %||% "", user$id %||% "")
}

service_assert_workspace_manager <- function(pool, workspace_id, user) {
  if (!service_can_manage_workspace(pool, workspace_id, user)) {
    stop("当前账号无权管理该数据空间")
  }
  invisible(TRUE)
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

service_list_workspace_invites <- function(pool, workspace_id = "") {
  sql <- paste(
    "SELECT wi.id, wi.workspace_id, wi.invited_email, wi.target_role, wi.status,",
    "wi.created_by_user_id, wi.claimed_user_id, wi.created_at, wi.claimed_at,",
    "u.username AS claimed_username",
    "FROM workspace_invites wi",
    "LEFT JOIN users u ON u.id = wi.claimed_user_id"
  )
  if (nzchar(workspace_id %||% "")) {
    sql <- paste(sql, "WHERE wi.workspace_id = $1 ORDER BY wi.created_at DESC")
    return(DBI::dbGetQuery(pool, sql, params = list(workspace_id)))
  }
  DBI::dbGetQuery(pool, paste(sql, "ORDER BY wi.created_at DESC"))
}

service_list_workspace_access <- function(pool, workspace_id) {
  list(
    workspace = service_get_workspace(pool, workspace_id),
    memberships = service_list_workspace_memberships(pool, workspace_id),
    invites = service_list_workspace_invites(pool, workspace_id)
  )
}

service_create_workspace <- function(pool, workspace_name, owner_user_id) {
  workspace_name <- service_normalize_workspace_name(workspace_name)
  if (!nzchar(owner_user_id %||% "")) {
    stop("缺少数据空间负责人")
  }
  existing_workspace <- service_get_workspace_by_name(pool, workspace_name)
  if (nrow(existing_workspace) > 0) {
    stop("数据空间名称已存在")
  }
  workspace_id <- auth_generate_id("ws")
  DBI::dbExecute(
    pool,
    "INSERT INTO workspaces (id, name, owner_user_id, created_at) VALUES ($1, $2, $3, NOW())",
    params = list(workspace_id, workspace_name, owner_user_id)
  )
  auth_ensure_workspace_membership(pool, workspace_id, owner_user_id, role = "owner")
  list(
    id = workspace_id,
    name = workspace_name,
    owner_user_id = owner_user_id
  )
}

service_delete_workspace <- function(pool, workspace_id, acting_user = NULL) {
  if (!nzchar(workspace_id %||% "")) {
    stop("缺少数据空间信息")
  }
  if (!is.null(acting_user)) {
    service_assert_workspace_manager(pool, workspace_id, acting_user)
  }
  DBI::dbExecute(
    pool,
    "DELETE FROM workspaces WHERE id = $1",
    params = list(workspace_id)
  )
  invisible(TRUE)
}

service_upsert_workspace_membership <- function(pool, workspace_id, user_id, role) {
  if (!nzchar(workspace_id %||% "") || !nzchar(user_id %||% "")) {
    stop("缺少数据空间或用户信息")
  }
  role <- service_normalize_role(role, allow_owner = TRUE)
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

service_record_workspace_invite <- function(pool, workspace_id, invited_email, role, created_by_user_id) {
  normalized_email <- auth_normalize_email(invited_email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    stop(email_error)
  }
  role <- service_normalize_role(role, allow_owner = TRUE)
  existing_invite <- DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id FROM workspace_invites",
      "WHERE workspace_id = $1 AND invited_email = $2 LIMIT 1"
    ),
    params = list(workspace_id, normalized_email)
  )
  if (nrow(existing_invite) > 0) {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE workspace_invites",
        "SET target_role = $1, status = 'pending', created_by_user_id = $2,",
        "claimed_user_id = NULL, claimed_at = NULL",
        "WHERE id = $3"
      ),
      params = list(role, created_by_user_id, existing_invite$id[[1]])
    )
    return(invisible(existing_invite$id[[1]]))
  }
  invite_id <- auth_generate_id("inv")
  DBI::dbExecute(
    pool,
    paste(
      "INSERT INTO workspace_invites",
      "(id, workspace_id, invited_email, target_role, status, created_by_user_id, created_at)",
      "VALUES ($1, $2, $3, $4, 'pending', $5, NOW())"
    ),
    params = list(invite_id, workspace_id, normalized_email, role, created_by_user_id)
  )
  invisible(invite_id)
}

service_assign_workspace_owner <- function(pool, workspace_id, owner_user_id) {
  if (!nzchar(workspace_id %||% "") || !nzchar(owner_user_id %||% "")) {
    stop("缺少数据空间或负责人信息")
  }
  workspace_row <- service_get_workspace(pool, workspace_id)
  if (nrow(workspace_row) == 0) {
    stop("数据空间不存在")
  }
  previous_owner_id <- workspace_row$owner_user_id[[1]] %||% ""
  DBI::dbExecute(
    pool,
    "UPDATE workspaces SET owner_user_id = $1 WHERE id = $2",
    params = list(owner_user_id, workspace_id)
  )
  auth_ensure_workspace_membership(pool, workspace_id, owner_user_id, role = "owner")
  if (nzchar(previous_owner_id) && !identical(previous_owner_id, owner_user_id)) {
    auth_ensure_workspace_membership(pool, workspace_id, previous_owner_id, role = "editor")
  }
  invisible(TRUE)
}

service_grant_workspace_access_by_email <- function(pool, workspace_id, invited_email, role, acting_user) {
  service_assert_workspace_manager(pool, workspace_id, acting_user)
  role <- service_normalize_role(role, allow_owner = FALSE)
  normalized_email <- auth_normalize_email(invited_email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    stop(email_error)
  }
  target_user <- service_get_user_by_email(pool, normalized_email)
  if (nrow(target_user) > 0) {
    service_upsert_workspace_membership(pool, workspace_id, target_user$id[[1]], role = role)
    return(list(mode = "membership", message = "成员权限已更新"))
  }
  service_record_workspace_invite(pool, workspace_id, normalized_email, role, acting_user$id)
  list(mode = "invite", message = "目标邮箱尚未注册，已记录待领取授权")
}

service_transfer_workspace_owner_by_email <- function(pool, workspace_id, invited_email, acting_user) {
  service_assert_workspace_manager(pool, workspace_id, acting_user)
  normalized_email <- auth_normalize_email(invited_email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    stop(email_error)
  }
  target_user <- service_get_user_by_email(pool, normalized_email)
  if (nrow(target_user) > 0) {
    service_assign_workspace_owner(pool, workspace_id, target_user$id[[1]])
    return(list(mode = "owner", message = "Workspace Owner 已迁移"))
  }
  service_record_workspace_invite(pool, workspace_id, normalized_email, "owner", acting_user$id)
  list(mode = "invite", message = "目标邮箱尚未注册，已记录待领取 Owner 迁移")
}

service_revoke_workspace_access_by_email <- function(pool, workspace_id, invited_email, acting_user) {
  service_assert_workspace_manager(pool, workspace_id, acting_user)
  normalized_email <- auth_normalize_email(invited_email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    stop(email_error)
  }
  workspace_row <- service_get_workspace(pool, workspace_id)
  owner_row <- service_get_user_by_email(pool, normalized_email)
  if (nrow(owner_row) > 0 && identical(workspace_row$owner_user_id[[1]] %||% "", owner_row$id[[1]])) {
    stop("不能直接回收当前 Owner，请先迁移负责人")
  }
  if (nrow(owner_row) > 0) {
    DBI::dbExecute(
      pool,
      "DELETE FROM workspace_memberships WHERE workspace_id = $1 AND user_id = $2",
      params = list(workspace_id, owner_row$id[[1]])
    )
  }
  DBI::dbExecute(
    pool,
    paste(
      "UPDATE workspace_invites SET status = 'revoked'",
      "WHERE workspace_id = $1 AND invited_email = $2"
    ),
    params = list(workspace_id, normalized_email)
  )
  invisible(TRUE)
}

service_claim_workspace_invites <- function(pool, user_id, email) {
  normalized_email <- auth_normalize_email(email)
  if (!nzchar(user_id %||% "") || !nzchar(normalized_email)) {
    return(invisible(FALSE))
  }
  invites <- DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, workspace_id, target_role FROM workspace_invites",
      "WHERE invited_email = $1 AND status = 'pending'",
      "ORDER BY created_at ASC"
    ),
    params = list(normalized_email)
  )
  if (nrow(invites) == 0) {
    return(invisible(FALSE))
  }
  for (row_index in seq_len(nrow(invites))) {
    invite_row <- invites[row_index, , drop = FALSE]
    if (identical(invite_row$target_role[[1]], "owner")) {
      service_assign_workspace_owner(pool, invite_row$workspace_id[[1]], user_id)
    } else {
      service_upsert_workspace_membership(pool, invite_row$workspace_id[[1]], user_id, invite_row$target_role[[1]])
    }
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE workspace_invites",
        "SET status = 'accepted', claimed_user_id = $1, claimed_at = NOW()",
        "WHERE id = $2"
      ),
      params = list(user_id, invite_row$id[[1]])
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

service_set_user_status_by_email <- function(pool, email, status) {
  target_user <- service_get_user_by_email(pool, email)
  if (nrow(target_user) == 0) {
    stop("目标邮箱对应的用户不存在")
  }
  service_set_user_status(pool, target_user$id[[1]], status)
}

service_set_user_db_access <- function(pool, user_id, enabled = FALSE) {
  if (!nzchar(user_id %||% "")) {
    stop("缺少用户信息")
  }
  DBI::dbExecute(
    pool,
    "UPDATE users SET db_access_enabled = $1 WHERE id = $2",
    params = list(isTRUE(enabled), user_id)
  )
  invisible(TRUE)
}

service_set_user_db_access_by_email <- function(pool, email, enabled = FALSE) {
  target_user <- service_get_user_by_email(pool, email)
  if (nrow(target_user) == 0) {
    stop("目标邮箱对应的用户不存在")
  }
  service_set_user_db_access(pool, target_user$id[[1]], enabled = enabled)
}

service_normalize_analysis_state_scope <- function(scope = "graphics") {
  scope <- trimws(scope %||% "graphics")
  if (!(scope %in% c("graphics", "statistics"))) {
    stop("不支持的分析状态范围")
  }
  scope
}

service_normalize_analysis_state_name <- function(state_name) {
  if (length(state_name) == 0 || is.null(state_name)) {
    state_name <- ""
  } else {
    state_name <- as.character(state_name[[1]])
  }
  state_name <- trimws(state_name)
  if (!nzchar(state_name)) {
    stop("请输入任务名称")
  }
  state_name
}

service_normalize_analysis_state_note <- function(state_note = NULL) {
  if (is.null(state_note) || length(state_note) == 0) {
    return(NULL)
  }
  state_note <- trimws(as.character(state_note[[1]]))
  if (!nzchar(state_note) || is.na(state_note)) {
    return(NULL)
  }
  state_note
}

service_analysis_state_db_scalar <- function(value) {
  if (is.null(value) || length(value) == 0) {
    return(NA_character_)
  }
  value <- value[[1]]
  if (is.na(value)) {
    return(NA_character_)
  }
  as.character(value)
}

service_normalize_analysis_state_workspace_id <- function(workspace_id = NULL) {
  if (is.null(workspace_id) || length(workspace_id) == 0) {
    return(NULL)
  }
  if (is.list(workspace_id) && !is.data.frame(workspace_id)) {
    if (!is.null(workspace_id$id)) {
      workspace_id <- workspace_id$id
    }
  }
  if (length(workspace_id) == 0 || is.null(workspace_id)) {
    return(NULL)
  }
  workspace_id <- as.character(workspace_id[[1]])
  if (!nzchar(trimws(workspace_id)) || is.na(workspace_id)) {
    return(NULL)
  }
  trimws(workspace_id)
}

service_normalize_analysis_state_payload <- function(payload) {
  if (is.character(payload) && length(payload) == 1 && nzchar(trimws(payload))) {
    parsed <- jsonlite::fromJSON(payload, simplifyVector = FALSE)
    return(jsonlite::toJSON(parsed, auto_unbox = TRUE, null = "null"))
  }
  jsonlite::toJSON(payload %||% list(), auto_unbox = TRUE, null = "null")
}

service_parse_analysis_state_payload <- function(payload_json) {
  payload_json <- trimws(payload_json %||% "")
  if (!nzchar(payload_json)) {
    return(list())
  }
  jsonlite::fromJSON(payload_json, simplifyVector = FALSE)
}

service_build_analysis_state_insert_spec <- function(state_id, user_id, workspace_id, scope, module_type, state_name, state_note, state_payload) {
  workspace_id <- service_normalize_analysis_state_workspace_id(workspace_id)
  state_note <- service_normalize_analysis_state_note(state_note)
  state_note_param <- service_analysis_state_db_scalar(state_note)
  if (is.null(workspace_id)) {
    return(list(
      sql = paste(
        "INSERT INTO analysis_states",
        "(id, user_id, workspace_id, scope, module_type, state_name, state_note, state_payload, created_at, updated_at)",
        "VALUES ($1, $2, NULL, $3, $4, $5, $6, $7, NOW(), NOW())"
      ),
      params = list(state_id, user_id, scope, module_type, state_name, state_note_param, state_payload)
    ))
  }
  list(
    sql = paste(
      "INSERT INTO analysis_states",
      "(id, user_id, workspace_id, scope, module_type, state_name, state_note, state_payload, created_at, updated_at)",
      "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())"
    ),
    params = list(state_id, user_id, workspace_id, scope, module_type, state_name, state_note_param, state_payload)
  )
}

service_list_analysis_states <- function(pool, user_id, scope = "graphics", module_type = NULL, workspace_id = NULL, match_workspace = TRUE) {
  if (!nzchar(user_id %||% "")) {
    return(data.frame())
  }
  scope <- service_normalize_analysis_state_scope(scope)
  workspace_id <- service_normalize_analysis_state_workspace_id(workspace_id)
  sql <- paste(
    "SELECT id, user_id, workspace_id, scope, module_type, state_name, state_note, state_payload, created_at, updated_at",
    "FROM analysis_states WHERE user_id = $1 AND scope = $2"
  )
  params <- list(user_id, scope)
  if (nzchar(module_type %||% "")) {
    sql <- paste(sql, sprintf("AND module_type = $%d", length(params) + 1))
    params[[length(params) + 1]] <- module_type
  }
  if (isTRUE(match_workspace)) {
    if (nzchar(workspace_id %||% "")) {
      sql <- paste(sql, sprintf("AND workspace_id = $%d", length(params) + 1))
      params[[length(params) + 1]] <- workspace_id
    } else {
      sql <- paste(sql, "AND workspace_id IS NULL")
    }
  }
  sql <- paste(sql, "ORDER BY updated_at DESC, created_at DESC")
  DBI::dbGetQuery(pool, sql, params = params)
}

service_get_analysis_state <- function(pool, state_id, user_id) {
  if (!nzchar(state_id %||% "") || !nzchar(user_id %||% "")) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    paste(
      "SELECT id, user_id, workspace_id, scope, module_type, state_name, state_note, state_payload, created_at, updated_at",
      "FROM analysis_states WHERE id = $1 AND user_id = $2 LIMIT 1"
    ),
    params = list(state_id, user_id)
  )
}

service_delete_analysis_state <- function(pool, state_id, user_id) {
  if (!nzchar(state_id %||% "") || !nzchar(user_id %||% "")) {
    return(invisible(0L))
  }
  DBI::dbExecute(
    pool,
    "DELETE FROM analysis_states WHERE id = $1 AND user_id = $2",
    params = list(state_id, user_id)
  )
}

service_save_analysis_state <- function(pool, user_id, module_type, state_name, payload, scope = "graphics", workspace_id = NULL, state_note = NULL) {
  if (!nzchar(user_id %||% "")) {
    stop("缺少用户信息")
  }
  if (length(module_type) == 0 || is.null(module_type)) {
    module_type <- ""
  } else {
    module_type <- trimws(as.character(module_type[[1]]))
  }
  if (!nzchar(module_type)) {
    stop("缺少模块类型")
  }
  scope <- service_normalize_analysis_state_scope(scope)
  state_name <- service_normalize_analysis_state_name(state_name)
  workspace_id <- service_normalize_analysis_state_workspace_id(workspace_id)
  state_note <- service_normalize_analysis_state_note(state_note)
  state_payload <- service_normalize_analysis_state_payload(payload)
  if (is.null(workspace_id)) {
    existing <- DBI::dbGetQuery(
      pool,
      paste(
        "SELECT id FROM analysis_states",
        "WHERE user_id = $1 AND scope = $2 AND module_type = $3 AND state_name = $4 AND workspace_id IS NULL",
        "LIMIT 1"
      ),
      params = list(user_id, scope, module_type, state_name)
    )
  } else {
    existing <- DBI::dbGetQuery(
      pool,
      paste(
        "SELECT id FROM analysis_states",
        "WHERE user_id = $1 AND scope = $2 AND module_type = $3 AND state_name = $4 AND workspace_id = $5",
        "LIMIT 1"
      ),
      params = list(user_id, scope, module_type, state_name, workspace_id)
    )
  }
  if (nrow(existing) > 0) {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE analysis_states SET state_payload = $1, state_note = $2, updated_at = NOW()",
        "WHERE id = $3"
      ),
      params = list(state_payload, service_analysis_state_db_scalar(state_note), existing$id[[1]])
    )
    return(invisible(existing$id[[1]]))
  }
  state_id <- auth_generate_id("ast")
  insert_spec <- service_build_analysis_state_insert_spec(
    state_id = state_id,
    user_id = user_id,
    workspace_id = workspace_id,
    scope = scope,
    module_type = module_type,
    state_name = state_name,
    state_note = state_note,
    state_payload = state_payload
  )
  DBI::dbExecute(pool, insert_spec$sql, params = insert_spec$params)
  invisible(state_id)
}
