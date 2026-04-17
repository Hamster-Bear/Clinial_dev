library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- if (length(script_path) > 0 && nzchar(script_path)) {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (basename(wd) == "tests") normalizePath(file.path(wd, ".."), winslash = "/", mustWork = TRUE) else wd
}

source(file.path(project_root, "modules", "common", "auth.R"), local = TRUE)
source(file.path(project_root, "modules", "common", "account_service.R"), local = TRUE)

load_env_file <- function(file_path) {
  if (!file.exists(file_path)) {
    return(invisible(FALSE))
  }
  lines <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
  for (line in lines) {
    trimmed <- trimws(line)
    if (!nzchar(trimmed) || startsWith(trimmed, "#")) {
      next
    }
    idx <- regexpr("=", trimmed, fixed = TRUE)[[1]]
    if (idx <= 1) {
      next
    }
    key <- trimws(substr(trimmed, 1, idx - 1))
    value <- trimws(substr(trimmed, idx + 1, nchar(trimmed)))
    do.call(Sys.setenv, stats::setNames(list(value), key))
  }
  invisible(TRUE)
}

load_env_file(file.path(project_root, ".env.test"))

with_env_vars <- function(vars, code) {
  old_values <- Sys.getenv(names(vars), unset = NA_character_)
  on.exit({
    for (key in names(old_values)) {
      old_value <- old_values[[key]]
      if (is.na(old_value)) {
        Sys.unsetenv(key)
      } else {
        do.call(Sys.setenv, stats::setNames(list(old_value), key))
      }
    }
  }, add = TRUE)
  for (key in names(vars)) {
    value <- vars[[key]]
    if (is.null(value) || identical(value, "")) {
      Sys.unsetenv(key)
    } else {
        do.call(Sys.setenv, stats::setNames(list(as.character(value)), key))
    }
  }
  force(code)
}

skip_if_no_test_db <- function() {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RPostgres", quietly = TRUE)) {
    skip("缺少 DBI 或 RPostgres，跳过 PostgreSQL 集成测试")
  }
  required_env <- c("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD")
  values <- Sys.getenv(required_env, "")
  if (any(!nzchar(values))) {
    skip("未检测到完整的 PostgreSQL 测试环境变量，跳过集成测试")
  }
}

with_isolated_auth_schema <- function(code) {
  skip_if_no_test_db()

  conn <- tryCatch(
    DBI::dbConnect(
      RPostgres::Postgres(),
      host = Sys.getenv("POSTGRES_HOST"),
      port = as.integer(Sys.getenv("POSTGRES_PORT")),
      dbname = Sys.getenv("POSTGRES_DB"),
      user = Sys.getenv("POSTGRES_USER"),
      password = Sys.getenv("POSTGRES_PASSWORD")
    ),
    error = function(e) {
      skip(paste0("PostgreSQL 测试库不可达：", e$message))
    }
  )
  on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

  schema_name <- paste0(
    "autotfl_auth_test_",
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    paste(sample(c(letters, 0:9), 6, replace = TRUE), collapse = "")
  )
  quoted_schema <- DBI::dbQuoteIdentifier(conn, schema_name)
  DBI::dbExecute(conn, paste("CREATE SCHEMA", quoted_schema))
  on.exit(
    try(DBI::dbExecute(conn, paste("DROP SCHEMA IF EXISTS", quoted_schema, "CASCADE")), silent = TRUE),
    add = TRUE
  )
  DBI::dbExecute(conn, paste("SET search_path TO", quoted_schema))
  auth_ensure_schema(conn)

  force(code)(conn, schema_name)
}

test_that("管理员初始化必须依赖完整环境变量", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(APP_ADMIN_USERNAME = "bootstrap_admin", APP_ADMIN_EMAIL = "", APP_ADMIN_PASSWORD = "StrongPass123"),
      {
        auth_ensure_bootstrap_admin(conn)
      }
    )
    expect_equal(nrow(auth_list_users(conn)), 0)

    with_env_vars(
      c(
        APP_ADMIN_USERNAME = "bootstrap_admin",
        APP_ADMIN_EMAIL = "bootstrap_admin@example.com",
        APP_ADMIN_PASSWORD = "StrongPass123"
      ),
      {
        auth_ensure_bootstrap_admin(conn)
      }
    )
    users <- auth_list_users(conn)
    expect_equal(nrow(users), 1)
    expect_true(isTRUE(users$is_admin[[1]]))
    expect_true(isTRUE(users$db_access_enabled[[1]]))
    expect_identical(users$email[[1]], "bootstrap_admin@example.com")
  })
})

test_that("自注册用户不会自动成为管理员", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(APP_ADMIN_USERNAME = "", APP_ADMIN_EMAIL = "", APP_ADMIN_PASSWORD = ""),
      {
        result <- auth_register_user(conn, "plain_user", "plain_user@example.com", "StrongPass123")
        expect_true(isTRUE(result$success))
        expect_false(isTRUE(result$user$is_admin))
      }
    )

    created <- auth_get_user_by_username(conn, "plain_user")
    expect_equal(nrow(created), 1)
    expect_false(isTRUE(created$is_admin[[1]]))
    expect_false(isTRUE(created$db_access_enabled[[1]]))
  })
})

test_that("管理员不能自动访问或管理其他用户数据空间", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(
        APP_ADMIN_USERNAME = "bootstrap_admin",
        APP_ADMIN_EMAIL = "bootstrap_admin@example.com",
        APP_ADMIN_PASSWORD = "StrongPass123"
      ),
      {
        auth_ensure_bootstrap_admin(conn)
      }
    )

    admin_row <- auth_get_user_by_username(conn, "bootstrap_admin")
    admin_user <- auth_build_user_payload(admin_row)

    alice_result <- auth_register_user(conn, "alice_user", "alice_user@example.com", "StrongPass123")
    bob_result <- auth_register_user(conn, "bob_user", "bob_user@example.com", "StrongPass123")
    expect_true(isTRUE(alice_result$success))
    expect_true(isTRUE(bob_result$success))

    admin_workspace <- service_create_workspace(conn, "admin-space", admin_user$id)
    alice_workspace <- service_create_workspace(conn, "alice-space", alice_result$user$id)
    auth_ensure_workspace_membership(conn, alice_workspace$id, bob_result$user$id, role = "viewer")

    admin_accessible <- auth_accessible_workspace_ids(conn, admin_user$id, is_admin = TRUE)
    alice_accessible <- auth_accessible_workspace_ids(conn, alice_result$user$id, is_admin = FALSE)
    bob_accessible <- auth_accessible_workspace_ids(conn, bob_result$user$id, is_admin = FALSE)

    expect_true(admin_workspace$id %in% admin_accessible)
    expect_false(alice_workspace$id %in% admin_accessible)
    expect_true(alice_workspace$id %in% alice_accessible)
    expect_true(alice_workspace$id %in% bob_accessible)

    expect_true(service_can_manage_workspace(conn, admin_workspace$id, admin_user))
    expect_false(service_can_manage_workspace(conn, alice_workspace$id, admin_user))
    expect_false(auth_user_can_access_workspace(conn, admin_user$id, is_admin = TRUE, alice_workspace$id))
    expect_true(auth_user_can_access_workspace(conn, bob_result$user$id, is_admin = FALSE, alice_workspace$id))
  })
})
