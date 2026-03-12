# Tables模块 - 临床数据表格展示模块
# 支持多种表格类型：人口统计表格 (t_dm)、AE SOC/PT 汇总表 (t_ae_soc_pt)
# 基于 gtsummary 和 rtables/tern，支持自动类型检测、自定义总计列和代码输出

library(shiny)
library(dplyr)
library(gt)
library(shinyjs)

# 加载子模块分析函数
source("modules/tables/t_dm.R")
source("modules/tables/t_ae_soc_pt.R")
source("modules/tables/listing_general.R")
source("modules/tables/ae_sidebyside.R") # 加载并列对比图模块
source("modules/common/data_filter.R") # 加载通用筛选模块

# Tables模块UI
tables_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    useShinyjs(),
    fluidRow(
      # 顶部：数据筛选（新增）
      column(
        width = 12,
        box(
          width = NULL,
          title = "全局数据筛选",
          status = "info",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = TRUE, # 默认折叠
          # 调用筛选模块 UI
          data_filter_ui(ns("global_filter"))
        )
      )
    ),
    fluidRow(
      # 左侧：参数设置
      column(
        width = 3,
        box(
          width = NULL,
          title = "预设图表参数设置",
          status = "primary",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = FALSE,
          # 表格类型选择
          selectizeInput(
            ns("table_type"),
            "选择图表类型",
            choices = c(
              "人口统计表格 (t_dm)" = "t_dm",
              "分级统计表 (t_ae_soc_pt)" = "t_ae_soc_pt",
              "一般列表 (listing_general)" = "listing_general",
              "不良事件并列对比图 (ae_sidebyside)" = "ae_sidebyside"
            ),
            selected = "t_dm"
          ),
          # 动态参数UI（由服务器端根据数据渲染）
          uiOutput(ns("dm_params_ui")),
          # 生成按钮
          actionButton(
            ns("generate"),
            "生成表格",
            icon = icon("table"),
            class = "btn-success",
            width = "100%"
          )
        )
      ),
      # 右侧：结果展示
      column(
        width = 9,
        box(
          width = NULL,
          title = "统计表格结果",
          status = "success",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = FALSE,
          tabsetPanel(
            tabPanel("表格结果", uiOutput(ns("table_output"))),
            tabPanel("R代码", verbatimTextOutput(ns("code_output"), placeholder = TRUE))
          )
        )
      )
    )
  )
}

# Tables模块服务器逻辑
tables_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  
  # 反应式值：存储生成的表格
  table_result <- reactiveVal(NULL)
  # 存储生成的代码
  code_result <- reactiveVal("# 请先上传数据并选择变量，然后点击'生成表格'")
  
  # 调用筛选模块，获取筛选后的数据
  filtered_data <- data_filter_server("global_filter", data)
  
  # 动态生成参数 UI
  ae_sidebyside_params_server("ae_sidebyside_params", filtered_data)
  
  # 渲染动态参数UI（根据表格类型）
  output$dm_params_ui <- renderUI({
    req(filtered_data(), input$table_type)
    df <- filtered_data()
    if (input$table_type == "t_dm") {
      t_dm_params_ui(ns, df)
    } else if (input$table_type == "t_ae_soc_pt") {
      t_ae_soc_pt_params_ui(ns, df)
    } else if (input$table_type == "listing_general") {
      listing_general_params_ui(ns, df)
    } else if (input$table_type == "ae_sidebyside") {
      ae_sidebyside_params_ui(ns("ae_sidebyside_params"), df)
    } else {
      NULL
    }
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
    code_result("# 请先上传数据并选择变量，然后点击'生成表格'")
  })
  
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
        # 注意：ae_sidebyside_params_ui 生成的输入带有 ae_sidebyside_params- 前缀
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
        result <- perform_listing_general_analysis(
          data = df,
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols
        )
        
        code <- generate_listing_general_code(
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols,
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
        
        code <- generate_ae_sidebyside_code()
      } else {
        showNotification(paste("未知的表格类型:", input$table_type), type = "error")
        result <- NULL
        code <- "# 未知表格类型"
      }
      
      if (!is.null(result)) {
        table_result(result)
        code_result(code)
        showNotification("表格生成成功", type = "default")
      } else {
        showNotification("未生成表格，请检查参数设置", type = "warning")
        code_result("# 表格生成失败")
      }
      
    }, error = function(e) {
      showNotification(paste("生成表格时出错:", e$message), type = "error")
      table_result(NULL)
      code_result(paste("# 错误:", e$message))
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
  output$table_text <- renderPrint({
    req(table_result(), input$table_type == "t_ae_soc_pt")
    print(table_result())
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
        export_listing_general_rtf(
          data = filtered_data(),
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols,
          file = file,
          landscape = input$listing_landscape,
          font_size = input$listing_font_size
        )
      }, error = function(e) {
        showNotification(paste("导出错误:", e$message), type = "error")
      })
    }
  )
  
  # 渲染代码输出
  output$code_output <- renderText({
    code_result()
  })
  
  # 返回表格结果
  return(table_result)
  })
}
