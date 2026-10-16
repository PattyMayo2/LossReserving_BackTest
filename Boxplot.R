bt <- subset(all_backtests, AccidentYear != "1998")

# Distribution of errors by line, 2007 only
boxplot(ErrorPct ~ Line, data = subset(bt, AccidentYear == "2007"),
        las = 2, ylab = "Percent error", main = "2007 projection error by line")
abline(h = 0, lty = 2)

# Mean absolute error over accident years, one line per business line
library(ggplot2)    # install.packages("ggplot2") once
ggplot(ttest_results[ttest_results$AccidentYear != "1998", ],
       aes(x = AccidentYear, y = AvgAbsPctError, group = Line, color = Line)) +
  geom_line() + geom_point() +
  labs(y = "Mean absolute % error", title = "Chain ladder error by line and accident year")