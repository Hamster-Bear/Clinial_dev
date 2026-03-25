library(shiny)
library(dplyr)

source("modules/common/table_export.R")
source("modules/common/analysis_format.R")
source("modules/statistical_analysis/logistic.R")

clean_indent <- function(x) {
  trimws(gsub("\u00A0", "", as.character(x), fixed = TRUE))
}

must_one <- function(df, idx, msg) {
  out <- df[idx, , drop = FALSE]
  if (nrow(out) != 1) stop(msg)
  out[1, , drop = FALSE]
}

d <- read.csv("test/medical_test_data.csv", stringsAsFactors = FALSE)

res <- perform_logistic_analysis(
  data = d,
  logistic_response = "event",
  logistic_predictors = c("gender"),
  logistic_strata = "None",
  logistic_facet = "None",
  logistic_event_value = "1",
  logistic_model_strata = "None",
  logistic_reference_map = c(gender = "Female")
)

raw_tbl <- res$table[["_data"]]
front_tbl <- extract_table_dataframe(res$table)
front_render_tbl <- extract_table_dataframe(apply_sci_gt_style(res$table, title = "t", footnotes = NULL))

df_fit <- d
df_fit$event <- ifelse(as.character(df_fit$event) == "1", 1, 0)
df_fit$gender <- factor(as.character(df_fit$gender), levels = c("Female", "Male"))
fit <- glm(event ~ gender, data = df_fit, family = binomial())
coef_tbl <- summary(fit)$coefficients
beta <- as.numeric(coef_tbl["genderMale", "Estimate"])
se <- as.numeric(coef_tbl["genderMale", "Std. Error"])
pval <- as.numeric(coef_tbl["genderMale", "Pr(>|z|)"])

expected_stat <- format_regression_stat(exp(beta), exp(beta - 1.96 * se), exp(beta + 1.96 * se))
expected_p <- format_p_value_regression(pval)
expected_n <- as.character(sum(df_fit$gender == "Male", na.rm = TRUE))

row_male_raw <- must_one(
  raw_tbl,
  clean_indent(raw_tbl$预测变量) == "Male",
  "raw表未唯一定位到 Male 行"
)
row_ref_raw <- must_one(
  raw_tbl,
  grepl("Reference", raw_tbl$统计值, fixed = TRUE) & clean_indent(raw_tbl$预测变量) == "Female (Reference)",
  "raw表未唯一定位到 Female 参考组行"
)

if (!startsWith(as.character(row_male_raw$预测变量), "\u00A0\u00A0\u00A0\u00A0")) {
  stop("缩进逻辑异常：Male 行未保留四个不间断空格缩进")
}
if (as.character(row_male_raw$统计值) != expected_stat) {
  stop(paste0("统计值不一致：raw=", as.character(row_male_raw$统计值), " expected=", expected_stat))
}
if (as.character(row_male_raw$P值) != expected_p) {
  stop(paste0("P值不一致：raw=", as.character(row_male_raw$P值), " expected=", expected_p))
}
if (as.character(row_male_raw$N) != expected_n) {
  stop(paste0("N不一致：raw=", as.character(row_male_raw$N), " expected=", expected_n))
}
if (as.character(row_ref_raw$统计值) != "Reference") {
  stop("参考组统计值异常")
}

row_male_front <- must_one(
  front_tbl,
  clean_indent(front_tbl$预测变量) == "Male",
  "前端表未唯一定位到 Male 行"
)
if (as.character(row_male_front$`OR (95% CI)`) != expected_stat) {
  stop(paste0("前端统计值不一致：front=", as.character(row_male_front$`OR (95% CI)`), " expected=", expected_stat))
}
if (as.character(row_male_front$P值) != expected_p) {
  stop(paste0("前端P值不一致：front=", as.character(row_male_front$P值), " expected=", expected_p))
}

row_male_front_render <- must_one(
  front_render_tbl,
  clean_indent(front_render_tbl$预测变量) == "Male",
  "前端渲染表未唯一定位到 Male 行"
)
if (as.character(row_male_front_render$`OR (95% CI)`) != expected_stat) {
  stop(paste0("前端渲染统计值不一致：front=", as.character(row_male_front_render$`OR (95% CI)`), " expected=", expected_stat))
}
if (as.character(row_male_front_render$P值) != expected_p) {
  stop(paste0("前端渲染P值不一致：front=", as.character(row_male_front_render$P值), " expected=", expected_p))
}

cat("[PASS] medical CSV Logistic 全链路一致性通过\n")
cat("[PASS] OR/95CI/P 与直接glm一致\n")
cat("[PASS] 缩进与参考组显示未影响前端取值\n")
