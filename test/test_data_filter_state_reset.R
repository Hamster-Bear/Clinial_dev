library(shiny)
library(testthat)

source("modules/common/data_filter.R")

df1 <- read.csv("test/medical_test_data.csv", stringsAsFactors = FALSE)
df2 <- df1
df2$gender <- ifelse(seq_len(nrow(df2)) <= 10, "Male", "Female")

rv <- reactiveVal(df1)

testServer(data_filter_server, args = list(data = reactive(rv())), {
  filtered <- session$returned
  session$setInputs(selected_var = c("gender"))
  session$setInputs(cat_values_gender = c("Female"))
  session$setInputs(apply_filters = 1)
  expect_equal(nrow(filtered()), sum(df1$gender == "Female"))

  rv(df2)
  session$flushReact()
  expect_equal(nrow(filtered()), nrow(df2))
})

cat("[PASS] data_filter 在数据变化后会清空旧筛选状态\n")
