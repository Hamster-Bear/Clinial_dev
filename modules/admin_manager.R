admin_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
        .admin-shell {
          padding-bottom: 8px;
        }
        .admin-equal-row {
          display: flex;
          flex-wrap: wrap;
          margin-left: -15px;
          margin-right: -15px;
        }
        .admin-equal-row > [class*='col-'] {
          display: flex;
          margin-bottom: 16px;
        }
        .admin-equal-row > [class*='col-'] > .app-card.box,
        .admin-equal-row > [class*='col-'] > .nav-tabs-custom {
          width: 100%;
        }
        .admin-shell .app-card__note {
          margin-top: 0;
          margin-bottom: 12px;
        }
        .admin-runtime-pre {
          margin: 0;
          padding: 0;
          border: 0;
          background: transparent;
          color: #4f5f73;
          font-size: 13px;
          line-height: 1.7;
          white-space: pre-wrap;
          word-break: break-word;
        }
        .admin-shell .nav-tabs-custom {
          border-radius: 14px;
          border: 1px solid #e7edf4;
          box-shadow: 0 10px 24px rgba(31, 45, 61, 0.06);
          overflow: hidden;
          background: #fff;
        }
        .admin-shell .nav-tabs-custom > .nav-tabs {
          background: #ffffff;
          border-bottom: 1px solid #edf2f7;
          padding: 0 10px;
        }
        .admin-shell .nav-tabs-custom > .nav-tabs > li > a {
          color: #4f5f73;
          font-weight: 500;
        }
        .admin-shell .nav-tabs-custom > .nav-tabs > li.active > a {
          color: #243447;
        }
        .admin-shell .nav-tabs-custom > .tab-content {
          padding: 14px 16px 16px;
        }
        .admin-impact-card {
          margin-top: 10px;
          background: #fff9ef;
          border: 1px solid #f4d7aa;
          color: #7a5a18;
          line-height: 1.7;
        }
        .admin-impact-card strong {
          color: #7a5a18;
        }
        .admin-risk-list {
          margin: 0;
          padding-left: 18px;
          color: #4f5f73;
          line-height: 1.8;
        }
        .admin-risk-actions {
          margin-top: 12px;
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }
        .admin-risk-anchor {
          scroll-margin-top: 80px;
        }
        .admin-compact-grid {
          grid-template-columns: repeat(auto-fit, minmax(132px, 1fr));
          gap: 10px;
          margin-bottom: 0;
        }
        .admin-compact-grid .app-stat-card {
          min-height: 86px;
          padding: 12px 14px;
          box-shadow: 0 6px 16px rgba(31, 45, 61, 0.05);
        }
        .admin-compact-grid .app-stat-card__label,
        .admin-compact-grid .app-stat-card__meta {
          font-size: 11px;
          line-height: 1.45;
        }
        .admin-compact-grid .app-stat-card__value {
          font-size: 22px;
          margin-top: 4px;
        }
        .admin-management-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
          gap: 12px;
        }
        .admin-management-grid .app-card__panel {
          margin-bottom: 0;
        }
        .admin-management-panel {
          padding: 12px 14px;
        }
        .admin-section-heading {
          color: #243447;
          font-weight: 700;
          margin-bottom: 4px;
        }
        .admin-section-note {
          color: #5f6b7a;
          font-size: 12px;
          line-height: 1.6;
          margin-bottom: 10px;
        }
        .admin-shell .app-action-row {
          margin-top: 8px;
        }
        .admin-shell .app-action-btn {
          min-width: 118px;
        }
        .admin-toolbar {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          margin: 10px 0 14px;
        }
        .admin-toolbar .btn {
          border-radius: 999px;
          padding: 6px 14px;
        }
        .admin-toolbar .btn.active {
          box-shadow: none;
          border-width: 1px;
        }
        .admin-filter-note {
          display: flex;
          justify-content: space-between;
          align-items: center;
          flex-wrap: wrap;
          gap: 8px;
          margin-bottom: 12px;
          padding: 10px 12px;
          border-radius: 10px;
          background: #f7fafc;
          color: #5f6b7a;
        }
        .admin-filter-note strong {
          color: #243447;
        }
      "))
    ),
    fluidRow(
      app_card_box(
        width = 12,
        title = "系统管理入口",
        subtitle = "集中处理系统级账号状态、数据空间权限与协作排障入口",
        tone = "info",
        status = "info",
        solidHeader = FALSE,
        uiOutput(ns("admin_access_notice"))
      )
    ),
    div(class = "admin-shell", uiOutput(ns("admin_content")))
  )
}

admin_manager_server <- function(id, pg_pool, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
    admin_stat_grid <- function(..., class = NULL) {
      tags$div(class = trimws(paste("app-stat-grid", class)), ...)
    }
    admin_stat_item <- function(label, value, tone = "primary", meta = NULL, chips = NULL) {
      app_stat_card(
        label = label,
        value = as.character(value %||% ""),
        meta = meta,
        tone = tone,
        chips = chips
      )
    }
    admin_panel <- function(..., class = NULL) {
      tags$div(class = trimws(paste("app-card__panel", class)), ...)
    }
    refresh_tick <- reactiveVal(0)
    smtp_probe_last_result <- reactiveVal(list(
      status = "idle",
      email = "",
      message = "尚未发送探针邮件",
      at = ""
    ))
    registry_filter_mode <- reactiveVal("all")
    registry_filter_labels <- c(
      all = "全部账号",
      admin = "只看管理员",
      inactive = "只看停用账号",
      no_email = "只看未设置邮箱",
      db_locked = "只看未开通数据空间功能",
      pending = "只看待领取邀请"
    )

    get_current_user <- function() {
      if (is.null(current_user)) {
        return(NULL)
      }
      isolate(current_user())
    }

    is_admin <- reactive({
      user <- get_current_user()
      !is.null(user) && isTRUE(user$is_admin)
    })

    list_users <- reactive({
      req(is_admin())
      service_list_users(pg_pool)
    })

    list_manageable_workspaces <- reactive({
      req(is_admin())
      service_list_manageable_workspaces(pg_pool, get_current_user())
    })

    list_manageable_memberships <- reactive({
      req(is_admin())
      workspaces_df <- list_manageable_workspaces()
      if (nrow(workspaces_df) == 0) {
        return(data.frame())
      }
      do.call(
        rbind,
        lapply(workspaces_df$id, function(workspace_id) {
          service_list_workspace_memberships(pg_pool, workspace_id = workspace_id)
        })
      )
    })

    list_manageable_invites <- reactive({
      req(is_admin())
      workspaces_df <- list_manageable_workspaces()
      if (nrow(workspaces_df) == 0) {
        return(data.frame())
      }
      do.call(
        rbind,
        lapply(workspaces_df$id, function(workspace_id) {
          service_list_workspace_invites(pg_pool, workspace_id = workspace_id)
        })
      )
    })

    selected_manage_workspace_id <- reactive({
      req(is_admin())
      workspaces_df <- list_manageable_workspaces()
      if (nrow(workspaces_df) == 0) {
        return("")
      }
      workspace_ids <- workspaces_df$id %||% character(0)
      selected_id <- input$workspace_manage_select %||% ""
      if (nzchar(selected_id) && selected_id %in% workspace_ids) {
        selected_id
      } else {
        workspace_ids[[1]] %||% ""
      }
    })

    filtered_registry_users <- reactive({
      req(is_admin())
      users_df <- list_users()
      registry_df <- build_user_registry_overview_df(users_df)
      if (nrow(registry_df) == 0) {
        return(users_df[0, , drop = FALSE])
      }
      keep_idx <- switch(
        registry_filter_mode(),
        inactive = which(registry_df$账号状态 %in% "已停用"),
        no_email = which(registry_df$联系邮箱 %in% "未设置"),
        db_locked = which(registry_df$数据空间功能 %in% "未开通"),
        pending = which(registry_df$待领取邀请 > 0),
        admin = which(registry_df$管理员身份 %in% "是"),
        seq_len(nrow(registry_df))
      )
      users_df[keep_idx, , drop = FALSE]
    })

    get_target_user_row <- reactive({
      req(is_admin())
      selected_idx <- input$admin_user_registry_table_rows_selected %||% integer(0)
      users_df <- filtered_registry_users()
      if (length(selected_idx) == 0 || nrow(users_df) == 0) {
        return(data.frame())
      }
      row_idx <- selected_idx[[1]]
      if (is.na(row_idx) || row_idx < 1 || row_idx > nrow(users_df)) {
        return(data.frame())
      }
      users_df[row_idx, , drop = FALSE]
    })

    build_workspace_overview_df <- function(workspaces_df) {
      if (is.null(workspaces_df) || !is.data.frame(workspaces_df) || nrow(workspaces_df) == 0) {
        return(data.frame(
          数据空间 = character(0),
          当前成员数 = integer(0),
          待领取邀请 = integer(0),
          协作状态 = character(0),
          创建时间 = character(0),
          check.names = FALSE,
          stringsAsFactors = FALSE
        ))
      }
      memberships_df <- list_manageable_memberships()
      invites_df <- list_manageable_invites()
      data.frame(
        数据空间 = workspaces_df$name %||% "",
        当前成员数 = vapply(workspaces_df$id, function(workspace_id) {
          if (nrow(memberships_df) == 0) return(0L)
          sum((memberships_df$workspace_id %||% character(0)) == workspace_id)
        }, integer(1)),
        待领取邀请 = vapply(workspaces_df$id, function(workspace_id) {
          if (nrow(invites_df) == 0) return(0L)
          sum((invites_df$workspace_id %||% character(0)) == workspace_id & (invites_df$status %||% character(0)) == "pending")
        }, integer(1)),
        协作状态 = vapply(workspaces_df$id, function(workspace_id) {
          member_count <- if (nrow(memberships_df) == 0) 0L else sum((memberships_df$workspace_id %||% character(0)) == workspace_id)
          pending_count <- if (nrow(invites_df) == 0) 0L else sum((invites_df$workspace_id %||% character(0)) == workspace_id & (invites_df$status %||% character(0)) == "pending")
          if (pending_count > 0) {
            "有待领取邀请"
          } else if (member_count > 1) {
            "已共享"
          } else {
            "仅负责人可见"
          }
        }, character(1)),
        创建时间 = service_format_datetime(workspaces_df$created_at),
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    }

    build_user_registry_overview_df <- function(users_df) {
      if (is.null(users_df) || !is.data.frame(users_df) || nrow(users_df) == 0) {
        return(data.frame(
          账号名 = character(0),
          联系邮箱 = character(0),
          管理员身份 = character(0),
          账号状态 = character(0),
          数据空间功能 = character(0),
          名下数据空间 = integer(0),
          当前可访问空间 = integer(0),
          待领取邀请 = integer(0),
          创建时间 = character(0),
          check.names = FALSE,
          stringsAsFactors = FALSE
        ))
      }
      all_workspaces <- service_list_workspaces(pg_pool)
      all_invites <- service_list_workspace_invites(pg_pool)
      user_emails <- users_df$email %||% character(0)
      user_admin_flags <- users_df$is_admin %||% logical(0)
      user_db_access_flags <- users_df$db_access_enabled %||% logical(0)
      data.frame(
        账号名 = users_df$username %||% "",
        联系邮箱 = ifelse(is.na(user_emails) | !nzchar(user_emails), "未设置", user_emails),
        管理员身份 = ifelse(user_admin_flags, "是", "否"),
        账号状态 = vapply(users_df$status %||% character(0), service_label_user_status, character(1)),
        数据空间功能 = vapply(user_admin_flags | user_db_access_flags, service_label_db_access_status, character(1)),
        名下数据空间 = vapply(users_df$id %||% character(0), function(user_id) {
          if (nrow(all_workspaces) == 0) return(0L)
          sum((all_workspaces$owner_user_id %||% character(0)) == user_id)
        }, integer(1)),
        当前可访问空间 = vapply(seq_len(nrow(users_df)), function(i) {
          length(auth_accessible_workspace_ids(
            pg_pool,
            users_df$id[[i]] %||% "",
            isTRUE(user_admin_flags[[i]])
          ))
        }, integer(1)),
        待领取邀请 = vapply(seq_len(nrow(users_df)), function(i) {
          user_email <- user_emails[[i]] %||% ""
          if (!nzchar(user_email) || nrow(all_invites) == 0) return(0L)
          sum((all_invites$invited_email %||% character(0)) == user_email & (all_invites$status %||% character(0)) == "pending")
        }, integer(1)),
        创建时间 = service_format_datetime(users_df$created_at),
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    }

    filter_user_registry_df <- function(registry_df, mode) {
      if (is.null(registry_df) || !is.data.frame(registry_df) || nrow(registry_df) == 0) {
        return(registry_df)
      }
      switch(
        mode,
        inactive = registry_df[registry_df$账号状态 %in% "已停用", , drop = FALSE],
        no_email = registry_df[registry_df$联系邮箱 %in% "未设置", , drop = FALSE],
        db_locked = registry_df[registry_df$数据空间功能 %in% "未开通", , drop = FALSE],
        pending = registry_df[registry_df$待领取邀请 > 0, , drop = FALSE],
        admin = registry_df[registry_df$管理员身份 %in% "是", , drop = FALSE],
        registry_df
      )
    }

    output$admin_access_notice <- renderUI({
      if (isTRUE(is_admin())) {
        app_card_note(
          "当前页面仅面向系统管理员，用于执行账号状态调整、数据库管理权限开关和查看数据库信息。若需要处理数据空间负责人或协作授权，仅限当前管理员自己名下可管理的数据空间。管理员入口保持独立，不并入普通用户侧边栏卡片。"
        )
      } else {
        app_card_note("当前页面仅系统管理员可用。")
      }
    })

    output$admin_content <- renderUI({
      if (!isTRUE(is_admin())) {
        return(NULL)
      }
      users_df <- list_users()
      workspaces_df <- list_manageable_workspaces()
      workspace_choices <- if (nrow(workspaces_df) == 0) character(0) else setNames(workspaces_df$id, workspaces_df$name)
      tagList(
        div(
          class = "row admin-equal-row",
          app_card_box(
            width = 4,
            title = "系统概览",
            subtitle = "摘要优先查看当前管理员与账号总体态势",
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
            uiOutput(session$ns("admin_system_overview"))
          ),
          app_card_box(
            width = 4,
            title = "异常态势摘要",
            subtitle = "聚焦停用账号、未设置邮箱与待领取邀请等风险",
            tone = "warning",
            status = "warning",
            solidHeader = FALSE,
            uiOutput(session$ns("admin_risk_overview"))
          ),
          app_card_box(
            width = 4,
            title = "运行环境",
            subtitle = "快速核对数据库与管理员预置环境变量",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            app_card_panel(
              tags$pre(
                class = "admin-runtime-pre",
                textOutput(session$ns("admin_runtime_meta"))
              )
            )
          ),
        ),
        div(
          class = "row admin-equal-row",
          app_card_box(
            width = 8,
            title = "所有注册账号总览",
            subtitle = "按元信息统一筛查账号状态、数据空间功能与协作概况",
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
            app_card_note("仅展示所有已注册账号的元信息、数据空间功能状态和协作摘要，便于系统管理员统一排查与筛查；不展示其他用户数据空间中的实际数据内容。"),
            uiOutput(session$ns("admin_user_registry_summary")),
            uiOutput(session$ns("admin_user_registry_filters")),
            uiOutput(session$ns("admin_user_registry_filter_note")),
            DTOutput(session$ns("admin_user_registry_table"))
          ),
          app_card_box(
            width = 4,
            title = "SMTP 连通性测试",
            subtitle = "管理员可向测试邮箱发送探针邮件验证投递链路",
            tone = "success",
            status = "success",
            solidHeader = FALSE,
            app_card_note("仅用于验证当前邮件投递配置是否可达。建议先使用管理员自己的测试邮箱或预发收件箱验收。"),
            textInput(
              session$ns("smtp_probe_email"),
              "测试收件邮箱",
              value = get_current_user()$email %||% "",
              placeholder = "请输入用于接收探针邮件的邮箱"
            ),
            div(
              class = "app-action-row",
              actionButton(session$ns("smtp_probe_send"), "发送探针邮件", class = "btn-success app-action-btn")
            ),
            app_card_panel(
              tags$pre(
                class = "admin-runtime-pre",
                textOutput(session$ns("admin_smtp_probe_meta"))
              )
            ),
            app_card_panel(
              tags$pre(
                class = "admin-runtime-pre",
                textOutput(session$ns("admin_smtp_probe_last_result"))
              )
            )
          )
        ),
        div(
          class = "row admin-equal-row",
          app_card_box(
            width = 5,
            title = "账号状态管理",
            subtitle = "从上方账号总览联动目标账号后执行启停与开关",
            tone = "warning",
            status = "warning",
            solidHeader = FALSE,
            div(id = session$ns("admin_account_section"), class = "admin-risk-anchor"),
            app_card_note("先在上方“所有注册账号总览”中选中目标账号，再根据状态卡片与操作影响预览决定启用、停用或开关数据空间功能。"),
            uiOutput(session$ns("admin_user_meta_card")),
            uiOutput(session$ns("admin_action_hint")),
            div(
              class = "app-action-row",
              actionButton(session$ns("activate_user"), "启用账号", class = "btn-success app-action-btn"),
              actionButton(session$ns("deactivate_user"), "停用账号", class = "btn-danger app-action-btn"),
              actionButton(session$ns("grant_db_access"), "开放数据库", class = "btn-primary app-action-btn"),
              actionButton(session$ns("revoke_db_access"), "锁定数据库", class = "btn-default app-action-btn")
            )
          ),
          app_card_box(
            width = 7,
            title = "数据空间管理",
            subtitle = "合并处理我名下空间的负责人调整与协作授权",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            div(id = session$ns("admin_workspace_manage_section"), class = "admin-risk-anchor"),
            app_card_note("当前卡片统一处理我名下数据空间的负责人迁移、协作授权与待领取邀请跟进，不展示库内用户选择器。"),
            selectInput(session$ns("workspace_manage_select"), "选择目标数据空间", choices = workspace_choices),
            uiOutput(session$ns("admin_workspace_manage_summary")),
            div(
              class = "admin-management-grid",
              app_card_panel(
                div(class = "admin-section-heading", "负责人调整"),
                div(class = "admin-section-note", "适合处理负责人迁移或注册前先发送待领取 owner 记录。"),
                textInput(session$ns("owner_email"), "新负责人邮箱", placeholder = "请输入负责人邮箱"),
                div(
                  class = "app-action-row",
                  actionButton(session$ns("assign_owner"), "绑定负责人", class = "btn-primary app-action-btn")
                ),
                class = "admin-management-panel"
              ),
              app_card_panel(
                div(class = "admin-section-heading", "协作授权"),
                div(class = "admin-section-note", "通过邮箱授予或撤销 viewer/editor 权限，便于跟进待领取邀请。"),
                textInput(session$ns("membership_email"), "协作者邮箱", placeholder = "请输入协作者邮箱"),
                selectInput(
                  session$ns("membership_role"),
                  "协作权限等级",
                  choices = c("只读成员" = "viewer", "可编辑成员" = "editor"),
                  selected = "viewer"
                ),
                div(
                  class = "app-action-row",
                  actionButton(session$ns("assign_membership"), "发送授权", class = "btn-info app-action-btn"),
                  actionButton(session$ns("revoke_membership"), "撤销协作", class = "btn-danger app-action-btn")
                ),
                class = "admin-management-panel"
              )
            )
          )
        ),
        div(
          class = "row admin-equal-row",
          app_card_box(
            width = 6,
            title = "我名下数据空间概览",
            subtitle = "仅展示当前管理员可管理的数据空间元信息",
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
            div(id = session$ns("admin_workspace_summary_section"), class = "admin-risk-anchor"),
            app_card_note("仅展示当前管理员自己名下可管理的数据空间元信息，用于快速判断共享状态、待领取邀请和负责人迁移风险。"),
            DTOutput(session$ns("admin_workspace_summary_table"))
          ),
          tabBox(
            width = 6,
            title = "我名下空间协作预览",
            id = session$ns("admin_preview_tabs"),
            tabPanel("当前成员", DTOutput(session$ns("membership_table"))),
            tabPanel("待领取邀请", DTOutput(session$ns("invite_table")))
          )
        )
      )
    })

    output$admin_system_overview <- renderUI({
      req(is_admin())
      users_df <- list_users()
      workspaces_df <- list_manageable_workspaces()
      invites_df <- list_manageable_invites()
      current <- get_current_user()
      admin_stat_grid(
        admin_stat_item("当前管理员", current$username %||% "未识别", tone = "primary"),
        admin_stat_item("当前库用户数", nrow(users_df), tone = "info"),
        admin_stat_item("正常账号数", sum((users_df$status %||% character(0)) == "active"), tone = "success"),
        admin_stat_item("已开通数据空间功能", sum((users_df$is_admin %||% logical(0)) | (users_df$db_access_enabled %||% logical(0)), na.rm = TRUE), tone = "warning"),
        admin_stat_item("我名下数据空间", nrow(workspaces_df), tone = "primary"),
        admin_stat_item("我名下待领取邀请", sum((invites_df$status %||% character(0)) == "pending"), tone = "danger"),
        class = "admin-compact-grid"
      )
    })

    output$admin_runtime_meta <- renderText({
      req(is_admin())
      paste0(
        "数据库主机: ", Sys.getenv("POSTGRES_HOST", "未设置"), "\n",
        "数据库名称: ", Sys.getenv("POSTGRES_DB", "未设置"), "\n",
        "数据库端口: ", Sys.getenv("POSTGRES_PORT", "未设置"), "\n",
        "邮件模式: ", Sys.getenv("EMAIL_DELIVERY_MODE", "console"), "\n",
        "发件邮箱: ", ifelse(nzchar(Sys.getenv("EMAIL_FROM_ADDRESS", "")), Sys.getenv("EMAIL_FROM_ADDRESS", ""), "未设置"), "\n",
        "SMTP_HOST: ", ifelse(nzchar(Sys.getenv("SMTP_HOST", "")), Sys.getenv("SMTP_HOST", ""), "未设置"), "\n",
        "SMTP_PORT: ", ifelse(nzchar(Sys.getenv("SMTP_PORT", "")), Sys.getenv("SMTP_PORT", ""), "未设置"), "\n",
        "管理员环境变量用户名: ", ifelse(nzchar(Sys.getenv("APP_ADMIN_USERNAME", "")), Sys.getenv("APP_ADMIN_USERNAME", ""), "未设置"), "\n",
        "管理员环境变量邮箱: ", ifelse(nzchar(Sys.getenv("APP_ADMIN_EMAIL", "")), Sys.getenv("APP_ADMIN_EMAIL", ""), "未设置"), "\n",
        "管理员引导配置: ", ifelse(
          nzchar(Sys.getenv("APP_ADMIN_USERNAME", "")) && nzchar(Sys.getenv("APP_ADMIN_EMAIL", "")) && nzchar(Sys.getenv("APP_ADMIN_PASSWORD", "")),
          "已提供",
          "未提供"
        )
      )
    })

    output$admin_smtp_probe_meta <- renderText({
      req(is_admin())
      email_service_probe_summary()
    })

    output$admin_smtp_probe_last_result <- renderText({
      req(is_admin())
      result <- smtp_probe_last_result()
      paste0(
        "最近一次探针状态: ",
        switch(
          result$status %||% "idle",
          success = "成功",
          error = "失败",
          idle = "未执行",
          result$status %||% "未执行"
        ),
        "\n",
        "目标邮箱: ", if (nzchar(result$email %||% "")) result$email else "未设置", "\n",
        "执行时间: ", if (nzchar(result$at %||% "")) result$at else "未执行", "\n",
        "结果说明: ", result$message %||% ""
      )
    })

    output$admin_user_registry_table <- renderDT({
      req(is_admin())
      refresh_tick()
      users_df <- list_users()
      registry_df <- build_user_registry_overview_df(users_df)
      registry_df <- filter_user_registry_df(registry_df, registry_filter_mode())
      datatable(
        registry_df,
        rownames = FALSE,
        filter = "top",
        selection = "single",
        options = list(pageLength = 10, scrollX = TRUE, dom = "ftip")
      )
    })

    output$admin_user_registry_summary <- renderUI({
      req(is_admin())
      refresh_tick()
      registry_df <- build_user_registry_overview_df(list_users())
      admin_stat_grid(
        admin_stat_item("注册账号总数", nrow(registry_df), tone = "primary"),
        admin_stat_item("系统管理员", sum(registry_df$管理员身份 %in% "是"), tone = "info"),
        admin_stat_item("停用账号", sum(registry_df$账号状态 %in% "已停用"), tone = "warning"),
        admin_stat_item("未设置邮箱", sum(registry_df$联系邮箱 %in% "未设置"), tone = "danger"),
        admin_stat_item("未开通数据空间功能", sum(registry_df$数据空间功能 %in% "未开通"), tone = "warning"),
        admin_stat_item("待领取邀请账号", sum(registry_df$待领取邀请 > 0), tone = "success")
      )
    })

    output$admin_user_registry_filters <- renderUI({
      req(is_admin())
      current_mode <- registry_filter_mode()
      filter_button <- function(id, label, mode, class_name = "btn-default") {
        extra_class <- if (identical(current_mode, mode)) "active" else ""
        actionButton(
          session$ns(id),
          label,
          class = paste("btn btn-sm", class_name, extra_class)
        )
      }
      tags$div(
        class = "admin-toolbar",
        filter_button("registry_filter_all", "全部账号", "all", "btn-default"),
        filter_button("registry_filter_admin", "只看管理员", "admin", "btn-danger"),
        filter_button("registry_filter_inactive", "只看停用账号", "inactive", "btn-warning"),
        filter_button("registry_filter_no_email", "只看未设置邮箱", "no_email", "btn-info"),
        filter_button("registry_filter_db_locked", "只看未开通数据空间功能", "db_locked", "btn-primary"),
        filter_button("registry_filter_pending", "只看待领取邀请", "pending", "btn-success")
      )
    })

    output$admin_user_registry_filter_note <- renderUI({
      req(is_admin())
      current_mode <- registry_filter_mode()
      label <- registry_filter_labels[[current_mode]] %||% registry_filter_labels[["all"]]
      tags$div(
        class = "admin-filter-note",
        tags$span(HTML(paste0("当前视图: <strong>", label, "</strong>"))),
        tags$span("点击表格行即可把该账号直接带入下方状态管理。")
      )
    })

    observeEvent(input$registry_filter_all, {
      registry_filter_mode("all")
    })

    observeEvent(input$registry_filter_admin, {
      registry_filter_mode("admin")
    })

    observeEvent(input$registry_filter_inactive, {
      registry_filter_mode("inactive")
    })

    observeEvent(input$registry_filter_no_email, {
      registry_filter_mode("no_email")
    })

    observeEvent(input$registry_filter_db_locked, {
      registry_filter_mode("db_locked")
    })

    observeEvent(input$registry_filter_pending, {
      registry_filter_mode("pending")
    })

    output$admin_risk_overview <- renderUI({
      req(is_admin())
      users_df <- list_users()
      workspaces_df <- list_manageable_workspaces()
      invites_df <- list_manageable_invites()
      memberships_df <- list_manageable_memberships()

      safe_email <- users_df$email %||% character(0)
      inactive_count <- sum((users_df$status %||% character(0)) == "inactive")
      no_email_count <- sum(!nzchar(safe_email))
      db_locked_count <- sum(!((users_df$is_admin %||% logical(0)) | (users_df$db_access_enabled %||% logical(0))), na.rm = TRUE)
      pending_invite_count <- sum((invites_df$status %||% character(0)) == "pending")
      unclaimed_email_count <- if (nrow(invites_df) == 0) {
        0L
      } else {
        registered_emails <- unique(safe_email[nzchar(safe_email)])
        sum((invites_df$status %||% character(0)) == "pending" & !((invites_df$invited_email %||% character(0)) %in% registered_emails))
      }
      workspace_pending_count <- if (nrow(workspaces_df) == 0 || nrow(invites_df) == 0) {
        0L
      } else {
        sum(vapply(workspaces_df$id, function(workspace_id) {
          any((invites_df$workspace_id %||% character(0)) == workspace_id & (invites_df$status %||% character(0)) == "pending")
        }, logical(1)))
      }
      owner_only_count <- if (nrow(workspaces_df) == 0) {
        0L
      } else {
        sum(vapply(workspaces_df$id, function(workspace_id) {
          member_count <- if (nrow(memberships_df) == 0) 0L else sum((memberships_df$workspace_id %||% character(0)) == workspace_id)
          member_count <= 1L
        }, logical(1)))
      }

      risk_messages <- c(
        if (inactive_count > 0) paste0("当前有 ", inactive_count, " 个停用账号，必要时需核对是否仍为有效业务用户。"),
        if (no_email_count > 0) paste0("当前有 ", no_email_count, " 个账号未设置邮箱，这会影响邀请领取、负责人迁移与账号找回。"),
        if (db_locked_count > 0) paste0("当前有 ", db_locked_count, " 个账号未开通数据空间功能，这些用户只能走数据准备页的临时上传链路。"),
        if (pending_invite_count > 0) paste0("当前管理员自己名下共有 ", pending_invite_count, " 条待领取邀请，建议定期清理长期未领取记录。"),
        if (unclaimed_email_count > 0) paste0("其中有 ", unclaimed_email_count, " 条待领取邀请邮箱尚未注册，需要注意业务协作是否已经实际触达。"),
        if (workspace_pending_count > 0) paste0("当前有 ", workspace_pending_count, " 个我名下数据空间仍存在待领取邀请。"),
        if (owner_only_count > 0) paste0("当前有 ", owner_only_count, " 个我名下数据空间仍仅负责人可见，可按需再评估是否需要共享。")
      )
      risk_messages <- risk_messages[nzchar(risk_messages)]
      if (length(risk_messages) == 0) {
        risk_messages <- "当前未发现需要优先处理的账号或协作异常态势。"
      }

      quick_actions <- tagList(
        actionButton(session$ns("jump_account_admin"), "去账号状态管理", class = "btn-warning btn-sm"),
        actionButton(session$ns("jump_owner_admin"), "去负责人迁移", class = "btn-primary btn-sm"),
        actionButton(session$ns("jump_membership_admin"), "去空间协作", class = "btn-info btn-sm"),
        actionButton(session$ns("jump_workspace_summary"), "去空间概览", class = "btn-default btn-sm")
      )

      tagList(
        admin_stat_grid(
          admin_stat_item("停用账号", inactive_count, tone = "warning"),
          admin_stat_item("未设置邮箱账号", no_email_count, tone = "danger"),
          admin_stat_item("未开通数据空间功能", db_locked_count, tone = "warning"),
          admin_stat_item("我名下待领取邀请", pending_invite_count, tone = "info"),
          admin_stat_item("未注册邀请邮箱", unclaimed_email_count, tone = "danger"),
          admin_stat_item("仅负责人可见空间", owner_only_count, tone = "primary"),
          class = "admin-compact-grid"
        ),
        admin_panel(
          tags$strong("优先关注"),
          tags$ul(class = "admin-risk-list", lapply(risk_messages, tags$li)),
          div(class = "admin-risk-actions", quick_actions),
          class = "admin-impact-card"
        )
      )
    })

    observeEvent(input$jump_account_admin, {
      shinyjs::runjs(sprintf(
        "var anchor=document.getElementById('%s'); if(anchor){anchor.scrollIntoView({behavior:'smooth', block:'start'});} setTimeout(function(){var table=document.getElementById('%s'); if(table){table.focus();}}, 250);",
        session$ns("admin_account_section"),
        session$ns("admin_user_registry_table")
      ))
    })

    observeEvent(input$jump_owner_admin, {
      shinyjs::runjs(sprintf(
        "var anchor=document.getElementById('%s'); if(anchor){anchor.scrollIntoView({behavior:'smooth', block:'start'});} setTimeout(function(){var el=document.getElementById('%s'); if(el){el.focus();}}, 250);",
        session$ns("admin_workspace_manage_section"),
        session$ns("owner_email")
      ))
    })

    observeEvent(input$jump_membership_admin, {
      updateTabsetPanel(session, session$ns("admin_preview_tabs"), selected = "待领取邀请")
      shinyjs::runjs(sprintf(
        "var anchor=document.getElementById('%s'); if(anchor){anchor.scrollIntoView({behavior:'smooth', block:'start'});} setTimeout(function(){var el=document.getElementById('%s'); if(el){el.focus();}}, 250);",
        session$ns("admin_workspace_manage_section"),
        session$ns("membership_email")
      ))
    })

    observeEvent(input$jump_workspace_summary, {
      updateTabsetPanel(session, session$ns("admin_preview_tabs"), selected = "当前成员")
      shinyjs::runjs(sprintf(
        "var anchor=document.getElementById('%s'); if(anchor){anchor.scrollIntoView({behavior:'smooth', block:'start'});}",
        session$ns("admin_workspace_summary_section")
      ))
    })

    output$admin_user_meta_card <- renderUI({
      req(is_admin())
      row <- get_target_user_row()
      if (nrow(row) == 0) {
        return(app_card_note("请先在“所有注册账号总览”中选中一个账号。"))
      }
      all_workspaces <- service_list_workspaces(pg_pool)
      target_user_id <- row$id[[1]] %||% ""
      target_email <- row$email[[1]] %||% ""
      target_owned_count <- if (nrow(all_workspaces) == 0) 0L else sum((all_workspaces$owner_user_id %||% character(0)) == target_user_id)
      target_accessible_count <- length(auth_accessible_workspace_ids(pg_pool, target_user_id, isTRUE(row$is_admin[[1]])))
      all_invites <- service_list_workspace_invites(pg_pool)
      target_pending_invites <- if (!nzchar(target_email) || nrow(all_invites) == 0) {
        0L
      } else {
        sum((all_invites$invited_email %||% character(0)) == target_email & (all_invites$status %||% character(0)) == "pending")
      }
      admin_stat_grid(
        admin_stat_item(
          "目标账号",
          row$username[[1]] %||% "",
          tone = "primary",
          meta = ifelse(is.na(row$email[[1]]) || !nzchar(row$email[[1]]), "邮箱未设置", row$email[[1]])
        ),
        admin_stat_item("账号状态", service_label_user_status(row$status[[1]]), tone = "warning"),
        admin_stat_item(
          "角色与权限",
          ifelse(isTRUE(row$is_admin[[1]]), "管理员", "普通用户"),
          tone = "info",
          meta = paste0("数据空间：", service_label_db_access_status(isTRUE(row$db_access_enabled[[1]]) || isTRUE(row$is_admin[[1]])))
        ),
        admin_stat_item("名下数据空间", target_owned_count, tone = "success"),
        admin_stat_item("当前可访问空间", target_accessible_count, tone = "primary"),
        admin_stat_item("待领取邀请", target_pending_invites, tone = "danger"),
        admin_stat_item("创建时间", service_format_datetime(row$created_at[[1]]), tone = "info"),
        class = "admin-compact-grid"
      )
    })

    output$admin_workspace_manage_summary <- renderUI({
      req(is_admin())
      workspaces_df <- list_manageable_workspaces()
      workspace_id <- selected_manage_workspace_id()
      if (!nzchar(workspace_id) || nrow(workspaces_df) == 0) {
        return(app_card_note("当前管理员名下暂无可管理数据空间。"))
      }
      workspace_ids <- workspaces_df$id %||% character(0)
      target_idx <- match(workspace_id, workspace_ids)
      if (is.na(target_idx)) {
        return(NULL)
      }
      workspace_row <- workspaces_df[target_idx, , drop = FALSE]
      memberships_df <- service_list_workspace_memberships(pg_pool, workspace_id = workspace_id)
      invites_df <- service_list_workspace_invites(pg_pool, workspace_id = workspace_id)
      member_count <- if (nrow(memberships_df) == 0) 0L else nrow(memberships_df)
      pending_count <- if (nrow(invites_df) == 0) 0L else sum((invites_df$status %||% character(0)) == "pending")
      sharing_state <- if (pending_count > 0) {
        "有待领取邀请"
      } else if (member_count > 1L) {
        "已共享"
      } else {
        "仅负责人可见"
      }
      admin_stat_grid(
        admin_stat_item(
          "当前空间",
          workspace_row$name[[1]] %||% "",
          tone = "primary",
          meta = paste0("创建于 ", service_format_datetime(workspace_row$created_at[[1]]))
        ),
        admin_stat_item("当前成员数", member_count, tone = "info"),
        admin_stat_item(
          "待领取邀请",
          pending_count,
          tone = if (pending_count > 0) "warning" else "success"
        ),
        admin_stat_item(
          "协作状态",
          sharing_state,
          tone = if (pending_count > 0) "warning" else if (member_count > 1L) "success" else "primary"
        ),
        class = "admin-compact-grid"
      )
    })

    output$admin_action_hint <- renderUI({
      req(is_admin())
      row <- get_target_user_row()
      if (nrow(row) == 0) {
        return(NULL)
      }
      current <- get_current_user()
      hints <- c(
        if (identical(row$status[[1]] %||% "", "inactive")) "启用账号后，该用户可重新登录并恢复已有权限边界内的访问。",
        if (identical(row$status[[1]] %||% "", "active")) "停用账号后，该用户将无法继续登录系统，但现有数据空间元信息不会被自动删除。",
        if (!isTRUE(row$is_admin[[1]]) && !isTRUE(row$db_access_enabled[[1]])) "开放数据库后，该用户将获得数据空间创建与管理入口；未开放时仅可在“数据准备”页临时上传单文件。",
        if (!isTRUE(row$is_admin[[1]]) && isTRUE(row$db_access_enabled[[1]])) "锁定数据库后，该用户将失去数据空间管理入口，但仍可按当前口径继续进行临时上传分析。",
        if (!is.null(current) && identical(current$id, row$id[[1]] %||% "")) "当前目标账号就是你自己；系统会阻止停用自己或锁定自己当前登录管理员的数据库管理权限。"
      )
      hints <- hints[nzchar(hints)]
      if (length(hints) == 0) {
        return(NULL)
      }
      admin_panel(
        tags$strong("操作影响预览"),
        tags$ul(
          lapply(hints, tags$li)
        ),
        class = "admin-impact-card"
      )
    })

    output$admin_workspace_summary_table <- renderDT({
      req(is_admin())
      refresh_tick()
      overview_df <- build_workspace_overview_df(list_manageable_workspaces())
      datatable(overview_df, rownames = FALSE, options = list(pageLength = 8, scrollX = TRUE, dom = "tip"))
    })

    output$membership_table <- renderDT({
      req(is_admin())
      refresh_tick()
      workspace_id <- selected_manage_workspace_id()
      memberships <- if (!nzchar(workspace_id)) {
        service_membership_preview_df(data.frame())
      } else {
        service_membership_preview_df(service_list_workspace_memberships(pg_pool, workspace_id = workspace_id))
      }
      datatable(memberships, rownames = FALSE, options = list(pageLength = 8, scrollX = TRUE, dom = "tip"))
    })

    output$invite_table <- renderDT({
      req(is_admin())
      refresh_tick()
      workspace_id <- selected_manage_workspace_id()
      invites <- if (!nzchar(workspace_id)) {
        service_invite_preview_df(data.frame())
      } else {
        service_invite_preview_df(service_list_workspace_invites(pg_pool, workspace_id = workspace_id))
      }
      datatable(invites, rownames = FALSE, options = list(pageLength = 8, scrollX = TRUE, dom = "tip"))
    })

    observeEvent(input$assign_owner, {
      req(is_admin())
      workspace_id <- selected_manage_workspace_id()
      req(workspace_id, input$owner_email)
      tryCatch({
        result <- service_transfer_workspace_owner_by_email(
          pg_pool,
          workspace_id = workspace_id,
          invited_email = input$owner_email %||% "",
          acting_user = get_current_user()
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification(result$message, type = "message")
      }, error = function(e) {
        showNotification(paste0("绑定 Owner 失败：", e$message), type = "error")
      })
    })

    observeEvent(input$assign_membership, {
      req(is_admin())
      workspace_id <- selected_manage_workspace_id()
      req(workspace_id, input$membership_email)
      tryCatch({
        result <- service_grant_workspace_access_by_email(
          pg_pool,
          workspace_id = workspace_id,
          invited_email = input$membership_email %||% "",
          role = input$membership_role,
          acting_user = get_current_user()
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification(result$message, type = "message")
      }, error = function(e) {
        showNotification(paste0("更新 Membership 失败：", e$message), type = "error")
      })
    })

    observeEvent(input$revoke_membership, {
      req(is_admin())
      workspace_id <- selected_manage_workspace_id()
      req(workspace_id, input$membership_email)
      tryCatch({
        service_revoke_workspace_access_by_email(
          pg_pool,
          workspace_id = workspace_id,
          invited_email = input$membership_email %||% "",
          acting_user = get_current_user()
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification("权限已撤销", type = "message")
      }, error = function(e) {
        showNotification(paste0("撤销权限失败：", e$message), type = "error")
      })
    })

    observeEvent(input$activate_user, {
      req(is_admin())
      target_user <- get_target_user_row()
      if (nrow(target_user) == 0) {
        showNotification("请先在账号总览中选中目标账号", type = "warning")
        return()
      }
      tryCatch({
        service_set_user_status(pg_pool, target_user$id[[1]] %||% "", "active")
        refresh_tick(as.numeric(Sys.time()))
        showNotification("账号已启用", type = "message")
      }, error = function(e) {
        showNotification(paste0("启用失败：", e$message), type = "error")
      })
    })

    observeEvent(input$deactivate_user, {
      req(is_admin())
      target_user <- get_target_user_row()
      if (nrow(target_user) == 0) {
        showNotification("请先在账号总览中选中目标账号", type = "warning")
        return()
      }
      current <- get_current_user()
      if (nrow(target_user) > 0 && !is.null(current) && identical(current$id, target_user$id[[1]])) {
        showNotification("不能停用当前登录管理员账号", type = "warning")
        return()
      }
      tryCatch({
        service_set_user_status(pg_pool, target_user$id[[1]] %||% "", "inactive")
        refresh_tick(as.numeric(Sys.time()))
        showNotification("账号已停用", type = "message")
      }, error = function(e) {
        showNotification(paste0("停用失败：", e$message), type = "error")
      })
    })

    observeEvent(input$grant_db_access, {
      req(is_admin())
      target_user <- get_target_user_row()
      if (nrow(target_user) == 0) {
        showNotification("请先在账号总览中选中目标账号", type = "warning")
        return()
      }
      tryCatch({
        service_set_user_db_access(pg_pool, target_user$id[[1]] %||% "", enabled = TRUE)
        refresh_tick(as.numeric(Sys.time()))
        showNotification("数据库管理权限已开放", type = "message")
      }, error = function(e) {
        showNotification(paste0("开放失败：", e$message), type = "error")
      })
    })

    observeEvent(input$revoke_db_access, {
      req(is_admin())
      target_user <- get_target_user_row()
      if (nrow(target_user) == 0) {
        showNotification("请先在账号总览中选中目标账号", type = "warning")
        return()
      }
      current <- get_current_user()
      if (nrow(target_user) > 0 && !is.null(current) && identical(current$id, target_user$id[[1]]) && isTRUE(current$is_admin)) {
        showNotification("不能锁定当前登录管理员的数据库管理权限", type = "warning")
        return()
      }
      tryCatch({
        service_set_user_db_access(pg_pool, target_user$id[[1]] %||% "", enabled = FALSE)
        refresh_tick(as.numeric(Sys.time()))
        showNotification("数据库管理权限已锁定", type = "message")
      }, error = function(e) {
        showNotification(paste0("锁定失败：", e$message), type = "error")
      })
    })

    observeEvent(input$smtp_probe_send, {
      req(is_admin())
      target_email <- trimws(input$smtp_probe_email %||% "")
      email_error <- auth_validate_email(target_email)
      if (!is.null(email_error)) {
        smtp_probe_last_result(list(
          status = "error",
          email = target_email,
          message = email_error,
          at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
        ))
        showNotification(email_error, type = "warning")
        return()
      }
      result <- email_service_send_probe(target_email)
      if (isTRUE(result$success)) {
        smtp_probe_last_result(list(
          status = "success",
          email = target_email,
          message = result$message %||% "探针邮件已发送",
          at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
        ))
        showNotification(result$message, type = "message")
      } else {
        smtp_probe_last_result(list(
          status = "error",
          email = target_email,
          message = result$message %||% "探针邮件发送失败",
          at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
        ))
        showNotification(result$message, type = "error")
      }
    })
  })
}
