# 共享数据文件读取 I/O
# 收录跨模块复用的文件读取逻辑，供 database_manager 和 data_preparation 共用

library(readxl)
library(haven)
library(vroom)
library(dplyr)

SUPPORTED_FILE_EXTENSIONS <- c("csv", "xlsx", "xls", "sas7bdat", "sav", "dta", "por")

data_io_get_supported_extensions <- function() {
  SUPPORTED_FILE_EXTENSIONS
}

data_read_file <- function(file_path, csv_encoding = "UTF-8") {
  ext <- tolower(tools::file_ext(file_path))
  if (!ext %in% SUPPORTED_FILE_EXTENSIONS) {
    stop(paste0("不支持的文件格式: ", ext))
  }

  if (ext %in% c("xlsx", "xls")) {
    data <- readxl::read_excel(file_path)
  } else if (ext == "csv") {
    if (csv_encoding == "GBK") {
      data <- vroom::vroom(file_path, progress = FALSE,
                           locale = readr::locale(encoding = "GBK"))
    } else {
      data <- vroom::vroom(file_path, progress = FALSE)
    }
  } else if (ext == "sas7bdat") {
    data <- haven::read_sas(file_path, encoding = "UTF-8")
  } else if (ext == "sav") {
    data <- haven::read_sav(file_path, encoding = "UTF-8")
  } else if (ext == "por") {
    data <- haven::read_por(file_path, encoding = "UTF-8")
  } else if (ext == "dta") {
    data <- haven::read_dta(file_path, encoding = "UTF-8")
  } else {
    stop(paste0("不支持的文件格式: ", ext))
  }

  data <- dplyr::mutate(data, dplyr::across(
    dplyr::where(haven::is.labelled),
    ~ haven::as_factor(.x, levels = "labels")
  ))

  return(data)
}
