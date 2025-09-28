# 数据准备模块
# 负责文件上传、数据清洗、变量类型识别和数据匿名化

data_preparation_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # 文件上传区域
    fluidRow(
      box(
        width = 12, 
        title = "文件上传", 
        status = "primary", 
        solidHeader = TRUE,
        fileInput(
          ns("file_upload"), 
          label = NULL, 
          buttonLabel = "浏览...", 
          placeholder = "选择 .csv, .xlsx 或 .sav 文件",
          accept = c(".csv", ".xlsx", ".xls", ".sav")
        ),
        helpText("支持 CSV, Excel, SPSS 格式。文件大小限制为 50MB。")
      )
    ),

    # 性能优化选项
    conditionalPanel(
      condition = paste0("input['", ns("file_upload"), "'] != null"),
      fluidRow(
        box(
          width = 12,
          title = "性能优化选项 (用于大型数据集)",
          status = "info",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = TRUE,
          fluidRow(
            column(6,
                   numericInput(ns("sample_size"), "采样观测数",
                               value = 10000, min = 1000, max = 1000000, step = 1000),
                   helpText("对于大型数据集，建议使用采样来提高响应速度")
            ),
            column(6,
                   checkboxInput(ns("enable_sampling"), "启用数据采样", value = FALSE),
                   checkboxInput(ns("lazy_loading"), "启用延迟加载", value = TRUE)
            )
          ),
          fluidRow(
            column(12,
                   actionButton(ns("apply_sampling"), "应用采样设置",
                               icon = icon("bolt"), class = "btn-info btn-sm")
            )
          )
        )
      )
    ),
    
    # 信息框区域
    fluidRow(
      valueBoxOutput(ns("var_count_box"), width = 2),
      valueBoxOutput(ns("obs_count_box"), width = 2),
      valueBoxOutput(ns("file_info_box"), width = 2),
      valueBoxOutput(ns("performance_info_box"), width = 2),
      valueBoxOutput(ns("memory_info_box"), width = 2)
    ),
    
    # 数据预览区域
    fluidRow(
      box(
        width = 12,
        title = "数据预览",
        status = "info",
        DT::dataTableOutput(ns("raw_data_preview"))
      )
    ),
    
    # 数据匿名化选项
    fluidRow(
      box(
        width = 12,
        title = "数据匿名化",
        status = "warning",
        solidHeader = TRUE,
        uiOutput(ns("anon_ui")),
        helpText("选择需要匿名化的标识符列（如患者ID、姓名等），并选择处理策略。",
                style = "color: #666; font-style: italic; margin-top: 10px;")
      )
    ),
    
    # 缺失值处理选项
    fluidRow(
      box(
        width = 12,
        title = "缺失值处理",
        status = "warning",
        solidHeader = TRUE,
        uiOutput(ns("na_action_ui")),
        conditionalPanel(
          condition = paste0("input['", ns("na_action"), "'] == 'impute'"),
          helpText("数值型列使用中位数填补，分类列使用众数填补。",
                  style = "color: #666; font-style: italic;")
        ),
        conditionalPanel(
          condition = paste0("input['", ns("na_action"), "'] == 'rm_row'"),
          helpText("将删除任何包含缺失值的行。",
                  style = "color: #666; font-style: italic;")
        )
      )
    ),
    
    
    # 数据预处理区域
    fluidRow(
      box(
        width = 12,
        title = "数据预处理",
        status = "warning",
        uiOutput(ns("variable_type_ui")),
        
        actionButton(
          ns("apply_preprocess"),
          label = "应用所有预处理设置",
          icon = icon("gears"),
          class = "btn btn-success btn-lg"
        )
      )
    )
  )
}

data_preparation_server <- function(input, output, session) {
  ns <- session$ns
  
  # 反应式数据存储
  raw_data <- reactiveVal(NULL)
  clean_data <- reactiveVal(NULL)
  type_info <- reactiveVal(NULL)
  sampled_data <- reactiveVal(NULL)
  performance_stats <- reactiveValues(
    load_time = NULL,
    memory_usage = NULL,
    row_count = NULL,
    col_count = NULL
  )
  
  # 文件上传处理 - 移除文件大小限制
  observeEvent(input$file_upload, {
    req(input$file_upload)
    
    file <- input$file_upload
    ext <- tools::file_ext(file$name)
    
    # 文件验证 - 只检查格式，不检查大小
    if (!ext %in% c("csv", "xlsx", "xls", "sav")) {
      showNotification("仅支持 CSV, Excel, SPSS 格式", type = "error")
      reset("file_upload")
      return()
    }
    
    # 开始性能监控
    start_time <- Sys.time()
    
    tryCatch({
      data <- switch(ext,
                    csv = {
                      # Read CSV with comprehensive error handling
                      df <- read_csv(file$datapath, show_col_types = FALSE,
                                   na = c("", "NA", "N/A", "NULL", "Null", "null", ".", " ", "NA", "na"),
                                   trim_ws = TRUE, guess_max = 1000,
                                   locale = locale(encoding = "UTF-8"))
                      # Check for parsing issues
                      parsing_problems <- problems(df)
                      if (nrow(parsing_problems) > 0) {
                        problem_msgs <- sapply(1:min(5, nrow(parsing_problems)), function(i) {
                          paste("CSV解析问题: 第", parsing_problems$row[i],
                                "行, 列", parsing_problems$col[i],
                                "- 期望", parsing_problems$expected[i],
                                "但得到", parsing_problems$actual[i])
                        })
                        
                        for (msg in problem_msgs) {
                          showNotification(msg, type = "warning", duration = 15)
                        }
                        
                        if (nrow(parsing_problems) > 5) {
                          showNotification(paste("还有", nrow(parsing_problems) - 5, "个解析问题，请检查数据文件"),
                                         type = "warning", duration = 15)
                        }
                      }
                      
                      # Convert potential numeric columns
                      df <- df %>% mutate(across(where(is.character),
                                               ~ ifelse(grepl("^[0-9.]+$", .), as.numeric(.), .)))
                      df
                    },
                    xlsx = {
                      df <- read_excel(file$datapath, na = c("", "NA", "N/A", "NULL", "Null", "null"))
                      df <- df %>% mutate(across(where(is.character),
                                               ~ ifelse(grepl("^[0-9.]+$", .), as.numeric(.), .)))
                      df
                    },
                    xls = {
                      df <- read_excel(file$datapath, na = c("", "NA", "N/A", "NULL", "Null", "null"))
                      df <- df %>% mutate(across(where(is.character),
                                               ~ ifelse(grepl("^[0-9.]+$", .), as.numeric(.), .)))
                      df
                    },
                    sav = read_sav(file$datapath))
      
      # 验证数据是否成功读取
      if (is.null(data) || nrow(data) == 0) {
        stop("文件读取成功但数据为空，请检查文件内容")
      }
      
      # 性能统计
     end_time <- Sys.time()
     load_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)
     memory_usage <- round(object.size(data) / 1024 / 1024, 2)  # MB
      
     performance_stats$load_time <- load_time
     performance_stats$memory_usage <- memory_usage
     performance_stats$row_count <- nrow(data)
     performance_stats$col_count <- ncol(data)
      
     raw_data(data)
      
     # 应用初始采样（如果启用）
     if (!is.null(input$enable_sampling) && input$enable_sampling && nrow(data) > input$sample_size) {
       sampled <- data %>% sample_n(min(input$sample_size, nrow(data)))
       sampled_data(sampled)
       clean_data(sampled)
       showNotification(paste("文件读取成功。已应用采样:", nrow(sampled), "行数据"), type = "message")
     } else {
       sampled_data(NULL)
       clean_data(data)
       showNotification("文件读取成功", type = "message")
     }
      
     # 显示性能信息
     showNotification(
       paste("加载时间:", load_time, "秒 | 内存占用:", memory_usage, "MB | 行数:", nrow(data), "| 列数:", ncol(data)),
       type = "message",
       duration = 10
     )
      
   }, error = function(e) {
     # 记录详细的错误信息到控制台
     message(paste("文件读取错误详情:", e$message))
     message(paste("调用栈:", paste(deparse(e$call), collapse = "\n")))
     
     showNotification(paste("文件读取错误:", e$message), type = "error")
   })
  })
  
  # 应用采样设置
  observeEvent(input$apply_sampling, {
    req(raw_data())
    
    if (input$enable_sampling && nrow(raw_data()) > input$sample_size) {
      sampled <- raw_data() %>% sample_n(min(input$sample_size, nrow(raw_data())))
      sampled_data(sampled)
      clean_data(sampled)
      showNotification(paste("已应用采样:", nrow(sampled), "行数据"), type = "message")
    } else {
      sampled_data(NULL)
      clean_data(raw_data())
      showNotification("已使用完整数据集", type = "message")
    }
  })
  
  # 性能信息框
  output$performance_info_box <- renderValueBox({
    req(performance_stats$load_time)
    
    valueBox(
      paste0(performance_stats$load_time, "s"),
      "加载时间",
      icon = icon("clock"),
      color = "orange"
    )
  })
  
  output$memory_info_box <- renderValueBox({
    req(performance_stats$memory_usage)
    
    valueBox(
      paste0(performance_stats$memory_usage, "MB"),
      "内存占用",
      icon = icon("memory"),
      color = "purple"
    )
  })
  
  # 数据预览 - 添加筛选功能和延迟加载
  output$raw_data_preview <- DT::renderDataTable({
    req(raw_data())
    
    # 使用延迟加载：只在需要时获取数据
    data_to_show <- if (!is.null(clean_data())) clean_data() else raw_data()
    
    # 对于大型数据集，使用服务器端处理提高性能
    if (nrow(data_to_show) > 10000 && input$lazy_loading) {
      # 服务器端处理配置
      dt_options <- list(
        scrollX = TRUE,
        scrollY = "400px",
        pageLength = 20,
        dom = 'Blfrtip',
        autoWidth = TRUE,
        buttons = c('copy', 'csv', 'excel', 'pdf'),
        lengthMenu = list(c(10, 20, 50, 100, -1), c('10', '20', '50', '100', 'All')),
        serverSide = TRUE,
        processing = TRUE,
        deferRender = TRUE
      )
    } else {
      # 客户端处理（小型数据集）
      dt_options <- list(
        scrollX = TRUE,
        scrollY = "400px",
        pageLength = 20,
        dom = 'Blfrtip',
        autoWidth = TRUE,
        buttons = c('copy', 'csv', 'excel', 'pdf'),
        lengthMenu = list(c(10, 20, 50, 100, -1), c('10', '20', '50', '100', 'All'))
      )
    }
    
    obs_count <- nrow(data_to_show)
    var_count <- ncol(data_to_show)
    
    # 添加采样状态信息
    sampling_info <- if (!is.null(sampled_data()) && nrow(sampled_data()) < nrow(raw_data())) {
      paste0("<br><small style='color: #ff7700;'>采样数据: ", format(nrow(sampled_data()), big.mark = ","),
             " 行 (完整数据: ", format(nrow(raw_data()), big.mark = ","), " 行)</small>")
    } else {
      ""
    }
    
    DT::datatable(
      data_to_show,
      options = dt_options,
      extensions = 'Buttons',
      rownames = FALSE,
      class = 'cell-border stripe hover',
      filter = 'top',
      caption = tags$caption(
        style = 'caption-side: top; text-align: left;',
        if (!is.null(clean_data())) {
          HTML(paste0(
            "<div style='background-color: #d4edda; color: #155724; padding: 10px; border-radius: 5px; margin-bottom: 10px;'>",
            "<strong>当前显示: 预处理后的数据</strong><br>",
            "观测数: ", format(obs_count, big.mark = ","), " | ",
            "变量数: ", var_count, sampling_info, "<br>",
            "<small style='color: #666;'>使用表格上方的筛选功能进行数据筛选，点击'应用所有预处理设置'生效</small>",
            "</div>"
          ))
        } else {
          HTML(paste0(
            "<div style='background-color: #d1ecf1; color: #0c5460; padding: 10px; border-radius: 5px; margin-bottom: 10px;'>",
            "<strong>当前显示: 原始数据</strong><br>",
            "观测数: ", format(obs_count, big.mark = ","), " | ",
            "变量数: ", var_count, sampling_info, "<br>",
            "<small style='color: #666;'>使用表格上方的筛选功能进行数据筛选，点击'应用所有预处理设置'生效</small>",
            "</div>"
          ))
        }
      )
    ) %>%
      DT::formatStyle(columns = names(data_to_show), fontSize = '12px')
  })
  
  # 信息框
  output$var_count_box <- renderValueBox({
    req(raw_data())
    valueBox(
      ncol(raw_data()), "变量数", 
      icon = icon("list"),
      color = "blue"
    )
  })
  
  output$obs_count_box <- renderValueBox({
    data_to_count <- if (!is.null(clean_data())) clean_data() else raw_data()
    req(data_to_count)
    
    valueBox(
      format(nrow(data_to_count), big.mark = ","), "观测数",
      icon = icon("database"),
      color = "green",
      subtitle = if (!is.null(clean_data())) "预处理后" else "原始数据"
    )
  })
  
  output$file_info_box <- renderValueBox({
    req(input$file_upload)
    valueBox(
      tools::file_ext(input$file_upload$name), "文件格式", 
      icon = icon("file"),
      color = "purple"
    )
  })
  
  # 智能变量类型识别
  observe({
    req(raw_data())
    
    types <- sapply(raw_data(), function(col) {
      if (is.numeric(col)) {
        "numeric"
      } else if (is.character(col) || is.factor(col)) {
        "categorical"
      } else if (inherits(col, "Date")) {
        "date"
      } else {
        "character"
      }
    })
    
    type_info(data.frame(
      variable = names(types),
      inferred_type = types,
      final_type = types,
      stringsAsFactors = FALSE
    ))
  })
  
  # 变量类型UI
  output$variable_type_ui <- renderUI({
    req(type_info())
    
    lapply(1:nrow(type_info()), function(i) {
      var_info <- type_info()[i, ]
      fluidRow(
        column(4, 
               tags$strong(var_info$variable),
               tags$br(),
               tags$small(paste("类型:", var_info$inferred_type))
        ),
        column(4,
               selectInput(
                 inputId = ns(paste0("type_", var_info$variable)),
                 label = NULL,
                 choices = c("数值型" = "numeric", 
                            "字符型(分类)" = "categorical", 
                            "日期型" = "date"),
                 selected = var_info$inferred_type
               )
        )
      )
    })
  })
  
  # 匿名化UI
  output$anon_ui <- renderUI({
    if (is.null(raw_data())) {
      return(
        div(style = "padding: 20px; text-align: center; color: #666;",
            icon("exclamation-triangle"),
            "请先上传数据以显示匿名化选项"
        )
      )
    }
    
    tagList(
      div(style = "margin-bottom: 15px;",
          selectizeInput(
            ns("anon_vars"),
            label = tags$span("选择需匿名化的标识符列",
                             style = "font-weight: bold; color: #0056b3;"),
            choices = names(raw_data()),
            multiple = TRUE,
            options = list(
              placeholder = "选择需要匿名化的列",
              'plugins' = list('remove_button')
            )
          )
      ),
      div(style = "background: #f8f9fa; padding: 15px; border-radius: 5px; border: 1px solid #dee2e6;",
          radioButtons(
            ns("anon_strategy"),
            tags$span("匿名化策略", style = "font-weight: bold; color: #0056b3;"),
            choices = c(
              "完全删除" = "delete",
              "哈希处理 (MD5)" = "hash",
              "部分掩码" = "mask",
              "随机化处理" = "randomize"
            ),
            selected = "delete"
          ),
          conditionalPanel(
            condition = paste0("input['", ns("anon_strategy"), "'] == 'hash'"),
            helpText("使用MD5哈希算法对标识符进行加密处理。",
                    style = "color: #666; font-style: italic; margin-top: 5px;")
          ),
          conditionalPanel(
            condition = paste0("input['", ns("anon_strategy"), "'] == 'mask'"),
            helpText("将标识符替换为'***MASKED***'文本。",
                    style = "color: #666; font-style: italic; margin-top: 5px;")
          ),
          conditionalPanel(
            condition = paste0("input['", ns("anon_strategy"), "'] == 'randomize'"),
            helpText("使用随机值替换标识符，保持数据格式但去除可识别信息。",
                    style = "color: #666; font-style: italic; margin-top: 5px;")
          )
      )
    )
  })
  
  # 缺失值处理UI
  output$na_action_ui <- renderUI({
    if (is.null(raw_data())) {
      return(
        div(style = "padding: 10px; text-align: center; color: #666;",
            icon("exclamation-triangle"),
            "请先上传数据以显示缺失值处理选项"
        )
      )
    }
    
    radioButtons(
      ns("na_action"),
      "处理策略",
      choices = c(
        "仅标记，不处理" = "mark",
        "删除存在NA的行" = "rm_row",
        "数字列中位数填补/分类列众数填补" = "impute"
      ),
      selected = "mark"
    )
  })
  
  
  # 应用预处理
  observeEvent(input$apply_preprocess, {
    req(raw_data())
    
    # 应用类型转换
    processed_data <- raw_data()
    
    # 收集类型选择
    type_selections <- list()
    for (var in names(processed_data)) {
      input_id <- paste0("type_", var)
      if (!is.null(input[[input_id]])) {
        type_selections[[var]] <- input[[input_id]]
      }
    }
    
    # 应用类型转换
    for (var in names(type_selections)) {
      type <- type_selections[[var]]
      switch(type,
             "numeric" = {
               processed_data[[var]] <- as.numeric(processed_data[[var]])
             },
             "categorical" = {
               processed_data[[var]] <- as.factor(processed_data[[var]])
             },
             "date" = {
               processed_data[[var]] <- as.Date(processed_data[[var]])
             })
    }
    
    # 应用匿名化
    if (!is.null(input$anon_vars) && length(input$anon_vars) > 0) {
      for (col in input$anon_vars) {
        if (col %in% names(processed_data)) {
          switch(input$anon_strategy,
                 "delete" = {
                   processed_data[[col]] <- NULL
                 },
                 "hash" = {
                   processed_data[[col]] <- sapply(processed_data[[col]], function(x) {
                     digest::digest(as.character(x), algo = "md5")
                   })
                 },
                 "mask" = {
                   processed_data[[col]] <- sapply(processed_data[[col]], function(x) {
                     ifelse(is.na(x), NA, "***MASKED***")
                   })
                 },
                 "randomize" = {
                   if (is.numeric(processed_data[[col]])) {
                     processed_data[[col]] <- sample(processed_data[[col]],
                                                   size = length(processed_data[[col]]),
                                                   replace = FALSE)
                   } else if (is.character(processed_data[[col]]) || is.factor(processed_data[[col]])) {
                     unique_vals <- unique(na.omit(processed_data[[col]]))
                     random_vals <- sample(unique_vals, size = length(processed_data[[col]]),
                                         replace = TRUE)
                     processed_data[[col]] <- random_vals
                   }
                 })
        }
      }
    }
    
    # 应用缺失值处理
    if (!is.null(input$na_action)) {
      switch(input$na_action,
             "rm_row" = {
               processed_data <- processed_data[complete.cases(processed_data), ]
             },
             "impute" = {
               for (col in names(processed_data)) {
                 if (any(is.na(processed_data[[col]]))) {
                   if (is.numeric(processed_data[[col]])) {
                     median_val <- median(processed_data[[col]], na.rm = TRUE)
                     if (!is.na(median_val)) {
                       processed_data[[col]][is.na(processed_data[[col]])] <- median_val
                     }
                   } else if (is.factor(processed_data[[col]]) || is.character(processed_data[[col]])) {
                     mode_val <- names(sort(table(processed_data[[col]]), decreasing = TRUE))[1]
                     if (!is.na(mode_val)) {
                       processed_data[[col]][is.na(processed_data[[col]])] <- mode_val
                     }
                   }
                 }
               }
             })
    }
    
    
    # 应用DT表格的筛选条件
    # 获取当前显示的行的索引
    if (!is.null(input$raw_data_preview_rows_all)) {
      displayed_rows <- input$raw_data_preview_rows_all
      if (length(displayed_rows) > 0) {
        processed_data <- processed_data[displayed_rows, ]
      }
    }
    
    # 检查筛选后是否还有数据
    if (nrow(processed_data) == 0) {
      showNotification("警告：筛选条件导致数据为空，请调整筛选条件", type = "warning")
    } else {
      clean_data(processed_data)
      
      obs_count <- nrow(processed_data)
      var_count <- ncol(processed_data)
      
      showNotification(
        HTML(paste(
          "<div style='background-color: #d4edda; color: #155724; padding: 10px; border-radius: 5px;'>",
          "<strong>数据预处理完成</strong><br>",
          "剩余观测数: ", format(obs_count, big.mark = ","), "<br>",
          "剩余变量数: ", var_count,
          "</div>"
        )),
        type = "message",
        duration = 10
      )
    }
  })
  
  # 返回清理后的数据
  return(clean_data)
}