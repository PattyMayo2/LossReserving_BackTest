library(ChainLadder)
library(openxlsx)

# 1. Import
data <- read.csv("C:/Users/milan/Downloads/Cas Data/WorkComp.csv")

# 2. Keep only accident years 1997 to 2008
data <- data[data$AccidentYear >= 1997 & data$AccidentYear <= 2008, ]

# 3. Keep companies with all positive paid and incurred losses
good <- names(which(tapply(data$CumPaidLoss > 0 & data$IncurredLosses > 0,
                           data$GRNAME, all)))
clean <- data[data$GRNAME %in% good, ]

# 4. Drop the smallest 25% of companies by net earned premium
prem   <- tapply(clean$EarnedPremNet, clean$GRNAME, sum)
cutoff <- quantile(prem, 0.25)
good   <- sort(names(prem)[prem > cutoff])
clean  <- clean[clean$GRNAME %in% good, ]

# 5. Sheet names (max 31 chars, no illegal characters, unique)
sheet_names <- make.unique(substr(gsub("[:\\\\/?*\\[\\]]", "", good, perl = TRUE), 1, 31))

wb     <- createWorkbook()
yellow <- createStyle(fgFill = "yellow")
addWorksheet(wb, "Summary")
summary_rows <- list()
tri_list     <- list()
backtest_list <- list()  

# 6. Loop over companies
for (i in seq_along(good)) {
  g  <- good[i]
  sn <- sheet_names[i]
  co <- clean[clean$GRNAME == g, ]
  
  res <- tryCatch({
    tri_data <- co[co$DevelopmentYear <= max(co$AccidentYear), ]
    tri  <- as.triangle(tri_data, origin = "AccidentYear",
                        dev = "DevelopmentLag", value = "CumPaidLoss")
    cl   <- chainladder(tri)
    list(m = unclass(tri), full = unclass(predict(cl)))
  }, error = function(e) NULL)
  
  if (is.null(res)) { message("Skipped: ", g); next }
  
  m    <- res$m
  full <- res$full
  n    <- ncol(m)
  
  # Keep only full 10x10 triangles
  if (!all(dim(m) == c(10, 10))) { message("Skipped (not 10x10): ", g); next }
  
  latest   <- apply(m, 1, function(r) tail(r[!is.na(r)], 1))
  ultimate <- full[, n]
  reserve  <- ultimate - latest
  
  #Backtest against the acutal lag 10 values
  
  actual    <- tapply(co$CumPaidLoss[co$DevelopmentLag == 10],
                      co$AccidentYear[co$DevelopmentLag == 10], sum)
  error_pct <- (ultimate - actual) / actual
  
  backtest_list[[g]] <- data.frame(Company = g,
                                   AccidentYear = names(actual),
                                   Projected = round(ultimate),
                                   Actual = round(actual),
                                   ErrorPct = round(100 * error_pct, 1))
                                   
  
  # Completed triangle (rounded)
  tri_out <- data.frame(AccidentYear = as.numeric(rownames(full)),
                        round(full), check.names = FALSE)
  names(tri_out)[-1] <- 1:n
  
  # Save for the CSV, with the company name as the first column
  tri_list[[g]] <- cbind(Company = g, tri_out,
                         Actual = unname(round(actual[as.character(tri_out$AccidentYear)])))
  
  # Excel sheet
  addWorksheet(wb, sn)
  writeData(wb, sn, g, startRow = 1, startCol = 1)
  writeData(wb, sn, tri_out, startRow = 3)
  
  # Shade projected cells (the ones that were NA in the original triangle)
  na_pos <- which(is.na(m), arr.ind = TRUE)
  if (length(na_pos) > 0) {
    na_pos <- matrix(na_pos, ncol = 2)
    addStyle(wb, sn, yellow, rows = na_pos[, 1] + 3, cols = na_pos[, 2] + 1,
             gridExpand = FALSE, stack = TRUE)
  }
  
  # Latest, ultimate, reserve by accident year
  res_out <- data.frame(AccidentYear = as.numeric(rownames(full)),
                        Latest = round(latest),
                        Ultimate = round(ultimate),
                        Actual = unname(round(actual)),
                        ErrorPct = unname(round(100 * error_pct, 1)),
                        Reserve = round(reserve))
  writeData(wb, sn, res_out, startRow = n + 6)
  
  summary_rows[[g]] <- data.frame(Company = g, Sheet = sn,
                                  Latest = sum(latest),
                                  Ultimate = sum(ultimate),
                                  ErrorPct = unname(round(100 * error_pct, 1)),
                                  Reserve = sum(reserve))
}

# 7. Save the workbook
writeData(wb, "Summary", do.call(rbind, summary_rows))
saveWorkbook(wb, "C:/Users/milan/Downloads/Cas Data/AllCompanies_Triangles_WorkComp.xlsx",
             overwrite = TRUE)

backtest <- do.call(rbind, backtest_list)
addWorksheet(wb, "Backtest")
writeData(wb, "Backtest", backtest)
# END NEW

saveWorkbook(wb, "C:/Users/milan/Downloads/Cas Data/AllCompanies_Triangles_WorkComp.xlsx",
             overwrite = TRUE)


# 8. Write all completed triangles to a separate CSV
all_triangles <- do.call(rbind, tri_list)
write.csv(all_triangles,
          "C:/Users/milan/Downloads/Cas Data/AllCompanies_Triangles_WorkComp.csv",
          row.names = FALSE)

write.csv(backtest,
          "C:/Users/milan/Downloads/Cas Data/Backtest.csv",
          row.names = FALSE)



  