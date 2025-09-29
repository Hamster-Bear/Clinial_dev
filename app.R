library(shiny)
library(shinydashboard)
library(shinyjs)
library(shinyBS)
library(bslib)
library(dplyr)
library(readr)
library(readxl)
library(haven)
library(ggplot2)
library(plotly)
library(DT)
library(gt)
library(purrr)
library(stringr)
library(survival)
library(broom)
library(survminer)
library(corrplot)
library(ggsci)
library(patchwork)
library(digest)
library(colourpicker)

# 加载所有模块
source("modules/data_preparation.R")
source("modules/exploratory_analysis.R")
source("modules/statistical_analysis.R")
source("modules/statistical_graphics.R")

# 定义UI
ui <- dashboardPage(
  skin = "blue",
  
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
      menuItem("1. 数据准备", 
               tabName = "data_prep", 
               icon = icon("database"),
               badgeLabel = "第一步", 
               badgeColor = "blue"),
      
      menuItem("2. 探索与可视化",
               tabName = "explore",
               icon = icon("bar-chart"),
               badgeLabel = "可访问",
               badgeColor = "blue"),
      
      menuItem("3. 统计分析",
               tabName = "stats",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "blue"),
      
      menuItem("4. 统计图形",
               tabName = "plots",
               icon = icon("line-chart"),
               badgeLabel = "可访问",
               badgeColor = "blue")
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
      )
    )
  )
)

# 定义服务器逻辑
server <- function(input, output, session) {
  
  # NULL coalescing operator for reactive values
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  # 反应式数据存储 - 在模块间共享
  raw_data <- reactiveVal(NULL)
  clean_data <- reactiveVal(NULL)
  type_info <- reactiveVal(NULL)
  
  # 调用数据准备模块
  data_prep_module <- callModule(data_preparation_server, "data_prep")
  
  # 观察数据准备模块返回的数据
  observe({
    req(data_prep_module())
    clean_data(data_prep_module())
  })
  
  # 调用探索性分析模块
  explore_module <- callModule(exploratory_analysis_server, "explore", data = clean_data)
  
  # 调用统计分析模块
  stats_module <- callModule(statistical_analysis_server, "stats", data = clean_data)
  
  # 调用统计图形模块
  plots_module <- callModule(statistical_graphics_server, "plots", data = clean_data)
  
  # 观察数据状态变化并更新侧边栏状态
  observe({
    data_available <- !is.null(clean_data())
    
    if (data_available) {
      # 启用所有分析步骤
      lapply(c("explore", "stats", "plots"), function(tab) {
        shinyjs::enable(selector = paste0('[data-value="', tab, '"]'))
        # 更新徽章状态
        runjs(paste0('
          $(\'[data-value="', tab, '"]\').find(".badge")
            .removeClass("bg-black")
            .addClass("bg-blue")
            .text("可访问");
        '))
      })
    } else {
      # 禁用分析步骤
      lapply(c("explore", "stats", "plots"), function(tab) {
        shinyjs::disable(selector = paste0('[data-value="', tab, '"]'))
        # 更新徽章状态
        runjs(paste0('
          $(\'[data-value="', tab, '"]\').find(".badge")
            .removeClass("bg-blue")
            .addClass("bg-black")
            .text("需数据");
        '))
      })
    }
  })
}

# 运行应用
shinyApp(ui, server)
