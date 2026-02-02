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

# Tables模块UI
tables_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    useShinyjs(),
    fluidRow(
      # 左侧：参数设置
      column(
        width = 4,
        box(
          width = 12,
          title = "表格参数设置",
          status = "primary",
          solidHeader = TRUE,
          # 表格类型选择
          selectizeInput(
            ns("table_type"),
            "选择表格类型",
            choices = c(
              "人口统计表格 (t_dm)" = "t_dm",
              "AE SOC/PT 汇总表 (t_ae_soc_pt)" = "t_ae_soc_pt"
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
        width = 8,
        box(
          width = 12,
          title = "描述性统计表格",
          status = "success",
          solidHeader = TRUE,
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
tables_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 反应式值：存储生成的表格
  table_result <- reactiveVal(NULL)
  # 存储生成的代码
  code_result <- reactiveVal("# 请先上传数据并选择变量，然后点击'生成表格'")
  
  # 渲染动态参数UI（根据表格类型）
  output$dm_params_ui <- renderUI({
    req(data(), input$table_type)
    df <- data()
    if (input$table_type == "t_dm") {
      t_dm_params_ui(ns, df)
    } else if (input$table_type == "t_ae_soc_pt") {
      t_ae_soc_pt_params_ui(ns, df)
    } else {
      NULL
    }
  })
  
  # 获取分组变量的水平（用于总计列设置）
  dm_group_levels <- reactive({
    req(data(), input$dm_by_var, input$dm_by_var != "无")
    unique(data()[[input$dm_by_var]])
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
    if (is.null(data())) {
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
    req(data(), input$table_type)
    if (input$table_type == "t_dm") {
      req(input$dm_variables)
    } else if (input$table_type == "t_ae_soc_pt") {
      req(input$ae_trt_var, input$ae_soc_var, input$ae_pt_var)
    }
    
    # 禁用按钮，防止重复点击
    shinyjs::disable("generate")
    on.exit(shinyjs::enable("generate"))
    
    tryCatch({
      df <- data()
      vars <- input$dm_variables
      by_var <- input$dm_by_var
      if (by_var == "无") {
        by_var <- NULL
      }
      
      total_settings <- NULL
      if (input$dm_enable_total_cols == TRUE && input$dm_by_var != "无") {
        total_settings <- dm_total_cols_settings()
      }
      
      # 调用子模块分析函数（根据表格类型）
      result <- NULL
      if (input$table_type == "t_dm") {
        result <- perform_t_dm_analysis(
          data = df,
          variables = vars,
          by_var = by_var,
          total_cols_settings = total_settings,
          table_title = input$dm_table_title,
          table_footnote = input$dm_table_footnote
        )
      } else if (input$table_type == "t_ae_soc_pt") {
        # 获取 AE 相关参数
        saffl_var <- if (input$ae_enable_saffl) input$ae_saffl_var else NULL
        saffl_val <- if (input$ae_enable_saffl) input$ae_saffl_val else "Y"
        result <- perform_t_ae_soc_pt_analysis(
          data = df,
          trt_var = input$ae_trt_var,
          soc_var = input$ae_soc_var,
          pt_var = input$ae_pt_var,
          saffl_var = saffl_var,
          saffl_val = saffl_val
        )
      } else {
        showNotification(paste("未知的表格类型:", input$table_type), type = "error")
      }
      
      if (!is.null(result)) {
        table_result(result)
        showNotification("表格生成成功", type = "default")
        
        # 生成代码（根据表格类型）
        if (input$table_type == "t_dm") {
          code <- generate_t_dm_code(
            variables = vars,
            by_var = by_var,
            total_cols_settings = total_settings,
            table_title = input$dm_table_title,
            table_footnote = input$dm_table_footnote
          )
        } else if (input$table_type == "t_ae_soc_pt") {
          code <- generate_t_ae_soc_pt_code(
            trt_var = input$ae_trt_var,
            soc_var = input$ae_soc_var,
            pt_var = input$ae_pt_var,
            saffl_var = if (input$ae_enable_saffl) input$ae_saffl_var else NULL,
            saffl_val = if (input$ae_enable_saffl) input$ae_saffl_val else "Y"
          )
        } else {
          code <- "# 未知表格类型"
        }
        code_result(code)
      } else {
        showNotification("未生成表格，请检查参数设置", type = "warning")
        code_result("# 表格生成失败")
      }
      
    }, error = function(e) {
      showNotification(paste("生成表格时出错:", e$message), type = "error")
      table_result(NULL)
      code_result(paste("# 错误:", e$message))
    })
  })
  
  # 渲染表格（根据表格类型动态选择渲染器）
  output$table_output <- renderUI({
    req(table_result(), input$table_type)
    if (input$table_type == "t_dm") {
      gt::gt_output(ns("table_gt"))
    } else if (input$table_type == "t_ae_soc_pt") {
      verbatimTextOutput(ns("table_text"), placeholder = TRUE)
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
  
  # 渲染代码输出
  output$code_output <- renderText({
    code_result()
  })
  
  # 返回表格结果
  return(table_result)
}
