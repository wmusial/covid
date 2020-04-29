library(data.table)
library(lubridate)
library(ggplot2)
library(VORtex)
library(pracma)

data.dt = as.data.table(read.csv("covid-confirmed-deaths-since-5th-death.csv"))
names(data.dt) =  c('entity', 'code', 'date', 'deaths', 'days.since')
data.dt[, date := parse_date_time(as.character(date), orders="bdy")]

setkey(data.dt, entity, date)
data.dt[, d.deaths := deaths - VORtex::ts.lag(deaths, 1), by = entity]

# print total deaths summary
max.deaths.dt = data.dt[, list(max.deaths=max(deaths)), by = entity]

writelog("summary of max.deaths:")
summary(max.deaths.dt$max.deaths)

writelog("entities: %s", length(unique(data.dt$entity)))

sub.data.dt = data.dt[is.element(entity, max.deaths.dt[max.deaths >= 500]$entity)]
writelog("entities with more than 500 deaths: %s", length(unique(sub.data.dt$entity)))

non.countries = c("Africa", "Asia", "Asia excl. China", "Europe", "European Union", "High income", "Lower middle income", "North America", "South America", "Upper middle income", "World", "World excl. China", "World excl. China and South Korea", "World excl. China, South Korea, Japan and Singapore")
sub.data.dt = sub.data.dt[!is.element(entity, non.countries)]

sub.data.dt[, week := as.integer((.N - seq(.N)) / 7), by = entity]
byweek.dt = sub.data.dt[, list(d.deaths = sum(d.deaths)), keyby = list(entity, week)]

do.plot(byweek.dt, "week", "ourworldindata_500_countries_revweek.pdf")


peak.week.dt = byweek.dt[, list(peak.week = which.max(d.deaths)), by = entity]

peak.countries = peak.week.dt[peak.week >= 3, entity]

peak.dt = sub.data.dt[is.element(entity, peak.countries)]
do.plot(peak.dt, "date", "ourworldindata_500_countries_oldpeak.pdf")

# clean outliers
peak.dt[d.deaths == 0, d.deaths := NA]
peak.dt[, mean.d.deaths := ts.lag(ts.roll.mean(d.deaths, 3), 1), by = entity]
peak.dt[, mean.d.deaths.lag := ts.lag(mean.d.deaths, -2), by = entity]


do.plot = function(data.dt, x.name, path = NULL) {
	if (!is.null(path)) {
		pdf(width=10, height=3*length(unique(data.dt$entity)), file=path)
  }
	p = ggplot(data.dt, aes(x=get(x.name), y=d.deaths)) + facet_grid(entity~., scales="free") + geom_step() + labs(x=x.name)
	print(p)
	if (!is.null(path)) {
		dev.off()
  }
}


deaths.m = dcast(peak.dt[!is.na(days.since)], entity ~ days.since, value.var = "d.deaths", fill=NA_real_)
entities = deaths.m$entity
deaths.m[, entity := NULL]
deaths.m = as.matrix(deaths.m)
rownames(deaths.m) = entities

num.countries = nrow(deaths.m)
num.dates = ncol(deaths.m)

source("opt.R")
#compute.deaths(2, 10, c(1,1), c(1,1), 1, 1, c(1,1), c(1,1))
