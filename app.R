# 检查并加载必要的包
required_packages <- c(
  "shiny", "shinydashboard", "shinyjs", "shinyBS", "bslib",
  "dplyr", "readr", "readxl", "haven", "ggplot2", "plotly",
  "DT", "gt", "purrr", "stringr", "survival", "broom", "survminer",
  "corrplot", "ggsci", "patchwork", "digest", "colourpicker", "reactable",
  "waiter", "shinyalert", "scales", "gridExtra", "cowplot", "RColorBrewer",
  "tidyr", "vroom", "memoise", "shinyWidgets", "gtsummary",
  "DBI", "RPostgres", "pool", "rmarkdown", "knitr", "flextable", "officer"
)

# 校验依赖包，不在 app.R 内执行安装
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    paste0(
      "检测到缺失依赖包：",
      paste(missing_packages, collapse = ", "),
      "。请先运行 run_app.R 或 install_dependencies.R 完成安装。"
    )
  )
}

invisible(lapply(required_packages, function(pkg) {
  library(pkg, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)
}))

# 加载所有模块
source("modules/common/storage_backend.R")
source("modules/data_preparation.R")
source("modules/database_manager.R")
source("modules/exploratory_analysis.R")
source("modules/statistical_analysis.R")
source("modules/statistical_graphics.R")
source("modules/tables.R")

# 定义UI
ui <- dashboardPage(
  skin = "black",
  
  # 头部
  dashboardHeader(
    title = "Medical Data Analysis Suite",
    titleWidth = 300,
    dropdownMenu(
      type = "notifications",
      notificationItem(
        text = "系统就绪",
        icon = icon("check-circle"),
        status = "success"
      )
    )
  ),
  
  # 侧边栏
  dashboardSidebar(
    width = 300,
    sidebarMenu(
      id = "tabs",
      menuItem("1. 数据库管理",
               tabName = "db_manage",
               icon = icon("database"),
               badgeLabel = "第一步",
               badgeColor = "blue"),
      
      menuItem("2. 数据准备",
               tabName = "data_prep",
               icon = icon("upload"),
               badgeLabel = "第二步",
               badgeColor = "blue"),
      
      menuItem("3. 探索与可视化",
               tabName = "explore",
               icon = icon("bar-chart"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      
      menuItem("4. 统计分析",
               tabName = "stats",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      
      menuItem("5. 统计图形",
               tabName = "plots",
               icon = icon("line-chart"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      
      menuItem("6. 专业表格",
               tabName = "tables",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "green")
    )
  ),
  
  # 主体
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
      tags$script(HTML("
        $(document).on('shiny:connected', function() {
          Shiny.setInputValue('plotly_pagination_info', 'Plotly目前不支持图形分页功能。对于大型数据集，建议使用数据筛选或抽样来减少数据点数量，或者使用交互式缩放功能来浏览数据的不同区域。');
        });
      "))
    ),
    
    tabItems(
      tabItem(
        tabName = "db_manage",
        database_manager_ui("db_manage")
      ),
      
      # 数据准备标签页
      tabItem(
        tabName = "data_prep",
        data_preparation_ui("data_prep")
      ),
      
      # 探索分析标签页
      tabItem(
        tabName = "explore",
        exploratory_analysis_ui("explore")
      ),
      
      # 统计分析标签页
      tabItem(
        tabName = "stats",
        statistical_analysis_ui("stats")
      ),
      
      # 统计图形标签页
      tabItem(
        tabName = "plots",
        statistical_graphics_ui("plots")
      ),
      
      # 专业表格标签页
      tabItem(
        tabName = "tables",
        tables_ui("tables")
      )
    )
  )
)

# 定义服务器逻辑
server <- function(input, output, session) {
  
  # NULL coalescing operator for reactive values
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  # 反应式数据存储 - 在模块间共享（简化）
  raw_data <- reactiveVal(NULL)
  filtered_data <- reactiveVal(NULL)  # 所有模块使用筛选后的数据
  
  # 状态更新辅助函数
  update_step_status <- function(step, status) {
    # status: "need_data" (需数据) or "accessible" (可访问)
    
    selector <- paste0('[data-value="', step, '"]')
    
    if (status == "accessible") {
      shinyjs::enable(selector = selector)
      shinyjs::runjs(paste0('
        $("', selector, '").find(".badge")
          .removeClass("bg-black")
          .addClass("bg-blue")
          .text("可访问");
      '))
    } else {
      shinyjs::disable(selector = selector)
      shinyjs::runjs(paste0('
        $("', selector, '").find(".badge")
          .removeClass("bg-blue")
          .addClass("bg-black")
          .text("需数据");
      '))
    }
  }
  
  database_manager_server("db_manage")
  
  # 调用数据准备模块
  data_prep_module <- data_preparation_server("data_prep")
  
  # 观察数据准备模块返回的数据（筛选后的数据）
  observe({
    req(data_prep_module())
    filtered_data(data_prep_module())
  })
  
  # 调用探索性分析模块 - 使用筛选后的数据
  explore_module <- exploratory_analysis_server("explore", data = filtered_data)
  
  # 调用统计分析模块 - 使用筛选后的数据
  stats_module <- statistical_analysis_server("stats", data = filtered_data)
  
  # 调用统计图形模块 - 使用筛选后的数据
  plots_module <- statistical_graphics_server("plots", data = filtered_data)
  
  # 调用专业表格模块 - 使用筛选后的数据
  tables_module <- tables_server("tables", data = filtered_data)
  
  # 观察数据状态变化并更新侧边栏状态
  observe({
    data_available <- !is.null(filtered_data())
    
    steps <- c("explore", "stats", "plots", "tables")
    
    if (data_available) {
      lapply(steps, function(step) {
        update_step_status(step, "accessible")
      })
    } else {
      lapply(steps, function(step) {
        update_step_status(step, "need_data")
      })
    }
  })
}

# 运行应用
shinyApp(ui, server)
