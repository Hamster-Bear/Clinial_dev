library(testthat)
library(shiny)
library(htmltools)

# 模拟加载依赖的UI模块
source(file.path("..", "modules", "statistical_graphics_ui", "common_ui_shell.R"))

context("Graphics Common UI Components")

test_that("graphics_reference_line_ui generates correct HTML structure", {
  # 模拟命名空间函数
  ns <- NS("test_module")
  
  # 调用UI生成函数
  ui_output <- graphics_reference_line_ui(
    ns = ns, 
    id_prefix = "ref_line", 
    label = "Test Line", 
    default_value = 15,
    default_color = "#123456",
    default_linetype = "dotted",
    default_linewidth = 1.5
  )
  
  # 将UI对象转换为HTML字符串进行断言
  html_str <- as.character(ui_output)
  
  # 验证核心控件是否存在并包含了正确的前缀和默认值
  expect_match(html_str, 'id="test_module-ref_line"')
  expect_match(html_str, 'value="15"')
  
  # 验证颜色控件
  expect_match(html_str, 'id="test_module-ref_line_color"')
  expect_match(html_str, 'value="#123456"')
  
  # 验证线型控件
  expect_match(html_str, 'id="test_module-ref_line_linetype"')
  expect_match(html_str, 'dotted')
  
  # 验证线宽控件
  expect_match(html_str, 'id="test_module-ref_line_linewidth"')
  expect_match(html_str, 'value="1.5"')
  
  # 验证Label传递
  expect_match(html_str, 'Test Line')
  expect_match(html_str, 'Test Line颜色')
  expect_match(html_str, 'Test Line线型')
  expect_match(html_str, 'Test Line线宽')
})