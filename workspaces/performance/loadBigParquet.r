library(arrow)
Sys.setenv(TZ='GMT')
df2 <- read_parquet(file.path(getwd(), "data-files", "20x1M.parquet"))