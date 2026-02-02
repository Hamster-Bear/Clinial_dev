# 描述性统计模块 - 增强版

# 加载必要库
library(dplyr)
library(tidyr)
library(gt)
library(stringr)

# 描述性统计参数UI

# 描述性统计参数UI
desc_params_ui <- function(ns, data) {
  var_names <- names(data)
  
  tagList(
    selectizeInput(ns("desc_variables"), "选择分析变量", choices = var_names, multiple = TRUE),
    selectInput(ns("desc_col_group_var"), "列分组变量 (可选)", choices = c("无", var_names)),
    selectInput(ns("desc_row_group_var"), "行分组变量 (可选)", choices = c("无", var_names)),
    
    # 自定义总计列设置
    conditionalPanel(
      condition = paste0("input['", ns("desc_col_group_var"), "'] != '无'"),
      h4("总计列设置"),
      numericInput(ns("desc_total_cols_count"), "总计列数量", value = 1, min = 1, max = 5),
      uiOutput(ns("desc_total_cols_ui"))
    ),
    
    numericInput(ns("desc_decimals"), "小数位数", value = 2, min = 0, max = 5),
    checkboxInput(ns("desc_auto_decimals"), "使用自动小数位数", value = TRUE)
  )
}

# 计算变量的原始数据小数位数
calculate_original_decimals <- function(data, variables) {
  numeric_vars <- variables[sapply(data[, variables, drop = FALSE], is.numeric)]
  decimal_info <- list()
  
  for(var in numeric_vars) {
    # 获取非缺失值
    values <- na.omit(data[[var]])
    if(length(values) == 0) {
      decimal_info[[var]] <- 0
      next
    }
    
    # 计算原始数据的小数位数
    decimals <- sapply(values, function(x) {
      if(is.integer(x) || x == round(x)) return(0)
      # 转换为字符串并计算小数位数
      x_str <- as.character(x)
      if(grepl("\\.", x_str)) {
        return(nchar(strsplit(x_str, "\\.")[[1]][2]))
      } else {
        return(0)
      }
    })
    
    # 取最常见的小数位数
    if(length(decimals) > 0) {
      decimal_counts <- table(decimals)
      most_common <- as.numeric(names(decimal_counts)[which.max(decimal_counts)])
      decimal_info[[var]] <- most_common
    } else {
      decimal_info[[var]] <- 0
    }
  }
  
  return(decimal_info)
}

# 描述性统计分析
perform_desc_analysis <- function(data, variables, col_group_var, row_group_var, total_cols_count, total_cols_settings, decimals, auto_decimals = TRUE) {
  req(data, variables)
  
  df <- data
  vars <- variables
  col_group_var <- if(col_group_var != "无") col_group_var else NULL
  row_group_var <- if(row_group_var != "无") row_group_var else NULL
  
  # 识别变量类型
  numeric_vars <- vars[sapply(df[, vars, drop = FALSE], is.numeric)]
  factor_vars <- setdiff(vars, numeric_vars)
  
  # 获取总计列设置
  total_settings <- if(!is.null(col_group_var)) total_cols_settings else list()
  
  # 计算自动小数位数
  auto_decimals_info <- if(auto_decimals && length(numeric_vars) > 0) {
    calculate_original_decimals(df, numeric_vars)
  } else {
    list()
  }
  
  # 自定义函数生成统计表格
  generate_stats_table <- function(data, numeric_vars, factor_vars, col_group_var = NULL, row_group_var = NULL, total_settings = list(), decimals = 2, auto_decimals = TRUE, auto_decimals_info = list()) {
    result_list <- list()
    
    # 处理分类变量
    if(length(factor_vars) > 0) {
      for(var in factor_vars) {
        # 存在行分组变量
        if(!is.null(row_group_var)) {
          # 存在列分组变量
          if(!is.null(col_group_var)) {
            group_counts <- data %>%
              group_by(!!sym(row_group_var), !!sym(col_group_var)) %>%
              count(!!sym(var)) %>%
              mutate(percent = n / sum(n) * 100) %>%
              mutate(stat = sprintf(paste0("%d (%.", decimals, "f%%)"), n, percent)) %>%
              select(!!sym(row_group_var), !!sym(col_group_var), !!sym(var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat",
                                 values_fill = paste0("0 (0.", paste0(rep("0", decimals), collapse = ""), "%)"))
            
            # 添加变量名和统计类型
            group_counts$Variable <- var
            group_counts$Statistics <- group_counts[[var]]
            group_counts <- group_counts %>%
              select(Variable, RowGroup = !!sym(row_group_var), Statistics, everything(), -!!sym(var))
            
            result_list[[var]] <- group_counts
          } else {
            # 无列分组变量
            total_counts <- data %>%
              group_by(!!sym(row_group_var)) %>%
              count(!!sym(var)) %>%
              mutate(percent = n / sum(n) * 100) %>%
              mutate(Statistics = !!sym(var),
                     Total = sprintf(paste0("%d (%.", decimals, "f%%)"), n, percent)) %>%
              select(RowGroup = !!sym(row_group_var), Variable = !!sym(var), Statistics, Total)
            
            total_counts$Variable <- var
            total_counts <- total_counts %>%
              select(Variable, RowGroup, Statistics, Total)
            
            result_list[[var]] <- total_counts
          }
        } else {
          # 无行分组变量，沿用原有逻辑
          if(!is.null(col_group_var)) {
            group_counts <- data %>%
              group_by(!!sym(col_group_var)) %>%
              count(!!sym(var)) %>%
              mutate(percent = n / sum(n) * 100) %>%
              mutate(stat = sprintf(paste0("%d (%.", decimals, "f%%)"), n, percent)) %>%
              select(!!sym(col_group_var), !!sym(var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat",
                                 values_fill = paste0("0 (0.", paste0(rep("0", decimals), collapse = ""), "%)"))
            
            # 添加变量名和统计类型
            group_counts$Variable <- var
            group_counts$Statistics <- group_counts[[var]]
            group_counts <- group_counts %>%
              select(Variable, Statistics, everything(), -!!sym(var))
            
            result_list[[var]] <- group_counts
          } else {
            # 无分组统计
            total_counts <- data %>%
              count(!!sym(var)) %>%
              mutate(percent = n / sum(n) * 100) %>%
              mutate(Statistics = !!sym(var),
                     Total = sprintf(paste0("%d (%.", decimals, "f%%)"), n, percent)) %>%
              select(Variable = !!sym(var), Statistics, Total)
            
            total_counts$Variable <- var
            total_counts <- total_counts %>%
              select(Variable, Statistics, Total)
            
            result_list[[var]] <- total_counts
          }
        }
      }
    }
    
    # 处理连续变量
    if(length(numeric_vars) > 0) {
      for(var in numeric_vars) {
        # 确定小数位数
        if(auto_decimals && var %in% names(auto_decimals_info)) {
          base_decimals <- auto_decimals_info[[var]]
          sd_decimals <- base_decimals + 2
          min_max_decimals <- base_decimals
          q1_q3_decimals <- base_decimals + 1
          median_mean_decimals <- base_decimals + 1
        } else {
          sd_decimals <- decimals
          min_max_decimals <- decimals
          q1_q3_decimals <- decimals
          median_mean_decimals <- decimals
        }

        # 存在行分组变量
        if(!is.null(row_group_var)) {
          # 存在列分组变量
          if(!is.null(col_group_var)) {
            # 分组统计 - 均值(标准差)
            mean_sd <- data %>%
              group_by(!!sym(row_group_var), !!sym(col_group_var)) %>%
              summarise(
                mean_val = mean(!!sym(var), na.rm = TRUE),
                sd_val = sd(!!sym(var), na.rm = TRUE)
              ) %>%
              mutate(stat = sprintf(paste0("%.", median_mean_decimals, "f (%.", sd_decimals, "f)"), mean_val, sd_val)) %>%
              select(!!sym(row_group_var), !!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 分组统计 - 中位数
            median_val <- data %>%
              group_by(!!sym(row_group_var), !!sym(col_group_var)) %>%
              summarise(stat = sprintf(paste0("%.", median_mean_decimals, "f"), median(!!sym(var), na.rm = TRUE))) %>%
              select(!!sym(row_group_var), !!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 分组统计 - 最小值,最大值
            min_max <- data %>%
              group_by(!!sym(row_group_var), !!sym(col_group_var)) %>%
              summarise(stat = sprintf(paste0("%.", min_max_decimals, "f, %.", min_max_decimals, "f"),
                                       min(!!sym(var), na.rm = TRUE),
                                       max(!!sym(var), na.rm = TRUE))) %>%
              select(!!sym(row_group_var), !!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 分组统计 - 四分位数
            quartiles <- data %>%
              group_by(!!sym(row_group_var), !!sym(col_group_var)) %>%
              summarise(
                q1 = quantile(!!sym(var), 0.25, na.rm = TRUE),
                q3 = quantile(!!sym(var), 0.75, na.rm = TRUE)
              ) %>%
              mutate(stat = sprintf(paste0("%.", q1_q3_decimals, "f, %.", q1_q3_decimals, "f"), q1, q3)) %>%
              select(!!sym(row_group_var), !!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 合并所有统计量
            stats_df <- bind_rows(
              data.frame(Statistics = "Mean (SD)", mean_sd, stringsAsFactors = FALSE),
              data.frame(Statistics = "Median", median_val, stringsAsFactors = FALSE),
              data.frame(Statistics = "Min, Max", min_max, stringsAsFactors = FALSE),
              data.frame(Statistics = "Q1, Q3", quartiles, stringsAsFactors = FALSE)
            )

            # 添加变量名和行分组列
            stats_df$Variable <- var
            stats_df <- stats_df %>%
              select(Variable, RowGroup = !!sym(row_group_var), Statistics, everything())

            result_list[[var]] <- stats_df
          } else {
            # 无列分组变量
            # 总计 - 均值(标准差)
            total_mean_sd <- data %>%
              group_by(!!sym(row_group_var)) %>%
              summarise(
                mean_val = mean(!!sym(var), na.rm = TRUE),
                sd_val = sd(!!sym(var), na.rm = TRUE)
              ) %>%
              mutate(Statistics = "Mean (SD)",
                     Total = sprintf(paste0("%.", median_mean_decimals, "f (%.", sd_decimals, "f)"), mean_val, sd_val)) %>%
              select(RowGroup = !!sym(row_group_var), Statistics, Total)

            # 总计 - 中位数
            total_median <- data %>%
              group_by(!!sym(row_group_var)) %>%
              summarise(
                Statistics = "Median",
                Total = sprintf(paste0("%.", median_mean_decimals, "f"), median(!!sym(var), na.rm = TRUE))
              ) %>%
              select(RowGroup = !!sym(row_group_var), Statistics, Total)

            # 总计 - 最小值,最大值
            total_min_max <- data %>%
              group_by(!!sym(row_group_var)) %>%
              summarise(
                Statistics = "Min, Max",
                Total = sprintf(paste0("%.", min_max_decimals, "f, %.", min_max_decimals, "f"),
                                min(!!sym(var), na.rm = TRUE),
                                max(!!sym(var), na.rm = TRUE))
              ) %>%
              select(RowGroup = !!sym(row_group_var), Statistics, Total)

            # 总计 - 四分位数
            total_quartiles <- data %>%
              group_by(!!sym(row_group_var)) %>%
              summarise(
                q1 = quantile(!!sym(var), 0.25, na.rm = TRUE),
                q3 = quantile(!!sym(var), 0.75, na.rm = TRUE)
              ) %>%
              mutate(
                Statistics = "Q1, Q3",
                Total = sprintf(paste0("%.", q1_q3_decimals, "f, %.", q1_q3_decimals, "f"), q1, q3)
              ) %>%
              select(RowGroup = !!sym(row_group_var), Statistics, Total)

            # 合并所有统计量
            stats_df <- bind_rows(
              total_mean_sd,
              total_median,
              total_min_max,
              total_quartiles
            )

            # 添加变量名
            stats_df$Variable <- var
            stats_df <- stats_df %>%
              select(Variable, RowGroup, Statistics, Total)

            result_list[[var]] <- stats_df
          }
        } else {
          # 无行分组变量，沿用原有逻辑
          if(!is.null(col_group_var)) {
            # 分组统计 - 均值(标准差)
            mean_sd <- data %>%
              group_by(!!sym(col_group_var)) %>%
              summarise(
                mean_val = mean(!!sym(var), na.rm = TRUE),
                sd_val = sd(!!sym(var), na.rm = TRUE)
              ) %>%
              mutate(stat = sprintf(paste0("%.", median_mean_decimals, "f (%.", sd_decimals, "f)"), mean_val, sd_val)) %>%
              select(!!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 分组统计 - 中位数
            median_val <- data %>%
              group_by(!!sym(col_group_var)) %>%
              summarise(stat = sprintf(paste0("%.", median_mean_decimals, "f"), median(!!sym(var), na.rm = TRUE))) %>%
              select(!!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 分组统计 - 最小值,最大值
            min_max <- data %>%
              group_by(!!sym(col_group_var)) %>%
              summarise(stat = sprintf(paste0("%.", min_max_decimals, "f, %.", min_max_decimals, "f"),
                                       min(!!sym(var), na.rm = TRUE),
                                       max(!!sym(var), na.rm = TRUE))) %>%
              select(!!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 分组统计 - 四分位数
            quartiles <- data %>%
              group_by(!!sym(col_group_var)) %>%
              summarise(
                q1 = quantile(!!sym(var), 0.25, na.rm = TRUE),
                q3 = quantile(!!sym(var), 0.75, na.rm = TRUE)
              ) %>%
              mutate(stat = sprintf(paste0("%.", q1_q3_decimals, "f, %.", q1_q3_decimals, "f"), q1, q3)) %>%
              select(!!sym(col_group_var), stat) %>%
              tidyr::pivot_wider(names_from = !!sym(col_group_var), values_from = "stat")

            # 合并所有统计量
            stats_df <- bind_rows(
              data.frame(Statistics = "Mean (SD)", mean_sd, stringsAsFactors = FALSE),
              data.frame(Statistics = "Median", median_val, stringsAsFactors = FALSE),
              data.frame(Statistics = "Min, Max", min_max, stringsAsFactors = FALSE),
              data.frame(Statistics = "Q1, Q3", quartiles, stringsAsFactors = FALSE)
            )

            # 添加变量名
            stats_df$Variable <- var
            stats_df <- stats_df %>%
              select(Variable, Statistics, everything())

            result_list[[var]] <- stats_df
          } else {
            # 无分组统计
            # 总计 - 均值(标准差)
            total_mean_sd <- data %>%
              summarise(
                mean_val = mean(!!sym(var), na.rm = TRUE),
                sd_val = sd(!!sym(var), na.rm = TRUE)
              ) %>%
              mutate(Statistics = "Mean (SD)",
                     Total = sprintf(paste0("%.", median_mean_decimals, "f (%.", sd_decimals, "f)"), mean_val, sd_val)) %>%
              select(Statistics, Total)

            # 总计 - 中位数
            total_median <- data %>%
              summarise(
                Statistics = "Median",
                Total = sprintf(paste0("%.", median_mean_decimals, "f"), median(!!sym(var), na.rm = TRUE))
              ) %>%
              select(Statistics, Total)

            # 总计 - 最小值,最大值
            total_min_max <- data %>%
              summarise(
                Statistics = "Min, Max",
                Total = sprintf(paste0("%.", min_max_decimals, "f, %.", min_max_decimals, "f"),
                                min(!!sym(var), na.rm = TRUE),
                                max(!!sym(var), na.rm = TRUE))
              ) %>%
              select(Statistics, Total)

            # 总计 - 四分位数
            total_quartiles <- data %>%
              summarise(
                q1 = quantile(!!sym(var), 0.25, na.rm = TRUE),
                q3 = quantile(!!sym(var), 0.75, na.rm = TRUE)
              ) %>%
              mutate(
                Statistics = "Q1, Q3",
                Total = sprintf(paste0("%.", q1_q3_decimals, "f, %.", q1_q3_decimals, "f"), q1, q3)
              ) %>%
              select(Statistics, Total)

            # 合并所有统计量
            stats_df <- bind_rows(
              total_mean_sd,
              total_median,
              total_min_max,
              total_quartiles
            )

            # 添加变量名
            stats_df$Variable <- var
            stats_df <- stats_df %>%
              select(Variable, Statistics, Total)

            result_list[[var]] <- stats_df
          }
        }
      }
    }
    
    # 合并所有结果
    if(length(result_list) > 0) {
      final_result <- bind_rows(result_list)
      
      # 统一添加总计列（在合并后统一处理，避免重复）
      if(!is.null(col_group_var) && length(total_settings) > 0) {
        # 获取所有分组列名
        group_cols <- setdiff(names(final_result), c("Variable", "Statistics"))
        
        for(i in seq_along(total_settings)) {
          setting <- total_settings[[i]]
          col_name <- setting$name
          groups <- setting$groups
          
          if(length(groups) > 0) {
            # 为每个变量计算总计列
            total_col_data <- data.frame(Variable = character(), Statistics = character(), TotalCol = character(), stringsAsFactors = FALSE)
            
            # 处理分类变量
            for(var in factor_vars) {
              total_counts <- data %>%
                filter(!!sym(col_group_var) %in% groups) %>%
                count(!!sym(var)) %>%
                mutate(percent = n / sum(n) * 100) %>%
                mutate(Statistics = !!sym(var),
                       TotalCol = sprintf(paste0("%d (%.", decimals, "f%%)"), n, percent)) %>%
                select(Variable = !!sym(var), Statistics, TotalCol)
              
              total_counts$Variable <- var
              total_col_data <- bind_rows(total_col_data, total_counts)
            }
            
            # 处理连续变量
            for(var in numeric_vars) {
              # 确定小数位数
              if(auto_decimals && var %in% names(auto_decimals_info)) {
                base_decimals <- auto_decimals_info[[var]]
                sd_decimals <- base_decimals + 2
                min_max_decimals <- base_decimals
                q1_q3_decimals <- base_decimals + 1
                median_mean_decimals <- base_decimals + 1
              } else {
                sd_decimals <- decimals
                min_max_decimals <- decimals
                q1_q3_decimals <- decimals
                median_mean_decimals <- decimals
              }
              
              # 均值(标准差)
              mean_sd_total <- data %>%
                filter(!!sym(col_group_var) %in% groups) %>%
                summarise(
                  mean_val = mean(!!sym(var), na.rm = TRUE),
                  sd_val = sd(!!sym(var), na.rm = TRUE)
                ) %>%
                mutate(Statistics = "Mean (SD)",
                       TotalCol = sprintf(paste0("%.", median_mean_decimals, "f (%.", sd_decimals, "f)"), mean_val, sd_val)) %>%
                select(Statistics, TotalCol)
              mean_sd_total$Variable <- var
              
              # 中位数
              median_total <- data %>%
                filter(!!sym(col_group_var) %in% groups) %>%
                summarise(
                  Statistics = "Median",
                  TotalCol = sprintf(paste0("%.", median_mean_decimals, "f"), median(!!sym(var), na.rm = TRUE))
                ) %>%
                select(Statistics, TotalCol)
              median_total$Variable <- var
              
              # 最小值,最大值
              min_max_total <- data %>%
                filter(!!sym(col_group_var) %in% groups) %>%
                summarise(
                  Statistics = "Min, Max",
                  TotalCol = sprintf(paste0("%.", min_max_decimals, "f, %.", min_max_decimals, "f"),
                                    min(!!sym(var), na.rm = TRUE),
                                    max(!!sym(var), na.rm = TRUE))
                ) %>%
                select(Statistics, TotalCol)
              min_max_total$Variable <- var
              
              # 四分位数
              quartiles_total <- data %>%
                filter(!!sym(col_group_var) %in% groups) %>%
                summarise(
                  q1 = quantile(!!sym(var), 0.25, na.rm = TRUE),
                  q3 = quantile(!!sym(var), 0.75, na.rm = TRUE)
                ) %>%
                mutate(
                  Statistics = "Q1, Q3",
                  TotalCol = sprintf(paste0("%.", q1_q3_decimals, "f, %.", q1_q3_decimals, "f"), q1, q3)
                ) %>%
                select(Statistics, TotalCol)
              quartiles_total$Variable <- var
              
              total_col_data <- bind_rows(total_col_data, mean_sd_total, median_total, min_max_total, quartiles_total)
            }
            
            # 合并总计列到最终结果
            final_result <- final_result %>%
              left_join(total_col_data %>% select(Variable, Statistics, !!col_name := TotalCol),
                        by = c("Variable", "Statistics"))
          }
        }
      }
      
      return(final_result)
    } else {
      return(NULL)
    }
  }
  
  # 生成统计表格
  result_table <- generate_stats_table(df, numeric_vars, factor_vars, col_group_var, row_group_var, total_settings, decimals, auto_decimals, auto_decimals_info)
  
  # 转换为gt表格
  if (!is.null(result_table)) {
    # 检查是否存在RowGroup列
    if ("RowGroup" %in% names(result_table)) {
      # 按Variable和RowGroup排序
      result_table <- result_table %>%
        arrange(Variable, RowGroup)
      
      # 添加行号
      result_table <- result_table %>%
        mutate(row_idx = row_number())
      
      # 计算每个Variable组内每个RowGroup子组的行范围
      group_ranges <- result_table %>%
        group_by(Variable, RowGroup) %>%
        summarise(start = min(row_idx), end = max(row_idx), .groups = 'drop')
      
      # 移除临时列
      result_table <- result_table %>% select(-row_idx)
      
      # 创建基础gt表格，按Variable分组，隐藏RowGroup列
      gt_table <- gt::gt(result_table, groupname_col = "Variable") %>%
        gt::cols_hide(columns = "RowGroup")
      
      # 添加二级分组（RowGroup）使用tab_row_group，并确保唯一ID
      for(i in seq_len(nrow(group_ranges))) {
        unique_id <- paste0(group_ranges$Variable[i], "_", group_ranges$RowGroup[i])
        gt_table <- gt_table %>%
          gt::tab_row_group(
            label = group_ranges$RowGroup[i],
            rows = group_ranges$start[i]:group_ranges$end[i],
            id = unique_id
          )
      }
      
    } else {
      # 无RowGroup列，仅按Variable分组
      gt_table <- gt::gt(result_table, groupname_col = "Variable")
    }
    
    # 应用基本格式化
    gt_table <- gt_table %>%
      gt::fmt_number(columns = where(is.numeric), decimals = decimals) %>%
      gt::tab_options(table.font.size = "small")
    return(gt_table)
  } else {
    return(NULL)
  }
}
