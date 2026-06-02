library(connections)
library(DBI)
library(RSQLite)

db_path <- file.path(getwd(), "db", "nycflights13.sqlite")
con <- connection_open(SQLite(), db_path)
