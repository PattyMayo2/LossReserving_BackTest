Backtesting Chain Ladder Reserves Across Lines of Business
-

The Chain Ladder Method has always been a staple for Insurance Reserving, but how well does it compare to the actual claim payments? Using the CAS Loss Reserving Data Base which includes data from the NAIC Schedule P Filing I was able construct paid-loss triangles up until the end of 2007 for the six lines of business and predict each companies Lag 10 losses as well as backtesting these predictions with the actual reported losses. On average for this data, the chain ladder method showed little projected bias with private passenger auto lines being the only detectable exception to this showing approximately 6% overprojection. All together, predictions by the accident year 2007 differed significantly by line: typical misses for private passenger being about 8%, 14% to 16% for  commercial auto and and worker's compensation, and about 48% for other liability. Medical Malpractice and Product Liability had far too few lines (4 and 8 respectively) to support firm conclusions. It is important to note that these results are from a filtered sample, the 25th percentile of smallest companies by net premium were filtered out, so these findings are meant to support larger companies rather than the entire industry.

Data: Meyers and Shi, 2011, https://www.casact.org/publications-research/research/research-resources/loss-reserving-data-pulled-naic-schedule-p

Methods:
- 
- Filtered data by positive claim payments and 25th percentile of net premiums across lines
- Preformed volume-weighted Chain Ladder Analysis on paid losses with tail factor of 1.0
- Triangles were cut by 2007 and backtested against actual lag 10 values
- Moved percent error to log error since percent error was distorted by the actual lag 10 claim payments for specific lines

Results:
- 

|   |Line             |  N| Pct_Bias| Typical_miss_pct|
|:--|:----------------|--:|--------:|----------------:|
|9  |CommercialAuto   | 72|    -1.94|             13.7|
|18 |MedicalMal       |  4|   -30.03|             42.6|
|27 |OtherLiability   | 69|    -5.27|             47.8|
|36 |PrivPassenger    | 74|     6.38|              8.2|
|45 |ProductLiability |  8|     8.05|            131.9|
|54 |WorkComp         | 45|    -1.77|             16.0|

![Error by accident year](figures/1_error_by_year.png)
*Median absolute log error by line and accident year. Error grows toward the newest years. Log-error basis, accident year 1998 excluded.*

![2007 bias intervals](figures/4_bias_intervals_2007.png)
*Bias by line for accident year 2007, with 95% confidence intervals (log-error basis, geometric mean of projected / actual). Intervals that cross 0 show no detectable bias. Medical malpractice (n=4) and product liability (n=8) have very wide intervals because of small samples.*

Limitations:
- 
- Chain Ladders only include lag 10 values which understates ultimate payments for long-tailed lines
- Incurred Losses were not included and only used to filter data
- Negative and zero paid and incurred data as well as 25th percentile of net premiums were filtered out
- 2007 was the only evaluation data used
- Log Error T-tests assume normal errors, so Wilcoxon Tests were run
- Companies preform business across several lines so p-values should be rough guidelines for bias

Future Intentions:
-
- Repeat analysis for incurred losses
- Test Bornhuetter-Ferguson and Cape Cod in hopes of reducing errors for large accident years
- Rerun tail factors for long-tailed lines

Note: AI assistance was used for code generation, selected calculations were checked by hand in order to verify results
