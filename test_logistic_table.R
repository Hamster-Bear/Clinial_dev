source('modules/common/analysis_shared.R')
source('modules/statistical_analysis/logistic.R')

data <- mtcars
data$am_factor <- factor(data$am, levels = c(0, 1), labels = c("Auto", "Manual"))
data$cyl_factor <- factor(data$cyl)
data$vs <- as.numeric(data$vs)

res <- perform_logistic_analysis(
  data = data,
  logistic_response = "vs",
  logistic_predictors = c("mpg", "am_factor", "cyl_factor")
)

print(res$table)
