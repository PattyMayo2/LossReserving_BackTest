combos <- unique(all_backtests[, c("Line", "AccidentYear")])

ttest_results <- do.call(rbind, lapply(seq_len(nrow(combos)), function(i) {
  ln <- combos$Line[i]
  ay <- combos$AccidentYear[i]
  x  <- all_backtests$ErrorPct[all_backtests$Line == ln &
                                 all_backtests$AccidentYear == ay]
  x  <- x[!is.na(x) & is.finite(x)]
  
  if (length(x) < 3 || sd(x) == 0) {
    return(data.frame(Line = ln, AccidentYear = ay, N = length(x),
                      AvgPctError = round(mean(x), 2),
                      AvgAbsPctError = round(mean(abs(x)), 2),
                      MedianPctError = round(median(x), 2),
                      t = NA, p = NA, CI_low = NA, CI_high = NA))
  }
  
  tt <- t.test(x)
  data.frame(Line = ln, AccidentYear = ay, N = length(x),
             AvgPctError    = round(mean(x), 2),
             AvgAbsPctError = round(mean(abs(x)), 2),
             MedianPctError = round(median(x), 2),
             t = round(unname(tt$statistic), 2),
             p = round(tt$p.value, 3),
             CI_low  = round(tt$conf.int[1], 2),
             CI_high = round(tt$conf.int[2], 2))
}))

ttest_results <- ttest_results[order(ttest_results$Line, ttest_results$AccidentYear), ]
ttest_results

subset(ttest_results, AccidentYear == "2007")

write.csv(ttest_results, paste0(folder, "TTest_ByLine.csv"), row.names = FALSE)
write.csv(ttest_results, paste0(folder, "TTest_ByLine.csv"), row.names = FALSE)