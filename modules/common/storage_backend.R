storage_backend_get <- function() {
  backend <- tolower(trimws(Sys.getenv("STORAGE_BACKEND", "local")))
  if (!(backend %in% c("local", "s3"))) {
    backend <- "local"
  }
  backend
}

storage_s3_bucket_get <- function() {
  trimws(Sys.getenv("STORAGE_S3_BUCKET", ""))
}

storage_data_key_build <- function(workspace_id, folder_id, dataset_id) {
  folder_seg <- if (is.null(folder_id) || !nzchar(folder_id)) "root" else folder_id
  paste(workspace_id, folder_seg, paste0(dataset_id, ".rds"), sep = "/")
}

storage_s3_ensure <- function() {
  bucket <- storage_s3_bucket_get()
  if (!nzchar(bucket)) {
    stop("对象存储模式需要设置 STORAGE_S3_BUCKET")
  }
  if (!requireNamespace("aws.s3", quietly = TRUE)) {
    stop("对象存储模式需要安装 aws.s3 包")
  }
  bucket
}

storage_save_dataset <- function(data, workspace_id, folder_id, dataset_id, storage_root) {
  backend <- storage_backend_get()
  if (backend == "s3") {
    bucket <- storage_s3_ensure()
    key <- storage_data_key_build(workspace_id, folder_id, dataset_id)
    tmp_file <- tempfile(fileext = ".rds")
    saveRDS(as.data.frame(data), tmp_file)
    ok <- aws.s3::put_object(file = tmp_file, object = key, bucket = bucket)
    unlink(tmp_file, force = TRUE)
    if (!isTRUE(ok)) {
      stop("对象存储上传失败")
    }
    return(paste0("s3://", bucket, "/", key))
  }
  target_dir <- file.path(storage_root, workspace_id)
  if (!is.null(folder_id) && nzchar(folder_id)) {
    target_dir <- file.path(target_dir, folder_id)
  }
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  data_file <- file.path(target_dir, paste0(dataset_id, ".rds"))
  saveRDS(as.data.frame(data), data_file)
  data_file
}

storage_load_dataset <- function(data_path) {
  if (grepl("^s3://", data_path)) {
    bucket <- storage_s3_ensure()
    no_prefix <- sub("^s3://", "", data_path)
    split_pos <- regexpr("/", no_prefix, fixed = TRUE)
    if (split_pos <= 0) {
      stop("无效的S3路径")
    }
    path_bucket <- substr(no_prefix, 1, split_pos - 1)
    key <- substr(no_prefix, split_pos + 1, nchar(no_prefix))
    if (nzchar(path_bucket) && path_bucket != bucket) {
      bucket <- path_bucket
    }
    tmp_file <- tempfile(fileext = ".rds")
    ok <- aws.s3::save_object(object = key, bucket = bucket, file = tmp_file)
    if (!isTRUE(ok) || !file.exists(tmp_file)) {
      unlink(tmp_file, force = TRUE)
      stop("对象存储下载失败")
    }
    data <- readRDS(tmp_file)
    unlink(tmp_file, force = TRUE)
    return(data)
  }
  readRDS(data_path)
}

storage_delete_dataset <- function(data_path) {
  if (!nzchar(data_path)) {
    return(invisible(FALSE))
  }
  if (grepl("^s3://", data_path)) {
    bucket <- storage_s3_ensure()
    no_prefix <- sub("^s3://", "", data_path)
    split_pos <- regexpr("/", no_prefix, fixed = TRUE)
    if (split_pos <= 0) {
      return(invisible(FALSE))
    }
    path_bucket <- substr(no_prefix, 1, split_pos - 1)
    key <- substr(no_prefix, split_pos + 1, nchar(no_prefix))
    if (nzchar(path_bucket) && path_bucket != bucket) {
      bucket <- path_bucket
    }
    aws.s3::delete_object(object = key, bucket = bucket)
    return(invisible(TRUE))
  }
  if (file.exists(data_path)) {
    file.remove(data_path)
    return(invisible(TRUE))
  }
  invisible(FALSE)
}
