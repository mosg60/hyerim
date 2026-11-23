# rcbd_analysis.R: one-factor or two-factor field trial in randomized complete blocks.
# ANOVA, assumption checks, mean separation with letters, CV, a figure and a Word table.
#
# Usage:
#   Rscript rcbd_analysis.R <data.csv|data.xlsx> <response> <treatment> <block> [factor2] [out_dir] [test]
#     test: lsd (default), duncan or tukey
# Example:
#   Rscript rcbd_analysis.R yield.csv yield cultivar rep "" results duncan
#
# Columns are taken by name. Korean column names and values work; CSV files saved by Korean
# Excel are usually CP949, which is tried when UTF-8 fails.

suppressPackageStartupMessages({
  library(agricolae)
  library(ggplot2)
  library(car)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("usage: rcbd_analysis.R <data> <response> <treatment> <block> [factor2] [out_dir] [test]")
path <- args[1]; resp <- args[2]; trt <- args[3]; blk <- args[4]
f2 <- if (length(args) >= 5 && nzchar(args[5])) args[5] else NA
out <- if (length(args) >= 6 && nzchar(args[6])) args[6] else "results"
test <- if (length(args) >= 7) tolower(args[7]) else "lsd"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

read_any <- function(p) {
  if (grepl("\\.xlsx?$", p, ignore.case = TRUE)) {
    if (!requireNamespace("readxl", quietly = TRUE)) stop("install.packages('readxl') to read Excel files")
    return(as.data.frame(readxl::read_excel(p)))
  }
  d <- tryCatch(read.csv(p, fileEncoding = "UTF-8-BOM", check.names = FALSE), error = function(e) NULL, warning = function(w) NULL)
  if (is.null(d)) d <- read.csv(p, fileEncoding = "CP949", check.names = FALSE)
  d
}

d <- read_any(path)
need <- c(resp, trt, blk, if (!is.na(f2)) f2)
miss <- setdiff(need, names(d))
if (length(miss)) stop("columns not found: ", paste(miss, collapse = ", "), "\ncolumns in the file: ", paste(names(d), collapse = ", "))
d[[trt]] <- factor(d[[trt]], levels = unique(d[[trt]]))
d[[blk]] <- factor(d[[blk]])
if (!is.na(f2)) d[[f2]] <- factor(d[[f2]], levels = unique(d[[f2]]))
d[[resp]] <- as.numeric(d[[resp]])
n_na <- sum(is.na(d[[resp]]))
d <- d[!is.na(d[[resp]]), ]

bt <- function(x) paste0("`", x, "`")
rhs <- if (is.na(f2)) paste(bt(blk), "+", bt(trt)) else paste(bt(blk), "+", bt(trt), "*", bt(f2))
fit <- aov(as.formula(paste(bt(resp), "~", rhs)), data = d)

sink(file.path(out, "report.txt"), split = TRUE)
cat("Response:", resp, " Treatment:", trt, if (!is.na(f2)) paste(" Factor 2:", f2), " Block:", blk, "\n")
cat("Observations used:", nrow(d), if (n_na) paste0(" (", n_na, " missing values dropped)"), "\n\n")
cat("== ANOVA (RCBD) ==\n"); print(summary(fit))
cv <- cv.model(fit)
cat(sprintf("\nCV = %.1f%%\n", cv))

cat("\n== Assumptions ==\n")
sw <- shapiro.test(residuals(fit))
cat(sprintf("Shapiro-Wilk on residuals: W = %.3f, p = %.3f  (%s)\n", sw$statistic, sw$p.value,
            ifelse(sw$p.value < 0.05, "residuals depart from normal: look at the Q-Q plot, consider a transformation", "no evidence against normality")))
grp <- if (is.na(f2)) d[[trt]] else interaction(d[[trt]], d[[f2]])
lv <- car::leveneTest(d[[resp]] ~ grp)
cat(sprintf("Levene (median): F = %.2f, p = %.3f  (%s)\n", lv[1, "F value"], lv[1, "Pr(>F)"],
            ifelse(lv[1, "Pr(>F)"] < 0.05, "variances differ between groups", "no evidence of unequal variances")))
png(file.path(out, "residual_check.png"), width = 1600, height = 800, res = 200)
par(mfrow = c(1, 2)); plot(fit, which = 1); plot(fit, which = 2)
invisible(dev.off())

cat("\n== Mean separation (", toupper(test), ", alpha = 0.05) ==\n", sep = "")
sep <- function(term) {
  switch(test,
    duncan = duncan.test(fit, term, alpha = 0.05, group = TRUE),
    tukey  = HSD.test(fit, term, alpha = 0.05, group = TRUE),
    LSD.test(fit, term, alpha = 0.05, p.adj = "none", group = TRUE))
}
term <- if (is.na(f2)) trt else c(trt, f2)
ms <- sep(term)
g <- ms$groups; g$level <- rownames(g)
st <- ms$means; st$level <- rownames(st)
tab <- merge(st[, c("level", resp, "std", "r")], g[, c("level", "groups")], by = "level")
names(tab) <- c("level", "mean", "sd", "n", "letter")
tab$se <- tab$sd / sqrt(tab$n)
tab <- tab[order(-tab$mean), c("level", "n", "mean", "sd", "se", "letter")]
print(tab, row.names = FALSE, digits = 4)
cat("\nMeans with the same letter are not significantly different at p < 0.05.\n")
if (!is.na(f2)) {
  p_int <- summary(fit)[[1]][paste0(trt, ":", f2), "Pr(>F)"]
  cat(sprintf("\nInteraction %s x %s: p = %.3f. %s\n", trt, f2, p_int,
              ifelse(p_int < 0.05,
                     "Significant: report the combination means above (or each factor within the other).",
                     "Not significant: report the main effects below rather than the combinations.")))
  for (m in c(trt, f2)) {
    cat("\n-- Main effect:", m, "--\n")
    mm <- sep(m); gm <- mm$groups
    print(data.frame(level = rownames(gm), mean = round(gm[[1]], 2), letter = gm$groups), row.names = FALSE)
  }
}
sink()

write.csv(tab, file.path(out, "means_letters.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# figure: mean +- SE with letters, 300 dpi
tab$level <- factor(tab$level, levels = tab$level[order(match(tab$level, if (is.na(f2)) levels(d[[trt]]) else tab$level))])
p <- ggplot(tab, aes(level, mean)) +
  geom_col(width = 0.6, fill = "grey70", colour = "grey20") +
  geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.2) +
  geom_text(aes(y = mean + se, label = letter), vjust = -0.6, size = 4) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = trt, y = resp) +
  theme_classic(base_size = 12) +
  theme(axis.text.x = element_text(angle = if (nrow(tab) > 6) 45 else 0, hjust = if (nrow(tab) > 6) 1 else 0.5))
ggsave(file.path(out, "means_plot.png"), p, width = 6, height = 4, dpi = 300)

if (requireNamespace("flextable", quietly = TRUE) && requireNamespace("officer", quietly = TRUE)) {
  ft <- flextable::flextable(transform(tab, mean = sprintf("%.2f %s", mean, letter), sd = round(sd, 2), se = round(se, 2))[, c("level", "n", "mean", "sd", "se")])
  ft <- flextable::set_header_labels(ft, level = trt, mean = paste0("Mean (", toupper(test), ")"), sd = "SD", se = "SE")
  ft <- flextable::autofit(ft)
  flextable::save_as_docx(ft, path = file.path(out, "means_table.docx"))
}
cat("\nWrote:", paste(list.files(out), collapse = ", "), "in", out, "\n")
