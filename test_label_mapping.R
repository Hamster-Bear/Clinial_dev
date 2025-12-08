#!/usr/bin/env Rscript

# 测试生存分析模块中的标签映射逻辑
cat("测试中位生存标签映射...\n")

# 加载必要包
library(survival)
library(survminer)

# 创建模拟生存数据
set.seed(123)
n <- 100
data <- data.frame(
  time = rexp(n, rate = 0.1),
  status = rbinom(n, 1, 0.8),
  grp = factor(rep(c("A", "B"), each = n/2))
)

# 模拟用户标签映射：将"A"映射为"Group Alpha"，"B"映射为"Group Beta"
labels <- list(A = "Group Alpha", B = "Group Beta")

# 复制数据并应用映射
plot_data <- data
strata_col <- as.character(plot_data$grp)
for (orig in names(labels)) {
  if (labels[[orig]] != "") {
    strata_col[strata_col == orig] <- labels[[orig]]
  }
}
plot_data$grp <- factor(strata_col, levels = unique(strata_col))

# 重新拟合生存曲线
surv_obj <- Surv(plot_data$time, plot_data$status)
fit_local <- surv_fit(surv_obj ~ grp, data = plot_data)

# 计算中位生存时间
median_surv <- surv_median(fit_local)
cat("中位生存时间表:\n")
print(median_surv)

# 检查strata列内容
cat("\nstrata列的值:\n")
print(median_surv$strata)

# 检查是否包含映射标签
expected_labels <- c("Group Alpha", "Group Beta")
if (all(median_surv$strata %in% expected_labels)) {
  cat("✅ 标签映射正确应用：strata使用映射后的标签\n")
} else {
  cat("❌ 标签映射未正确应用：strata =", median_surv$strata, "\n")
}

# 同时检查原始拟合（未映射）的strata
fit_original <- surv_fit(Surv(data$time, data$status) ~ grp, data = data)
median_orig <- surv_median(fit_original)
cat("\n原始拟合（未映射）的中位生存strata:\n")
print(median_orig$strata)

# 测试HR统计量的标签映射函数
map_label <- function(x, labels) {
  if (x %in% names(labels) && labels[[x]] != "") {
    return(labels[[x]])
  }
  if (grepl("=", x)) {
    extracted <- sub(".*=", "", x)
    if (extracted %in% names(labels) && labels[[extracted]] != "") {
      return(labels[[extracted]])
    }
  }
  return(x)
}

cat("\n测试HR标签映射函数:\n")
test_cases <- c("A", "B", "grp=A", "grp=B")
for (tc in test_cases) {
  mapped <- map_label(tc, labels)
  cat(sprintf("  %s -> %s\n", tc, mapped))
}

cat("\n测试完成。\n")