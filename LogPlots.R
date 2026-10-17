library(ggplot2)
library(scales)   # for squish(); installed with ggplot2

folder <- "path/to/your/data/"
if (file.exists("config_local.R")) source("config_local.R")
figdir <- "figures/"
dir.create(figdir, showWarnings = FALSE)

# ---- Load data -------------------------------------------------------------
bt <- read.csv(paste0(folder, "Backtest_AllLines.csv"))
bt$AccidentYear <- as.character(bt$AccidentYear)
bt <- subset(bt, AccidentYear != "1998" & Projected > 0 & Actual > 0)
bt$LogError    <- log(bt$Projected / bt$Actual)
bt$AbsLogError <- abs(bt$LogError)

lt <- read.csv(paste0(folder, "TTest_LogError_ByLine.csv"))
lt$AccidentYear <- as.character(lt$AccidentYear)

# Order lines from most to least precise in 2007, so every plot uses the same order
ord <- lt$Line[lt$AccidentYear == "2007"][order(lt$MedianAbsLogErr[lt$AccidentYear == "2007"])]
bt$Line <- factor(bt$Line, levels = ord)
lt$Line <- factor(lt$Line, levels = ord)

# Line labels that include the 2007 sample size, so small-N lines are visible
n07 <- lt[lt$AccidentYear == "2007", c("Line", "N")]
lab <- setNames(paste0(n07$Line, " (n=", n07$N, ")"), n07$Line)

d07 <- subset(bt, AccidentYear == "2007")
t07 <- subset(lt, AccidentYear == "2007")

# ---- 1. Typical error by accident year, one line per business line ----------
p1 <- ggplot(lt, aes(x = as.numeric(AccidentYear), y = MedianAbsLogErr,
                     color = Line, group = Line)) +
  geom_line(linewidth = 0.9) + geom_point() +
  scale_x_continuous(breaks = 1999:2007) +
  labs(x = "Accident year", y = "Median absolute log error",
       title = "Projection error grows toward the newest accident years",
       subtitle = "Median |log(projected / actual)| across companies",
       color = NULL) +
  theme_minimal(base_size = 12)
ggsave(paste0(figdir, "1_error_by_year.png"), p1, width = 8, height = 5, dpi = 300)

# ---- 2. Distribution of 2007 log error by line ------------------------------
p2 <- ggplot(d07, aes(x = Line, y = LogError)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(width = 0.15, alpha = 0.5, size = 1) +
  scale_x_discrete(labels = lab) +
  coord_cartesian(ylim = c(-1.5, 1.5)) +
  labs(x = NULL, y = "Log error (positive = over-projection)",
       title = "2007 projection error by line",
       subtitle = "Y-axis trimmed to -1.5 to 1.5; a few extreme points are cut off") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(paste0(figdir, "2_boxplot_2007.png"), p2, width = 8, height = 5.5, dpi = 300)

# ---- 3. Projected vs actual, log-log, 2007 ----------------------------------
p3 <- ggplot(d07, aes(x = Actual, y = Projected)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  geom_point(alpha = 0.6) +
  scale_x_log10(labels = comma) + scale_y_log10(labels = comma) +
  facet_wrap(~ Line, scales = "free", labeller = as_labeller(lab)) +
  labs(x = "Actual lag 10 paid loss (log scale)",
       y = "Projected lag 10 paid loss (log scale)",
       title = "Projected vs. actual, accident year 2007",
       subtitle = "Points on the dashed line are perfect projections") +
  theme_minimal(base_size = 11)
ggsave(paste0(figdir, "3_projected_vs_actual_2007.png"), p3, width = 10, height = 7, dpi = 300)

# ---- 4. 2007 bias with 95% confidence intervals -----------------------------
p4 <- ggplot(t07, aes(x = Pct_Bias, y = Line)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_errorbarh(aes(xmin = Pct_low, xmax = Pct_high), height = 0.2) +
  geom_point(size = 2.5) +
  scale_y_discrete(labels = lab, limits = rev) +
  labs(x = "Bias (%), geometric mean of projected / actual",
       y = NULL,
       title = "2007 bias by line, with 95% confidence intervals",
       subtitle = "Intervals that cross 0 show no detectable bias; wide intervals reflect small samples") +
  theme_minimal(base_size = 12)
ggsave(paste0(figdir, "4_bias_intervals_2007.png"), p4, width = 8, height = 4.5, dpi = 300)

# ---- 5. Heatmap: typical error by line and accident year --------------------
p5 <- ggplot(lt, aes(x = AccidentYear, y = Line, fill = MedianAbsLogErr)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", MedianAbsLogErr)), size = 3) +
  scale_fill_gradient(low = "white", high = "firebrick",
                      limits = c(0, 0.6), oob = squish,
                      name = "Median abs\nlog error") +
  scale_y_discrete(limits = rev) +
  labs(x = "Accident year", y = NULL,
       title = "Typical projection error by line and accident year",
       subtitle = "Colour scale capped at 0.6; darker cells are larger errors") +
  theme_minimal(base_size = 12)
ggsave(paste0(figdir, "5_heatmap.png"), p5, width = 9, height = 4.5, dpi = 300)

# Show them in RStudio too
p1; p2; p3; p4; p5