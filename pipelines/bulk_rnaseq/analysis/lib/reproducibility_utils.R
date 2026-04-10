#!/usr/bin/env Rscript

initialize_pipeline_seed <- function(default_seed = 12345L) {
  seed_txt <- Sys.getenv("PIPELINE_SEED", unset = "")
  seed_val <- suppressWarnings(as.integer(seed_txt))

  if (is.na(seed_val)) {
    seed_val <- as.integer(default_seed)
  }

  set.seed(seed_val)
  seed_val
}

write_stage_session_info <- function(stage_name) {
  run_dir <- Sys.getenv("RUN_DIR", unset = "")
  r_sessions_dir <- Sys.getenv("R_SESSIONS_DIR", unset = "")
  pipeline_seed <- Sys.getenv("PIPELINE_SEED", unset = "")

  if (!nzchar(run_dir) || !nzchar(r_sessions_dir)) {
    message("RUN_DIR or R_SESSIONS_DIR not set; skipping sessionInfo capture")
    return(invisible(NULL))
  }

  dir.create(r_sessions_dir, recursive = TRUE, showWarnings = FALSE)

  out_file <- file.path(
    r_sessions_dir,
    paste0(stage_name, "_sessionInfo.txt")
  )

  lines <- c(
    paste0("timestamp=", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("stage_name=", stage_name),
    paste0("run_dir=", run_dir),
    paste0("pipeline_seed=", pipeline_seed),
    ""
  )

  writeLines(lines, con = out_file)
  utils::capture.output(sessionInfo(), file = out_file, append = TRUE)

  invisible(out_file)
}
