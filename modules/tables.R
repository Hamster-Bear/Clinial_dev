# Tables模块 - 临床数据表格展示模块
# 支持多种表格类型：人口统计表格 (t_dm)、AE SOC/PT 汇总表 (t_ae_soc_pt)
# 基于 gtsummary 和 rtables/tern，支持自动类型检测、自定义总计列和代码输出

library(shiny)
library(dplyr)
library(gt)
library(shinyjs)
source("modules/common/entry_copy.R")
source("modules/common/ui_shell.R")
source("modules/common/graphics/graphics_common.R")

# 加载子模块分析函数
source("modules/tables/t_dm.R")
source("modules/tables/t_ae_soc_pt.R")
source("modules/tables/listing_general.R")
source("modules/tables/ae_sidebyside.R") # 加载并列对比图模块
source("modules/common/data/data_filter.R") # 加载通用筛选模块
source("modules/common/export/table_export.R")
source("modules/common/export/plot_export.R")

# Tables模块UI
tables_ui <- function(id) {
  ns <- NS(id)
  copy <- ENTRY_COPY$tables

  tagList(
    useShinyjs(),
    data_filter_ui(ns("global_filter")),
    task_history_ui(
      ns("tables_task_history"),
      help_text = "保存当前表格参数、页面选择和任务备注；workspace 为空时保存为个人任务。"
    ),
    fluidRow(
      column(
        width = 4,
        app_card_box(
          width = 12,
          title = copy$method$title,
          subtitle = copy$method$subtitle,
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note(copy$method$note),
          selectizeInput(
            ns("table_type"),
            "选择表格类型",
            choices = c(
              "人口统计表格 (t_dm)" = "t_dm",
              "分级统计表 (t_ae_soc_pt)" = "t_ae_soc_pt",
              "一般列表 (listing_general)" = "listing_general",
              "不良事件并列对比图 (ae_sidebyside)" = "ae_sidebyside"
            ),
            selected = "t_dm",
            width = "100%"
          )
        ),
        app_card_box(
          width = 12,
          title = copy$params$title,
          subtitle = copy$params$subtitle,
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          app_card_note(copy$params$note),
          uiOutput(ns("dm_params_ui")),
          actionButton(ns("generate"), "生成表格", icon = icon("table"), class = "btn-success", width = "100%")
        )
      ),
      column(
        width = 8,
        app_card_box(
          width = 12,
          title = copy$result$title,
          subtitle = copy$result$subtitle,
          tone = "success",
          status = "success",
          solidHeader = FALSE,
          app_card_note(copy$result$note),
          tabsetPanel(
            tabPanel(
              "表格结果",
              app_result_panel(
                title = "表格结果",
                note = "展示当前所选表格类型生成的表格结果。",
                tone = "success",
                uiOutput(ns("table_output"))
              )
            ),
            tabPanel(
              "R代码",
              app_result_panel(
                title = "R 代码",
                note = "展示当前表格参数对应的 R 代码，便于复现或写入报告。",
                tone = "info",
                verbatimTextOutput(ns("code_output"), placeholder = TRUE)
              )
            )
          ),
          app_result_panel(
            title = "导出配置",
            note = copy$result$export_note,
            tone = "warning",
            fluidRow(
              column(4, selectInput(ns("table_export_format"), "导出格式", choices = c("Word (.docx)" = "docx", "PNG (.png)" = "png"), selected = "docx")),
              column(4, textInput(ns("table_export_name"), "文件名前缀", value = "table_result")),
              column(4, div(style = "padding-top: 25px;", downloadButton(ns("table_download"), "导出结果", class = "btn-primary")))
            )
          )
        )
      )
    )
  )
}

# Tables模块服务器逻辑
tables_server <- function(id, data, pg_pool = NULL, current_user = NULL, dataset_meta = NULL) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  
  # 反应式值：存储生成的表格
  table_result <- reactiveVal(NULL)
  # 存储生成的代码
  code_result <- reactiveVal("# 请先上传数据并选择变量，然后点击'生成表格'")
  # 提交的参数快照（Generate 时冻结，导出与下游读取）
  committed_params <- reactiveVal(NULL)
  
  # 调用筛选模块，获取筛选后的数据
  filtered_data <- data_filter_server("global_filter", data)
  
  # 动态生成参数 UI
  ae_sidebyside_params_server("ae_sidebyside_params", filtered_data)
  
  # 渲染动态参数UI（根据表格类型）
  output$dm_params_ui <- renderUI({
    req(input$table_type)

    if (is.null(filtered_data())) {
      return(div(style = "padding: 20px; text-align: center; color: #7b8794;",
        icon("database", style = "font-size: 24px; margin-bottom: 8px;"),
        br(),
        "请先上传数据并完成筛选，再设置分析参数。"
      ))
    }

    df <- filtered_data()
    switch(input$table_type,
      "t_dm"            = t_dm_params_ui(ns, df),
      "t_ae_soc_pt"     = t_ae_soc_pt_params_ui(ns, df),
      "listing_general" = listing_general_params_ui(ns, df),
      "ae_sidebyside"   = ae_sidebyside_params_ui(ns("ae_sidebyside_params"), df),
      NULL
    )
  })
  
  # 获取分组变量的水平（用于总计列设置）
  dm_group_levels <- reactive({
    req(filtered_data(), input$dm_by_var, input$dm_by_var != "无")
    unique(filtered_data()[[input$dm_by_var]])
  })
  
  # 动态生成总计列设置UI
  output$dm_total_cols_ui <- renderUI({
    req(input$dm_enable_total_cols == TRUE, input$dm_total_cols_count >= 1, dm_group_levels())
    
    total_cols <- lapply(1:input$dm_total_cols_count, function(i) {
      wellPanel(
        textInput(
          ns(paste0("dm_total_col_name_", i)),
          paste("总计列", i, "名称"),
          value = paste("总计", i)
        ),
        selectizeInput(
          ns(paste0("dm_total_col_groups_", i)),
          paste("选择总计列", i, "包含的组"),
          choices = dm_group_levels(),
          multiple = TRUE
        )
      )
    })
    do.call(tagList, total_cols)
  })
  
  # 获取总计列设置
  dm_total_cols_settings <- reactive({
    req(input$dm_enable_total_cols == TRUE, input$dm_total_cols_count >= 1, input$dm_by_var != "无")
    
    settings <- list()
    for (i in 1:input$dm_total_cols_count) {
      name_id <- paste0("dm_total_col_name_", i)
      groups_id <- paste0("dm_total_col_groups_", i)
      
      if (!is.null(input[[name_id]]) && !is.null(input[[groups_id]])) {
        settings[[i]] <- list(
          name = input[[name_id]],
          groups = input[[groups_id]]
        )
      }
    }
    settings
  })
  
  # 访问锁：控制生成按钮状态（根据表格类型）
  observe({
    req(input$table_type)
    if (is.null(filtered_data())) {
      shinyjs::disable("generate")
      return()
    }
    if (input$table_type == "t_dm") {
      if (length(input$dm_variables) == 0) {
        shinyjs::disable("generate")
      } else {
        shinyjs::enable("generate")
      }
    } else if (input$table_type == "t_ae_soc_pt") {
      if (is.null(input$ae_trt_var) || is.null(input$ae_soc_var) || is.null(input$ae_pt_var)) {
        shinyjs::disable("generate")
      } else {
        shinyjs::enable("generate")
      }
    } else if (input$table_type == "listing_general") {
       if (is.null(input$listing_disp_cols) || length(input$listing_disp_cols) == 0) {
          shinyjs::disable("generate")
       } else {
          shinyjs::enable("generate")
       }
    } else if (input$table_type == "ae_sidebyside") {
         # 这里的输入在子模块 ns("ae_sidebyside_params") 下，需要通过 input 访问
         # 但由于 UI 是动态渲染的，input 可能需要通过 session$input 访问，或者直接假设它们在顶层 input 中（如果使用 ns）
         # 修正：ae_sidebyside_params_ui 使用了 ns，所以 input ID 会带有前缀
         # 但在这里访问时，input 对象已经包含了当前模块的 namespace
         # 所以 input[["ae_sidebyside_params-ae_term_col"]]
         
         term_col <- input[["ae_sidebyside_params-ae_term_col"]]
         sev_col <- input[["ae_sidebyside_params-ae_sev_col"]]
         
         if (is.null(term_col) || is.null(sev_col)) {
            shinyjs::disable("generate")
         } else {
            shinyjs::enable("generate")
         }
      } else {
      shinyjs::disable("generate")
    }
  })
  
  # 切换表格类型时清空之前的结果
  observeEvent(input$table_type, {
    table_result(NULL)
    committed_params(NULL)
    code_result("# 请先上传数据并选择变量，然后点击'生成表格'")
  })

  observeEvent(input$table_type, {
    req(input$table_type)
    export_choices <- switch(
      input$table_type,
      "ae_sidebyside" = c("PNG (.png)" = "png", "PDF (.pdf)" = "pdf", "SVG (.svg)" = "svg"),
      c("Word (.docx)" = "docx", "PNG (.png)" = "png", "PDF (.pdf)" = "pdf", "HTML (.html)" = "html", "RTF (.rtf)" = "rtf")
    )
    selected_format <- if ("docx" %in% unname(export_choices)) "docx" else unname(export_choices)[1]
    updateSelectInput(session, "table_export_format", choices = export_choices, selected = selected_format)
  }, ignoreInit = FALSE)
  
  # 生成表格
  observeEvent(input$generate, {
    req(filtered_data(), input$table_type)
    if (input$table_type == "t_dm") {
      req(input$dm_variables)
    } else if (input$table_type == "t_ae_soc_pt") {
        req(input$ae_trt_var, input$ae_soc_var, input$ae_pt_var)
      } else if (input$table_type == "listing_general") {
        req(input$listing_disp_cols)
      } else if (input$table_type == "ae_sidebyside") {
        # ae_sidebyside 参数输入使用 ae_sidebyside_params- 前缀
        req(input[["ae_sidebyside_params-ae_term_col"]], input[["ae_sidebyside_params-ae_sev_col"]])
      }
    
      # 禁用按钮，防止重复点击
    shinyjs::disable("generate")
    # on.exit(shinyjs::enable("generate")) # 移至末尾，确保在异步或错误时也能恢复
    
    tryCatch({
      df <- filtered_data()
      
      # 调试信息
      print(paste("Generating table type:", input$table_type))
      
      # ... (t_dm 逻辑保持不变)
      
      if (input$table_type == "t_dm") {
        # ... (t_dm 调用逻辑)
         vars <- input$dm_variables
         by_var <- input$dm_by_var
         if (by_var == "无") by_var <- NULL
         
         total_settings <- NULL
         if (input$dm_enable_total_cols == TRUE && input$dm_by_var != "无") {
            total_settings <- dm_total_cols_settings()
         }
         
         result <- perform_t_dm_analysis(
            data = df,
            variables = vars,
            by_var = by_var,
            total_cols_settings = total_settings,
            table_title = input$dm_table_title,
            table_footnote = input$dm_table_footnote
         )

         params <- list(
           table_type = "t_dm",
           dm_variables = vars,
           dm_by_var = input$dm_by_var,
           dm_enable_total_cols = input$dm_enable_total_cols,
           dm_total_cols_count = input$dm_total_cols_count,
           dm_total_cols_settings = total_settings,
           dm_table_title = input$dm_table_title,
           dm_table_footnote = input$dm_table_footnote,
           table_export_name = input$table_export_name,
           table_export_format = input$table_export_format
         )

         # 生成代码
         code <- generate_t_dm_code(
            variables = vars,
            by_var = by_var,
            total_cols_settings = total_settings,
            table_title = input$dm_table_title,
            table_footnote = input$dm_table_footnote
         )
         
      } else if (input$table_type == "t_ae_soc_pt") {
        # 获取 AE/分级统计相关参数
        pop_var <- if (input$ae_enable_pop) input$ae_pop_var else NULL
        pop_val <- if (input$ae_enable_pop) input$ae_pop_val else "Y"
        
        result <- perform_t_ae_soc_pt_analysis(
          data = df,
          trt_var = input$ae_trt_var,
          soc_var = input$ae_soc_var,
          pt_var = input$ae_pt_var,
          id_var = input$subject_id_var,
          pop_var = pop_var,
          pop_val = pop_val
        )

        params <- list(
          table_type = "t_ae_soc_pt",
          ae_trt_var = input$ae_trt_var,
          ae_soc_var = input$ae_soc_var,
          ae_pt_var = input$ae_pt_var,
          subject_id_var = input$subject_id_var,
          ae_enable_pop = input$ae_enable_pop,
          ae_pop_var = pop_var,
          ae_pop_val = pop_val,
          table_export_name = input$table_export_name,
          table_export_format = input$table_export_format
        )

        # 生成代码
        code <- generate_t_ae_soc_pt_code(
          trt_var = input$ae_trt_var,
          soc_var = input$ae_soc_var,
          pt_var = input$ae_pt_var,
          id_var = input$subject_id_var,
          pop_var = pop_var,
          pop_val = pop_val
        )
      } else if (input$table_type == "listing_general") {
        # 一般列表分析
        normalized_listing <- normalize_listing_columns(
          data = df,
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols
        )
        if (length(normalized_listing$disp_cols) == 0) {
          stop("当前展示列已失效，请重新选择有效字段。")
        }
        if (length(normalized_listing$missing_cols) > 0) {
          showNotification("部分已选 Listing 字段已失效，系统已自动忽略不可用字段。", type = "warning")
        }
        result <- perform_listing_general_analysis(
          data = df,
          key_cols = normalized_listing$key_cols,
          disp_cols = normalized_listing$disp_cols
        )

        params <- list(
          table_type = "listing_general",
          listing_key_cols = input$listing_key_cols,
          listing_disp_cols = input$listing_disp_cols,
          listing_landscape = input$listing_landscape,
          listing_font_size = input$listing_font_size,
          table_export_name = input$table_export_name,
          table_export_format = input$table_export_format
        )

        code <- generate_listing_general_code(
          key_cols = normalized_listing$key_cols,
          disp_cols = normalized_listing$disp_cols,
          landscape = input$listing_landscape,
          font_size = input$listing_font_size
        )
      } else if (input$table_type == "ae_sidebyside") {
        # 不良事件并列对比图
        # 需要手动提取带命名空间的输入
        prefix <- "ae_sidebyside_params-"
        result <- perform_ae_sidebyside_analysis(
          data = df,
          term_col = input[[paste0(prefix, "ae_term_col")]],
          sev_col = input[[paste0(prefix, "ae_sev_col")]],
          subj_col = input[[paste0(prefix, "ae_subj_col")]],
          group_col = input[[paste0(prefix, "ae_group_col")]],
          flag_col = input[[paste0(prefix, "ae_flag_col")]],
          flag_val = input[[paste0(prefix, "ae_flag_val")]],
          rel_col = input[[paste0(prefix, "ae_rel_col")]],
          rel_val = input[[paste0(prefix, "ae_rel_val")]],
          count_mode = input[[paste0(prefix, "ae_count_mode")]],
          min_pct = input[[paste0(prefix, "ae_min_pct")]]
        )
        
        params <- list(
          table_type = "ae_sidebyside",
          ae_term_col = input[[paste0(prefix, "ae_term_col")]],
          ae_sev_col  = input[[paste0(prefix, "ae_sev_col")]],
          ae_subj_col = input[[paste0(prefix, "ae_subj_col")]],
          ae_group_col = input[[paste0(prefix, "ae_group_col")]],
          ae_flag_col = input[[paste0(prefix, "ae_flag_col")]],
          ae_flag_val = input[[paste0(prefix, "ae_flag_val")]],
          ae_rel_col   = input[[paste0(prefix, "ae_rel_col")]],
          ae_rel_val   = input[[paste0(prefix, "ae_rel_val")]],
          ae_count_mode = input[[paste0(prefix, "ae_count_mode")]],
          ae_min_pct   = input[[paste0(prefix, "ae_min_pct")]],
          table_export_name = input$table_export_name,
          table_export_format = input$table_export_format
        )

        code <- generate_ae_sidebyside_code(
          term_col  = input[[paste0(prefix, "ae_term_col")]],
          sev_col   = input[[paste0(prefix, "ae_sev_col")]],
          subj_col  = input[[paste0(prefix, "ae_subj_col")]],
          group_col = input[[paste0(prefix, "ae_group_col")]],
          flag_col  = input[[paste0(prefix, "ae_flag_col")]],
          flag_val  = input[[paste0(prefix, "ae_flag_val")]],
          rel_col   = input[[paste0(prefix, "ae_rel_col")]],
          rel_val   = input[[paste0(prefix, "ae_rel_val")]],
          count_mode = input[[paste0(prefix, "ae_count_mode")]],
          min_pct   = input[[paste0(prefix, "ae_min_pct")]]
        )
      } else {
        showNotification(paste("未知的表格类型:", input$table_type), type = "error")
        result <- NULL
        code <- "# 未知表格类型"
      }
      
      if (!is.null(result)) {
        table_result(result)
        code_result(code)
        committed_params(params)
        showNotification("表格生成成功", type = "default")
      } else {
        showNotification("未生成表格，请检查参数设置", type = "warning")
        code_result("# 表格生成失败")
      }
      
    }, error = function(e) {
      message(sprintf("[TablesGenerateError] %s", conditionMessage(e)))
      showNotification("表格生成失败，请检查当前变量选择或数据状态后重试。", type = "error")
      table_result(NULL)
      code_result("# 表格生成失败，请检查变量选择与数据状态。")
    }, finally = {
      shinyjs::enable("generate")
    })
  })
  
  # 渲染表格（根据表格类型动态选择渲染器）
  output$table_output <- renderUI({
    req(table_result(), input$table_type)
    if (input$table_type == "t_dm") {
      gt::gt_output(ns("table_gt"))
    } else if (input$table_type == "t_ae_soc_pt") {
      verbatimTextOutput(ns("table_text"), placeholder = TRUE)
    } else if (input$table_type == "listing_general") {
      verbatimTextOutput(ns("listing_text"), placeholder = TRUE)
    } else if (input$table_type == "ae_sidebyside") {
      plotOutput(ns("ae_plot"), height = "800px")
    } else {
      NULL
    }
  })
  
  # GT 表格渲染
  output$table_gt <- gt::render_gt({
    req(table_result(), input$table_type == "t_dm")
    if (!inherits(table_result(), "gt_tbl")) {
      # 如果不是 gt 对象，返回空 gt 表格
      return(gt::gt(data.frame(Note = "表格类型不匹配")))
    }
    table_result()
  })
  
  # 文本表格渲染（用于 rtables）
  # showtext_auto() 启用后拦截所有字体解析，rtables/formatters 内部的 Courier
  # 字体查找会失败并回退到非等宽字体，触发 "non-monospace font" 错误。
  # 使用 graphics_with_showtext_paused() 临时关闭 showtext 避免此冲突。
  output$table_text <- renderText({
    req(table_result(), input$table_type == "t_ae_soc_pt")
    graphics_with_showtext_paused(toString(table_result(), ttype_ok = TRUE))
  })
  
  # Listing 渲染
  output$listing_text <- renderText({
    req(table_result(), input$table_type == "listing_general")
    toString(table_result())
  })
  
  # AE Side-by-Side Plot 渲染
  output$ae_plot <- renderPlot({
    req(table_result(), input$table_type == "ae_sidebyside")
    table_result()
  })
  
  # RTF 下载处理
  output$listing_download_rtf <- downloadHandler(
    filename = function() paste0("Listing_", Sys.Date(), ".rtf"),
    content = function(file) {
      req(filtered_data(), input$listing_disp_cols)
      
      tryCatch({
        normalized_listing <- normalize_listing_columns(
          data = filtered_data(),
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols
        )
        if (length(normalized_listing$disp_cols) == 0) {
          stop("当前导出列与数据不匹配，请重新选择变量后重试。")
        }
        if (length(normalized_listing$missing_cols) > 0) {
          showNotification("部分已选导出字段已失效，系统将仅导出当前仍有效的字段。", type = "warning")
        }
        export_listing_general_rtf(
          data = filtered_data(),
          key_cols = normalized_listing$key_cols,
          disp_cols = normalized_listing$disp_cols,
          file = file,
          landscape = input$listing_landscape,
          font_size = input$listing_font_size
        )
      }, error = function(e) {
        message(sprintf("[ListingExportError] %s", conditionMessage(e)))
        showNotification("RTF 导出失败，请检查当前导出字段与数据是否一致。", type = "error")
      })
    }
  )

  output$table_download <- downloadHandler(
    filename = function() {
      req(table_result())
      cp <- committed_params()
      prefix <- if (!is.null(cp$table_export_name) && nzchar(cp$table_export_name))
        cp$table_export_name
      else if (nzchar(input$table_export_name))
        input$table_export_name
      else
        "table_result"
      fmt <- cp$table_export_format %||% input$table_export_format
      ttype <- cp$table_type %||% input$table_type
      if (identical(ttype, "ae_sidebyside")) {
        build_plot_export_filename(prefix = prefix, format = fmt)
      } else {
        build_table_export_filename(prefix = prefix, format = fmt)
      }
    },
    content = function(file) {
      req(table_result())
      cp <- committed_params()
      obj <- table_result()
      fmt <- cp$table_export_format %||% input$table_export_format
      ttype <- cp$table_type %||% input$table_type
      if (identical(ttype, "ae_sidebyside")) {
        save_plot_export(
          file = file,
          plot_obj = obj,
          format = fmt,
          width = 12,
          height = 8,
          dpi = 300
        )
      } else {
        export_title <- switch(
          ttype,
          "t_dm" = "人口统计表格 (t_dm)",
          "t_ae_soc_pt" = "分级统计表 (t_ae_soc_pt)",
          "listing_general" = "一般列表 (listing_general)",
          "ae_sidebyside" = "不良事件并列对比图 (ae_sidebyside)",
          "导出结果"
        )
        if (identical(fmt, "png")) {
          save_table_png(file = file, table_obj = obj, width = 12, height = 8, dpi = 300)
        } else {
          save_table_export(
            file = file,
            result_obj = list(table = obj),
            format = fmt,
            title = export_title,
            include_report = FALSE
          )
        }
      }
    }
  )
  
  # 渲染代码输出
  output$code_output <- renderText({
    code_result()
  })
  
  # ---- task_history 集成 ----
  resolve_user_id <- if (is.function(current_user)) {
    function() { u <- current_user(); if (is.list(u)) list(id = u$id) else NULL }
  } else {
    function() NULL
  }

  resolve_workspace_id <- if (is.function(current_user) && exists("service_registry_load")) {
    function() {
      u <- current_user()
      if (!is.list(u) || !nzchar(u$id %||% "")) return(NULL)
      tryCatch({
        reg <- service_registry_load(pg_pool, u)
        if (length(reg$workspace_ids) > 0) reg$workspace_ids[[1]] else NULL
      }, error = function(e) NULL)
    }
  } else {
    function() NULL
  }

  # 收集当前表格类型的所有可见输入参数
  collect_tables_input_state <- function() {
    ttype <- input$table_type %||% ""
    params <- list(table_type = ttype)

    if (ttype == "t_dm") {
      params$dm_variables         <- input$dm_variables %||% character(0)
      params$dm_by_var            <- input$dm_by_var
      params$dm_enable_total_cols <- input$dm_enable_total_cols
      params$dm_total_cols_count  <- input$dm_total_cols_count
      params$dm_table_title       <- input$dm_table_title
      params$dm_table_footnote    <- input$dm_table_footnote
    } else if (ttype == "t_ae_soc_pt") {
      params$ae_trt_var       <- input$ae_trt_var
      params$ae_soc_var       <- input$ae_soc_var
      params$ae_pt_var        <- input$ae_pt_var
      params$subject_id_var   <- input$subject_id_var
      params$ae_enable_pop    <- input$ae_enable_pop
      params$ae_pop_var       <- input$ae_pop_var
      params$ae_pop_val       <- input$ae_pop_val
    } else if (ttype == "listing_general") {
      params$listing_key_cols    <- input$listing_key_cols %||% character(0)
      params$listing_disp_cols   <- input$listing_disp_cols %||% character(0)
      params$listing_landscape   <- input$listing_landscape
      params$listing_font_size   <- input$listing_font_size
    } else if (ttype == "ae_sidebyside") {
      prefix <- "ae_sidebyside_params-"
      params$ae_term_col   <- input[[paste0(prefix, "ae_term_col")]]
      params$ae_sev_col    <- input[[paste0(prefix, "ae_sev_col")]]
      params$ae_subj_col   <- input[[paste0(prefix, "ae_subj_col")]]
      params$ae_group_col  <- input[[paste0(prefix, "ae_group_col")]]
      params$ae_flag_col   <- input[[paste0(prefix, "ae_flag_col")]]
      params$ae_flag_val   <- input[[paste0(prefix, "ae_flag_val")]]
      params$ae_rel_col    <- input[[paste0(prefix, "ae_rel_col")]]
      params$ae_rel_val    <- input[[paste0(prefix, "ae_rel_val")]]
      params$ae_count_mode <- input[[paste0(prefix, "ae_count_mode")]]
      params$ae_min_pct    <- input[[paste0(prefix, "ae_min_pct")]]
    }

    # 导出参数
    params$table_export_name   <- input$table_export_name
    params$table_export_format <- input$table_export_format

    params
  }

  # 两阶段恢复
  pending_tables_restore <- reactiveVal(NULL)

  task_history_server(
    "tables_task_history",
    pg_pool = pg_pool,
    current_user = resolve_user_id,
    workspace_id = resolve_workspace_id,
    scope = "tables",
    module_type = reactive(input$table_type %||% ""),
    get_state = function() {
      list(task_schema_version = 1, extra_state = collect_tables_input_state())
    },
    apply_state = function(payload) {
      if (!is.list(payload)) return(invisible(FALSE))
      extra <- payload$extra_state
      if (is.null(extra) || is.null(extra$table_type)) return(invisible(FALSE))
      updateSelectizeInput(session, "table_type", selected = extra$table_type)
      # 导出参数立即恢复
      if (!is.null(extra$table_export_name))
        updateTextInput(session, "table_export_name", value = extra$table_export_name)
      if (!is.null(extra$table_export_format))
        updateSelectInput(session, "table_export_format", selected = extra$table_export_format)
      # 子模块参数等 UI 渲染后恢复
      pending_tables_restore(extra)
      TRUE
    },
    apply_failure_message = "Tables 模块暂未接入完整任务历史回填",
    source_info = dataset_meta
  )

  observe({
    extra <- pending_tables_restore()
    if (is.null(extra)) return()
    session$onFlushed(function() {
      shiny::isolate({
        pending_tables_restore(NULL)
        ttype <- extra$table_type
        switch(ttype,
          "t_dm"            = apply_t_dm_state(session, list(extra_state = extra)),
          "t_ae_soc_pt"     = apply_t_ae_soc_pt_state(session, list(extra_state = extra)),
          "listing_general" = apply_listing_general_state(session, list(extra_state = extra)),
          "ae_sidebyside"   = apply_ae_sidebyside_state(session, list(extra_state = extra))
        )
      })
    })
  })

  # 返回表格结果 + task_history 契约
  return(list(
    table_result = table_result,
    state = reactive({
      list(
        task_schema_version = 1,
        extra_state = collect_tables_input_state()
      )
    }),
    apply_state = function(payload) {
      if (!is.list(payload)) return(invisible(FALSE))
      extra <- payload$extra_state
      if (is.null(extra) || is.null(extra$table_type)) return(invisible(FALSE))
      updateSelectizeInput(session, "table_type", selected = extra$table_type)
      session$onFlushed(function() {
        ttype <- extra$table_type
        switch(ttype,
          "t_dm"            = apply_t_dm_state(session, list(extra_state = extra)),
          "t_ae_soc_pt"     = apply_t_ae_soc_pt_state(session, list(extra_state = extra)),
          "listing_general" = apply_listing_general_state(session, list(extra_state = extra)),
          "ae_sidebyside"   = apply_ae_sidebyside_state(session, list(extra_state = extra))
        )
      })
    }
  ))
  })
}
