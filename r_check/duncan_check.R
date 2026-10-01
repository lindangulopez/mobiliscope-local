# Recompute the Duncan segregation index (IS) from the Mobiliscope open data
# and compare it with the values published in segreg/<indicator>_Duncan.csv.
#
# Usage:  Rscript duncan_check.R [city] [path_to_opendata]
# Data:   Zenodo, doi:10.5281/zenodo.11111161 (ODbL), unzipped.
#
# The pipeline (data-process/prepa_bdnum/step3/p2m_fct.R) uses OasisR::ISDuncan
# on the number of people present per sector and hour. The same index is
# written out here by hand, so that the check does not depend on OasisR:
#   IS_k = 1/2 * sum_i | x_ik / X_k  -  (t_i - x_ik) / (T - X_k) |
# with x_ik the people of group k present in sector i, t_i all people present
# in sector i, X_k and T the totals over the region, for one hour.

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr) })

args <- commandArgs(trailingOnly = TRUE)
city <- if (length(args) >= 1) args[1] else "rennes"
root <- if (length(args) >= 2) args[2] else "../zenodo/opendata/20230706_opendata"
dir_city <- file.path(root, city)
stopifnot(dir.exists(dir_city))

is_duncan <- function(x) {            # x: matrix sectors x groups, one hour
  t_i <- rowSums(x); T <- sum(t_i)
  sapply(seq_len(ncol(x)), function(k) {
    X_k <- sum(x[, k])
    0.5 * sum(abs(x[, k] / X_k - (t_i - x[, k]) / (T - X_k)))
  }) |> setNames(colnames(x))
}

check_indicator <- function(ind) {
  stock <- read_csv(file.path(dir_city, "stacked", paste0(ind, "_prop_stacked.csv")),
                    col_types = cols(district = col_character(), hour = col_character(),
                                     .default = col_double()))
  pub <- read_csv(file.path(dir_city, "segreg", paste0(ind, "_Duncan.csv")),
                  col_types = cols(hour = col_character(), .default = col_double()))
  groups <- setdiff(names(stock), c("district", "hour"))
  mine <- stock |>
    group_by(hour) |>
    group_modify(~ as.data.frame(t(is_duncan(as.matrix(.x[, groups]))))) |>
    ungroup() |>
    pivot_longer(-hour, names_to = "group", values_to = "recomputed")
  pub |>
    pivot_longer(-hour, names_to = "group", values_to = "published") |>
    inner_join(mine, by = c("hour", "group")) |>
    mutate(indicator = ind, diff = recomputed - published)
}

inds <- sub("_Duncan\\.csv$", "", list.files(file.path(dir_city, "segreg"), "_Duncan\\.csv$"))
res <- bind_rows(lapply(inds, function(i)
  tryCatch(check_indicator(i), error = function(e) {
    message("skipped ", i, ": ", conditionMessage(e)); NULL })))

summary <- res |>
  group_by(indicator) |>
  summarise(values = n(),
            max_abs_diff = max(abs(diff), na.rm = TRUE),
            within_rounding = all(abs(diff) <= 5e-5 + 1e-9, na.rm = TRUE),
            .groups = "drop")

cat("City:", city, "\n")
print(as.data.frame(summary), row.names = FALSE)
cat("\nExample, indicator 'sex', first hours:\n")
print(as.data.frame(res |> filter(indicator == "sex", group == "sex1") |> head(6) |>
                      mutate(recomputed = round(recomputed, 4))), row.names = FALSE)
write_csv(res, paste0("duncan_check_", city, ".csv"))
