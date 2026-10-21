library(ggplot2)

folder <- "path/to/your/data/"
if (file.exists("config_local.R")) source("config_local.R")

figdir <- "figures/"
dir.create(figdir, showWarnings = FALSE)

# ---- Load and prepare -------------------------------------------------------
bt <- read.csv(paste0(folder, "Backtest_Methods.csv"))
bt$AccidentYear <- as.character(bt$AccidentYear)

# 1998 is fully observed (error always 0); logs need positive values
d <- subset(bt, AccidentYear != "1998" & Projected > 0 & Actual > 0)
d$LogError    <- log(d$Projected / d$Actual)
d$AbsLogError <- abs(d$LogError)

# Keep only company-years that have every method, so comparisons are paired
n_methods <- length(unique(d$Method))
key  <- paste(d$Line, d$Company, d$AccidentYear)
keep <- names(which(table(key) == n_methods))
d    <- d[key %in% keep, ]

method_levels <- c("ChainLadder", "CapeCod", "BF", "BF_AllYears")
d$Method <- factor(d$Method, levels = intersect(method_levels, unique(d$Method)))

years <- c("2005", "2006", "2007")
dy    <- subset(d, AccidentYear %in% years)

# ---- 1. Descriptive table: typical miss and bias by line, method, year ------
desc <- aggregate(cbind(AbsLogError, LogError) ~ Line + Method + AccidentYear,
                  data = dy, FUN = median)
names(desc)[4:5] <- c("MedianAbsLogErr", "MedianLogErr")
nn <- aggregate(Company ~ Line + Method + AccidentYear, data = dy,
                FUN = function(x) length(unique(x)))
names(nn)[4] <- "N"
desc <- merge(desc, nn)
desc$TypicalMissPct <- round(100 * (exp(desc$MedianAbsLogErr) - 1), 1)
desc <- desc[order(desc$AccidentYear, desc$Line, desc$Method), ]
desc$MedianAbsLogErr <- round(desc$MedianAbsLogErr, 4)
desc$MedianLogErr    <- round(desc$MedianLogErr, 4)
rownames(desc) <- NULL
desc

# ---- 2. Paired tests: each method vs chain ladder, by company ---------------
cl  <- d[d$Method == "ChainLadder", c("Line", "Company", "AccidentYear", "AbsLogError")]
names(cl)[4] <- "AbsCL"
oth <- d[d$Method != "ChainLadder", ]
paired <- merge(oth, cl, by = c("Line", "Company", "AccidentYear"))
paired$Diff <- paired$AbsLogError - paired$AbsCL     # negative = method beats chain ladder
paired <- subset(paired, AccidentYear %in% years)
paired$Method <- droplevels(paired$Method)

groups <- split(paired, list(paired$Line, paired$Method, paired$AccidentYear), drop = TRUE)

tests <- do.call(rbind, lapply(groups, function(x) {
  n <- nrow(x)
  p <- NA
  if (n >= 10 && any(x$Diff != 0)) {
    p <- suppressWarnings(wilcox.test(x$Diff, mu = 0)$p.value)
  }
  data.frame(Line = x$Line[1], Method = as.character(x$Method[1]),
             AccidentYear = x$AccidentYear[1], N = n,
             MedianDiff = round(median(x$Diff), 4),
             PctCompaniesBetter = round(100 * mean(x$Diff < 0), 1),
             p = round(p, 4))
}))
rownames(tests) <- NULL

# Holm adjustment across all tests that were run
tests$p_adj <- round(p.adjust(tests$p, method = "holm"), 4)
tests$Note  <- ifelse(tests$N < 10, "N < 10: descriptive only", "")
tests <- tests[order(tests$AccidentYear, tests$Line, tests$Method), ]
tests

write.csv(desc,  paste0(folder, "MethodComparison_Descriptive.csv"), row.names = FALSE)
write.csv(tests, paste0(folder, "MethodComparison_PairedTests.csv"), row.names = FALSE)

# ---- 3. Plots ---------------------------------------------------------------
d07 <- subset(desc, AccidentYear == "2007")
n07 <- unique(d07[, c("Line", "N")])
lab <- setNames(paste0(n07$Line, " (n=", n07$N, ")"), n07$Line)

# Plot A: typical miss by method and line, 2007
pA <- ggplot(d07, aes(x = Line, y = MedianAbsLogErr, fill = Method)) +
  geom_col(position = "dodge") +
  scale_x_discrete(labels = lab) +
  labs(x = NULL, y = "Median absolute log error (smaller is better)",
       title = "Typical projection error by method, accident year 2007",
       subtitle = "Same companies for every method; log-error basis") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(paste0(figdir, "6_method_error_2007.png"), pA, width = 9, height = 5.5, dpi = 300)

# Plot B: paired differences vs chain ladder, 2007
p07 <- subset(paired, AccidentYear == "2007")
pB <- ggplot(p07, aes(x = Line, y = Diff, fill = Method)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_boxplot(outlier.shape = NA, position = position_dodge(width = 0.8)) +
  scale_x_discrete(labels = lab) +
  coord_cartesian(ylim = c(-0.6, 0.6)) +
  labs(x = NULL,
       y = "Method error minus chain ladder error (|log error|)",
       title = "Does the method beat chain ladder? Paired differences, 2007",
       subtitle = "Below 0 = method more accurate than chain ladder. Y-axis trimmed to -0.6 to 0.6") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(paste0(figdir, "7_paired_differences_2007.png"), pB, width = 9, height = 5.5, dpi = 300)

# Plot C: typical miss across 2005 to 2007, one panel per line
pC <- ggplot(desc, aes(x = AccidentYear, y = MedianAbsLogErr, color = Method, group = Method)) +
  geom_line(linewidth = 0.9) + geom_point() +
  facet_wrap(~ Line, scales = "free_y") +
  labs(x = "Accident year", y = "Median absolute log error",
       title = "Method comparison across accident years 2005 to 2007") +
  theme_minimal(base_size = 11)
ggsave(paste0(figdir, "8_methods_by_year.png"), pC, width = 10, height = 6.5, dpi = 300)

pA; pB; pC