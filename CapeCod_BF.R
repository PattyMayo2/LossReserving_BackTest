library(ChainLadder)

folder <- "path/to/your/data/"
if (file.exists("config_local.R")) source("config_local.R")

lines <- c(
  WorkComp         = "WorkComp.csv",
  OtherLiability   = "OtherLiability.csv",
  ProductLiability = "ProductLiability.csv",
  CommercialAuto   = "CommercialAuto.csv",
  MedicalMal       = "MedicalMal.csv",
  PrivPassenger    = "PrivPassenger.csv"
)

run_methods <- function(line_name, file_name) {
  
  # Same filters as the Phase 1 build script
  data <- read.csv(paste0(folder, file_name))
  data <- data[data$AccidentYear >= 1997 & data$AccidentYear <= 2008, ]
  good  <- names(which(tapply(data$CumPaidLoss > 0 & data$IncurredLosses > 0,
                              data$GRNAME, all)))
  clean <- data[data$GRNAME %in% good, ]
  prem  <- tapply(clean$EarnedPremNet, clean$GRNAME, sum)
  good  <- sort(names(prem)[prem > quantile(prem, 0.25)])
  clean <- clean[clean$GRNAME %in% good, ]
  
  out <- list()
  for (g in good) {
    co <- clean[clean$GRNAME == g, ]
    
    res <- tryCatch({
      tri_data <- co[co$DevelopmentYear <= max(co$AccidentYear), ]
      tri <- as.triangle(tri_data, origin = "AccidentYear",
                         dev = "DevelopmentLag", value = "CumPaidLoss")
      m <- unclass(tri)
      if (!all(dim(m) == c(10, 10))) stop("not 10x10")
      m
    }, error = function(e) NULL)
    if (is.null(res)) next
    m <- res
    n <- ncol(m)
    yrs <- rownames(m)
    
    # Premium per accident year (taken from lag 1 rows)
    p1 <- co[co$DevelopmentLag == 1, ]
    premium <- tapply(p1$EarnedPremNet, p1$AccidentYear, sum)[yrs]
    if (any(is.na(premium)) || any(premium <= 0)) next
    
    # Volume-weighted factors, CDFs, percent developed
    f <- sapply(1:(n - 1), function(k) {
      h <- !is.na(m[, k + 1])
      sum(m[h, k + 1]) / sum(m[h, k])
    })
    cdf    <- rev(cumprod(rev(c(f, 1))))        # tail factor = 1
    Lidx   <- n - seq_len(n) + 1                # latest lag for each row
    latest <- m[cbind(seq_len(n), Lidx)]
    pctdev <- 1 / cdf[Lidx]
    
    # 1. Chain ladder
    ult_cl <- latest * cdf[Lidx]
    
    # 2. Cape Cod: expected loss ratio estimated from the data
    elr_cc <- sum(latest) / sum(premium * pctdev)
    ult_cc <- latest + premium * elr_cc * (1 - pctdev)
    
    # 3. Bornhuetter-Ferguson: a priori loss ratio = average chain ladder
    #    loss ratio of the three oldest (most mature) accident years
    elr_bf <- mean((ult_cl / premium)[1:3])
    ult_bf <- latest + premium * elr_bf * (1 - pctdev)
    
    actual <- tapply(co$CumPaidLoss[co$DevelopmentLag == 10],
                     co$AccidentYear[co$DevelopmentLag == 10], sum)[yrs]
    
    out[[g]] <- rbind(
      data.frame(Method = "ChainLadder", Projected = ult_cl),
      data.frame(Method = "CapeCod",     Projected = ult_cc),
      data.frame(Method = "BF",          Projected = ult_bf)
    )
    out[[g]] <- cbind(Line = line_name, Company = g,
                      AccidentYear = rep(yrs, 3),
                      out[[g]],
                      Actual = rep(as.numeric(actual), 3))
  }
  do.call(rbind, out)
}

results <- list()
for (ln in names(lines)) results[[ln]] <- run_methods(ln, lines[[ln]])
bt <- do.call(rbind, results)
rownames(bt) <- NULL

bt$Projected <- round(bt$Projected)
bt$Actual    <- round(bt$Actual)
write.csv(bt, paste0(folder, "Backtest_Methods.csv"), row.names = FALSE)
