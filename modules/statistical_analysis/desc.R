# 描述性统计模块

# 描述性统计参数UI
desc_params_ui <- function(ns, data) {
  tagList(
    selectizeInput(ns("desc_vars"), "选择变量", choices = names(data), multiple = TRUE),
    checkboxGroupInput(ns("desc_stats"), "统计量",
                       choices = c("平均值" = "mean", "标准差" = "sd", "中位数" = "median",
                                   "最小值" = "min", "最大值" = "max", "缺失值" = "na"),
                       selected = c("mean", "sd"))
  )
}

# 描述性统计
perform_desc_analysis <- function(data, desc_vars, desc_stats) {
  req(desc_vars, desc_stats)
  
  # 验证变量是否存在
  missing_vars <- desc_vars[!desc_vars %in% names(data)]
  if (length(missing_vars) > 0) {
    stop(paste("变量不存在:", paste(missing_vars, collapse = ", ")))
  }
  
  desc_data <- data %>% select(all_of(desc_vars))
  
  stats_list <- list()
  
  # 只对数值型变量计算统计量
  numeric_vars <- names(desc_data)[sapply(desc_data, is.numeric)]
  
  if ("mean" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Mean <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) mean(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("sd" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$SD <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) sd(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("median" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Median <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) median(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("min" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Min <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) min(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("max" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Max <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) max(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("na" %in% desc_stats) {
    stats_list$Missing <- colSums(is.na(desc_data))
  }
  
  # 处理空结果的情况
  if (length(stats_list) == 0) {
    return(data.frame(Variable = desc_vars, Note = "无可用统计量"))
  }
  
  result <- as.data.frame(do.call(cbind, stats_list))
  result$Variable <- rownames(result)
  result <- result %>% select(Variable, everything())
  
  return(result)
}