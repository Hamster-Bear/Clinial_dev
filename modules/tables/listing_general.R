# 一般列表生成模块 - 基于 rlistings 和 r2rtf
# 适用于生成通用的 CDISC 风格列表 (Listing)
# 支持自定义分组、显示变量、RTF 导出等

library(dplyr)
library(rlistings)
library(r2rtf)
`%||%` <- function(x, y) if (is.null(x)) y else x

normalize_listing_columns <- function(data, key_cols = NULL, disp_cols = NULL) {
  available_cols <- names(data %||% data.frame())
  raw_key_cols <- unique(key_cols %||% character(0))
  raw_disp_cols <- unique(disp_cols %||% character(0))
  missing_cols <- setdiff(unique(c(raw_key_cols, raw_disp_cols)), available_cols)
  key_cols <- intersect(raw_key_cols, available_cols)
  disp_cols <- intersect(raw_disp_cols, available_cols)
  list(
    key_cols = key_cols,
    disp_cols = disp_cols,
    missing_cols = missing_cols,
    available_cols = available_cols
  )
}

#' 一般列表参数 UI
#'
#' @param ns Shiny 命名空间函数
#' @param data 数据框
#' @return tagList
#' @export
listing_general_params_ui <- function(ns, data) {
  cols <- names(data)
  
  tagList(
    # 变量选择
    selectInput(
      ns("listing_key_cols"), 
      "Group 变量 (合并相同值):", 
      choices = cols, 
      selected = intersect(c("USUBJID", "SITEID"), cols), 
      multiple = TRUE
    ),
    selectInput(
      ns("listing_disp_cols"), 
      "Display 变量:", 
      choices = cols, 
      selected = setdiff(cols, c("USUBJID", "SITEID"))[1:min(6, length(cols))], 
      multiple = TRUE
    ),
    
    hr(),
    h5("格式设置"),
    checkboxInput(ns("listing_landscape"), "横向页面 (Landscape)", value = TRUE),
    sliderInput(ns("listing_font_size"), "字体大小", min = 7, max = 11, value = 9),
    
    # 下载按钮 (注意：需要在 server 端绑定 downloadHandler)
    downloadButton(ns("listing_download_rtf"), "导出 RTF (三线表+Group)")
  )
}

#' 执行一般列表分析 (生成预览对象)
#'
#' @param data 数据框
#' @param key_cols 分组变量
#' @param disp_cols 显示变量
#' @return rlistings listing 对象 (用于打印预览)
#' @export
perform_listing_general_analysis <- function(data, key_cols, disp_cols) {
  shiny::req(data, disp_cols)
  normalized <- normalize_listing_columns(data, key_cols, disp_cols)
  key_cols <- normalized$key_cols
  disp_cols <- normalized$disp_cols
  if (length(disp_cols) == 0) {
    stop("当前展示列已失效，请重新选择有效字段。")
  }
  
  # 数据清洗 (参考 listing_sample.R)
  # 优化：先排序，再格式化为字符，确保数值列按大小排序而非字典序
  clean_df <- data
  
  if (!is.null(key_cols) && length(key_cols) > 0) {
    clean_df <- clean_df %>% arrange(across(all_of(key_cols)))
  }
  
  clean_df <- clean_df %>%
    mutate(across(where(is.factor), as.character)) %>%
    mutate(across(where(is.numeric), ~ as.character(round(., 4)))) %>%
    mutate(across(everything(), ~ ifelse(is.na(.), "", .))) %>%
    ungroup()
  
  # 预览仅取前 50 行以提高性能
  df_view <- clean_df %>% 
    select(all_of(unique(c(key_cols, disp_cols)))) %>%
    head(50)
  
  # 生成 listing 对象
  as_listing(df_view, key_cols = key_cols, disp_cols = disp_cols)
}

#' 导出 RTF 逻辑
#'
#' @param data 原始数据
#' @param key_cols 分组变量
#' @param disp_cols 显示变量
#' @param file 目标文件路径
#' @param landscape 是否横向
#' @param font_size 字体大小
#' @export
export_listing_general_rtf <- function(data, key_cols, disp_cols, file, landscape = TRUE, font_size = 9) {
  shiny::req(data, disp_cols)
  normalized <- normalize_listing_columns(data, key_cols, disp_cols)
  key_cols <- normalized$key_cols
  disp_cols <- normalized$disp_cols
  if (length(disp_cols) == 0) {
    stop("当前导出列与数据不匹配，请重新选择变量后重试。")
  }
  
  # 1. 数据准备
  # 优化：先排序，再格式化为字符，确保数值列按大小排序而非字典序
  clean_df <- data
  
  if (!is.null(key_cols) && length(key_cols) > 0) {
    clean_df <- clean_df %>% arrange(across(all_of(key_cols)))
  }
  
  clean_df <- clean_df %>%
    mutate(across(where(is.factor), as.character)) %>%
    mutate(across(where(is.numeric), ~ as.character(round(., 4)))) %>%
    mutate(across(everything(), ~ ifelse(is.na(.), "", .))) %>%
    ungroup()
    
  all_cols <- unique(c(key_cols, disp_cols))
  
  # 必须转为纯 data.frame 避免 tibble 兼容性问题
  df_export <- clean_df %>% 
    select(all_of(all_cols)) %>%
    as.data.frame() 
  
  # 2. 模拟 SAS Group (留白处理)
  if (nrow(df_export) > 1 && length(key_cols) > 0) {
    for (col in key_cols) {
      vec <- df_export[[col]]
      # 比较当前行与上一行
      is_duplicate <- c(FALSE, vec[-1] == vec[-length(vec)])
      df_export[[col]][is_duplicate] <- ""
    }
  }
  
  final_cols <- names(df_export)
  
  # 3. 参数计算
  col_width <- nchar(final_cols)
  # 计算内容最大长度 (取前 100 行估算)
  content_width <- sapply(df_export[1:min(nrow(df_export), 100), ], function(x) max(nchar(as.character(x)), na.rm = TRUE))
  # 取最大值
  width_vals <- pmax(col_width, content_width, na.rm = TRUE)
  
  # 简单估算列宽，最小 8，适当增加缓冲
  rel_widths <- as.numeric(ifelse(width_vals < 8, 8, width_vals * 1.1)) 
  
  # 统一左对齐
  aligns <- rep("l", length(final_cols))
  f_size <- as.numeric(font_size)
  
  # 4. r2rtf 管道
  df_export %>%
    rtf_page(
      orientation = if(landscape) "landscape" else "portrait",
      border_first = "single", 
      border_last = "single"   
    ) %>%
    rtf_title(
      "Listing of Subject Data",
      text_font_size = 12,
      text_format = "b"
    ) %>%
    rtf_colheader(
      colheader = paste(final_cols, collapse = "|"),
      col_rel_width = rel_widths,
      col_justification = aligns, # 表头也应用左对齐
      text_font_size = f_size,
      text_format = "b",
      border_top = "double",   
      border_bottom = "single",
      border_left = "",        
      border_right = ""      
    ) %>%
    rtf_body(
      col_rel_width = rel_widths,
      text_justification = aligns,
      text_font_size = f_size,
      border_left = "", 
      border_right = "",
      border_top = "", 
      border_bottom = "" 
    ) %>%
    rtf_footnote(
      paste("Generated on:", Sys.Date()),
      text_font_size = 8
    ) %>%
    rtf_encode() %>%
    write_rtf(file)
}

#' 生成代码 (占位)
#' @export
generate_listing_general_code <- function(key_cols, disp_cols, landscape, font_size) {
  paste0(
    "# 生成 Listing 代码示例\n",
    "library(rlistings)\n",
    "library(r2rtf)\n",
    "# 请参考 export_listing_general_rtf 函数逻辑\n",
    "# Key Cols: ", paste(key_cols, collapse = ", "), "\n",
    "# Disp Cols: ", paste(disp_cols, collapse = ", "), "\n"
  )
}
