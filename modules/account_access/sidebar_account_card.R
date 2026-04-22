sidebar_account_card_styles <- function() {
  tags$style(HTML("
    .sidebar-user-card {
      margin: 12px;
      padding: 14px 14px 12px;
      border-radius: 14px;
      border: 1px solid #dfe7ef;
      background: #ffffff;
      color: #243447;
      box-shadow: 0 10px 24px rgba(31, 45, 61, 0.06);
    }
    .sidebar-user-card-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 10px;
    }
    .sidebar-user-name {
      font-weight: 700;
      font-size: 15px;
      color: #243447;
    }
    .sidebar-user-role {
      margin-top: 4px;
      color: #f39c12;
      font-size: 12px;
      font-weight: 600;
    }
    .sidebar-user-meta {
      margin-top: 6px;
      color: #6b7785;
      font-size: 12px;
      word-break: break-all;
    }
    .sidebar-user-summary {
      margin-top: 10px;
      color: #4f5f73;
      font-size: 12px;
      line-height: 1.5;
    }
    .sidebar-user-section-title {
      margin-top: 12px;
      margin-bottom: 8px;
      color: #7b8794;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }
    .sidebar-user-status-list {
      display: grid;
      gap: 8px;
    }
    .sidebar-user-status-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      padding: 8px 10px;
      border-radius: 8px;
      border: 1px solid #e8eef5;
      background: #f8fbff;
      font-size: 12px;
      color: #4f5f73;
    }
    .sidebar-user-status-item strong {
      font-weight: 600;
      color: #243447;
    }
    .sidebar-user-status-badge {
      display: inline-flex;
      align-items: center;
      padding: 2px 8px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 700;
      white-space: nowrap;
    }
    .sidebar-user-status-badge--success {
      background: rgba(0, 166, 90, 0.22);
      color: #7ef0b4;
    }
    .sidebar-user-status-badge--warning {
      background: rgba(243, 156, 18, 0.22);
      color: #ffd27a;
    }
    .sidebar-user-status-badge--info {
      background: rgba(60, 141, 188, 0.22);
      color: #9fd8ff;
    }
    .sidebar-user-actions {
      margin-top: 12px;
      display: grid;
      gap: 8px;
    }
    .sidebar-user-actions a {
      color: #3c4b5b !important;
      display: block;
      padding: 8px 10px;
      border-radius: 8px;
      border: 1px solid #d2d9e1;
      background: #f8fafc;
      text-align: center;
      font-size: 12px;
      font-weight: 600;
      text-decoration: none !important;
    }
    .sidebar-user-actions a:hover,
    .sidebar-user-actions a:focus {
      background: #eef3f8;
      color: #1f2d3d !important;
    }
    .sidebar-user-quick-entry {
      padding: 4px 10px !important;
      border-radius: 999px !important;
      border: none !important;
      background: #3c8dbc !important;
      color: #ffffff !important;
      font-size: 12px !important;
      white-space: nowrap;
    }
    /* Hidden internal routes: keep tab wiring alive but never expose them as sidebar menu items. */
    section.sidebar li[data-value='user_profile'],
    section.sidebar li[data-value='access_permissions'],
    section.sidebar a[data-value='user_profile'],
    section.sidebar a[data-value='access_permissions'],
    section.sidebar a[href='#shiny-tab-user_profile'],
    section.sidebar a[href='#shiny-tab-access_permissions'] {
      display: none !important;
    }
  "))
}

sidebar_account_card_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("panel"))
}

sidebar_account_card_server <- function(
    id,
    pg_pool,
    current_user = NULL,
    user_has_database_access = NULL,
    goto_tab = NULL,
    on_logout = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
    copy <- ACCOUNT_ENTRY_COPY

    can_use_database <- function(user) {
      if (is.null(user_has_database_access) || !is.function(user_has_database_access)) {
        return(FALSE)
      }
      isTRUE(user_has_database_access(user))
    }

    navigate_to <- function(tab_name) {
      if (!is.null(goto_tab) && is.function(goto_tab)) {
        goto_tab(tab_name)
      }
      invisible(tab_name)
    }

    output$panel <- renderUI({
      user <- if (is.null(current_user)) NULL else current_user()
      if (is.null(user)) {
        return(NULL)
      }
      manageable_df <- service_list_manageable_workspaces(pg_pool, user)
      manageable_count <- nrow(manageable_df)
      accessible_count <- length(auth_accessible_workspace_ids(pg_pool, user$id, isTRUE(user$is_admin)))
      database_access_label <- if (can_use_database(user)) {
        copy$status$database_enabled
      } else {
        copy$status$database_disabled
      }
      email_status_label <- if (isTRUE(user$email_verified)) {
        copy$status$email_verified
      } else {
        copy$status$email_unverified
      }
      email_status_badge_class <- if (isTRUE(user$email_verified)) {
        "sidebar-user-status-badge sidebar-user-status-badge--success"
      } else {
        "sidebar-user-status-badge sidebar-user-status-badge--warning"
      }
      database_status_badge_class <- if (can_use_database(user)) {
        "sidebar-user-status-badge sidebar-user-status-badge--info"
      } else {
        "sidebar-user-status-badge sidebar-user-status-badge--warning"
      }

      div(
        class = "sidebar-user-card",
        div(
          class = "sidebar-user-card-header",
          div(
            div(class = "sidebar-user-name", user$username),
            if (isTRUE(user$is_admin)) div(class = "sidebar-user-role", copy$status$role_admin)
          ),
          if (isTRUE(user$is_admin)) {
            actionButton(session$ns("open_admin"), copy$actions$admin, icon = icon("users"), class = "sidebar-user-quick-entry")
          } else if (can_use_database(user)) {
            actionButton(session$ns("open_db_manage"), copy$actions$db_manage, icon = icon("database"), class = "sidebar-user-quick-entry")
          } else {
            actionButton(session$ns("open_data_prep"), copy$actions$data_prep, icon = icon("upload"), class = "sidebar-user-quick-entry")
          }
        ),
        div(class = "sidebar-user-meta", if (nzchar(user$email %||% "")) user$email else copy$copy$no_email),
        div(class = "sidebar-user-section-title", copy$sections$account),
        div(
          class = "sidebar-user-summary",
          copy$copy$account_summary
        ),
        div(
          class = "sidebar-user-status-list",
          div(
            class = "sidebar-user-status-item",
            tags$strong(copy$status$email),
            tags$span(class = email_status_badge_class, email_status_label)
          ),
          div(
            class = "sidebar-user-status-item",
            tags$strong(copy$status$database),
            tags$span(class = database_status_badge_class, database_access_label)
          )
        ),
        div(class = "sidebar-user-section-title", copy$sections$workspace),
        div(
          class = "sidebar-user-summary",
          paste0(copy$copy$workspace_manageable_prefix, manageable_count),
          br(),
          paste0(copy$copy$workspace_accessible_prefix, accessible_count)
        ),
        div(
          class = "sidebar-user-actions",
          if (!isTRUE(user$is_admin)) actionLink(session$ns("open_user_profile"), copy$actions$profile),
          if (!isTRUE(user$is_admin)) actionLink(session$ns("open_access_permissions"), copy$actions$permissions),
          actionLink(session$ns("logout_submit"), copy$actions$logout)
        )
      )
    })

    observeEvent(input$open_user_profile, {
      navigate_to(copy$page_keys$profile)
    })

    observeEvent(input$open_access_permissions, {
      navigate_to(copy$page_keys$permissions)
    })

    observeEvent(input$open_db_manage, {
      navigate_to(copy$page_keys$db_manage)
    })

    observeEvent(input$open_data_prep, {
      navigate_to(copy$page_keys$data_prep)
    })

    observeEvent(input$open_admin, {
      navigate_to(copy$page_keys$admin)
    })

    observeEvent(input$logout_submit, {
      if (!is.null(on_logout) && is.function(on_logout)) {
        on_logout()
      }
    })
  })
}
