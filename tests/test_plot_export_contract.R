library(testthat)

source(file.path("..", "modules", "common", "plot_export.R"))

test_that("save_plot_export 允许超过 ggsave 默认 50 英寸限制的导出", {
  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  out_file <- tempfile(fileext = ".pdf")
  expect_no_error(
    save_plot_export(
      file = out_file,
      plot_obj = p,
      format = "pdf",
      width = 60,
      height = 55,
      dpi = 72
    )
  )
  expect_true(file.exists(out_file))
  unlink(out_file)
})
