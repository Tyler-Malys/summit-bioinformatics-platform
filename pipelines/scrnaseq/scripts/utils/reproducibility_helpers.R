initialize_pipeline_seed <- function(default_seed = 12345) {
  seed_raw <- Sys.getenv("PIPELINE_SEED", unset = as.character(default_seed))

  seed <- suppressWarnings(as.integer(seed_raw))
  if (is.na(seed)) {
    warning(sprintf("Invalid PIPELINE_SEED value '%s'; falling back to %d", seed_raw, default_seed))
    seed <- as.integer(default_seed)
  }

  set.seed(seed)

  return(seed)
}

write_stage_session_info <- function(stage_name) {
  r_sessions_dir <- Sys.getenv("R_SESSIONS_DIR", unset = "")
  run_metadata_dir <- Sys.getenv("RUN_METADATA_DIR", unset = "")

  if (!nzchar(r_sessions_dir) && nzchar(run_metadata_dir)) {
    r_sessions_dir <- file.path(run_metadata_dir, "r_sessions")
  }

  if (!nzchar(r_sessions_dir)) {
    r_sessions_dir <- file.path(getwd(), "run_metadata", "r_sessions")
  }

  dir.create(r_sessions_dir, recursive = TRUE, showWarnings = FALSE)

  out_file <- file.path(r_sessions_dir, paste0(stage_name, "_sessionInfo.txt"))

  cat(
    sprintf("stage_name: %s\n", stage_name),
    sprintf("timestamp: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    file = out_file
  )

  capture.output(
    sessionInfo(),
    file = out_file,
    append = TRUE
  )

  invisible(out_file)
}
