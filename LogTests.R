folder <- "path/to/your/data/"
if (file.exists("config_local.R")) source("config_local.R")

bt <- read.csv(paste0(folder, "Backtest_AllLines.csv"))
bt$AccidentYear <- as.character(bt$AccidentYear)

# 1. Log error: log(Projected / Actual)
#    Positive = over-projection, negative = under-projection, symmetric in both directions
bt <- subset(bt, AccidentYear != "1998" & Projected > 0 & Actual > 0)   # 1998 is always 0; logs need positive values
bt$LogError    <- log(bt$Projected / bt$Actual)
bt$AbsLogError <- abs(bt$LogError)

# 2. One t-test and one Wilcoxon signed-rank test per line and accident year
combos <- unique(bt[, c("Line", "AccidentYear")])

lt <- do.call(rbind, lapply(seq_len(nrow(combos)), function(i) {
  ln <- combos$Line[i]; ay <- combos$AccidentYear[i]
  x  <- bt$LogError[bt$Line == ln & bt$AccidentYear == ay]
  x  <- x[is.finite(x)]
  
  if (length(x) < 3 || sd(x) == 0) {
    return(data.frame(Line = ln, AccidentYear = ay, N = length(x),
                      MeanLogErr = NA, MedianLogErr = NA, MedianAbsLogErr = NA,
                      Pct_Bias = NA, Pct_low = NA, Pct_high = NA,
                      p_t = NA, p_wilcox = NA))
  }
  
  tt <- t.test(x)
  wp <- suppressWarnings(wilcox.test(x)$p.value)
  
  data.frame(Line = ln, AccidentYear = ay, N = length(x),
             MeanLogErr      = round(mean(x), 4),
             MedianLogErr    = round(median(x), 4),
             MedianAbsLogErr = round(median(abs(x)), 4),
             # back-transform to a percent: exp(mean log error) - 1
             Pct_Bias = round(100 * (exp(mean(x)) - 1), 2),
             Pct_low  = round(100 * (exp(tt$conf.int[1]) - 1), 2),
             Pct_high = round(100 * (exp(tt$conf.int[2]) - 1), 2),
             p_t = round(tt$p.value, 4),
             p_wilcox = round(wp, 4))
}))

# 3. Holm adjustment across all tests
lt$p_t_adj      <- round(p.adjust(lt$p_t, method = "holm"), 4)
lt$p_wilcox_adj <- round(p.adjust(lt$p_wilcox, method = "holm"), 4)

lt <- lt[order(lt$Line, lt$AccidentYear), ]
rownames(lt) <- NULL

# 2007 summary, most precise line first
t07 <- subset(lt, AccidentYear == "2007")
t07 <- t07[order(t07$MedianAbsLogErr), ]
rownames(t07) <- NULL
t07

write.csv(lt, paste0(folder, "TTest_LogError_ByLine.csv"), row.names = FALSE)

# 4. Kruskal-Wallis and pairwise Wilcoxon on absolute log error, 2007
d07 <- subset(bt, AccidentYear == "2007")

kruskal.test(AbsLogError ~ Line, data = d07)
pairwise.wilcox.test(d07$AbsLogError, d07$Line, p.adjust.method = "holm")

# 5. Optional: Kruskal-Wallis for every accident year (is the pattern stable?)
for (ay in sort(unique(bt$AccidentYear))) {
  d <- subset(bt, AccidentYear == ay)
  kw <- kruskal.test(AbsLogError ~ Line, data = d)
  cat(ay, ": chi-sq =", round(kw$statistic, 1), ", p =", signif(kw$p.value, 3), "\n")
}