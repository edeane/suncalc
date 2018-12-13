
# References
# https://www.wbur.org/hereandnow/2018/12/11/sunsets-getting-later-winter-solstice
# http://www.idialstars.com/eass.htm
# http://suncalc.net
# https://github.com/mourner/suncalc
# https://www.aa.quae.nl/en/reken/zonpositie.html
# https://cran.r-project.org/web/packages/suncalc/index.html
# https://www.timeanddate.com/sun/usa/denver
# the data accounts for daylight saving time changes


# get lat and long of cities
library(ggmap)

# get timze zones of cities
library(lutz)

# get sunrise and sunset times
library(suncalc)

# data munge
library(data.table)

# plot some data
library(ggplot2)
theme_set(theme_light())

plot_save <- function(plot, width=980, height=700, text_factor=1, filename='plot.png') {
  dpi <- text_factor * 100
  width_calc <- width / dpi
  height_calc <- height / dpi
  ggsave(filename = filename, dpi = dpi, width = width_calc, height = height_calc, units = 'in', plot = plot)
}


year_input <- 2018
time_columns <- c('sunrise', 'solarNoon', 'sunset')
cities <- data.table(city_name=c('Honolulu, HI', 'Denver, CO', 'Anchorage, AK'))

# get the city lat and lon
cities <- cbind(cities, as.data.table(ggmap::geocode(cities[, city_name], source='dsk')))

# get the timezone by city
cities[, timezone := tz_lookup_coords(lat, lon, warn=F)]
cities

# year range
from_date <- as.Date(paste0(year_input, '/1/1'))
to_date <- as.Date(paste0(year_input, '/12/31'))
from_to_date_vec <- seq.Date(from_date, to_date, by='day')

# get sunires sunset time data
cities_ls <- list()
for (city in cities[, city_name]) {
  print(city)
  tz <- cities[city_name==city, timezone]
  print(tz)
  res <- as.data.table(getSunlightTimes(date=from_to_date_vec, lat=cities[city_name==city, lat], lon=cities[city_name==city, lon], 
                                        keep=time_columns, tz='UTC'))
  
  for (col_name in time_columns) {
    print(col_name)
    res[, (col_name) := as.POSIXct(strftime(format(get(col_name), tz=tz)))]
  }
  cities_ls[[city]] <- res
}

# convert to data.table
cities_dt <- rbindlist(cities_ls, idcol='city_name')
cities_dt <- na.omit(cities_dt)
cities_dt[, date := as.Date(date)]

# convert times to all the same day (year-01-01)
date_to_times <- function(x) {
  return(as.POSIXct(strftime(paste0(year_input, '-01-01 ', format(x, '%H:%M:%S')), format='%Y-%d-%m %H:%M:%S')))
}

for (col_name in time_columns) {
  print(col_name)
  cities_dt[, (paste0(col_name, '_time')) := date_to_times(get(col_name))]
}

# calculate seconds of daylight sunlight
cities_dt[, daylight_secs := as.integer(difftime(sunset, sunrise, units='secs'))]

# seconds to minutes for printing
seconds_to_hrs_mins <- function(x) {
  return(paste0(floor(x / 3600), ' hrs. ', ceiling((x %% 3600) / 60), ' mins.'))
}


# print max and mins ------------------------------------------------------

max_mins_ls <- list()

for (city in cities[, city_name]) {
  print(city)
    
  max_daylight_idx <- cities_dt[city_name==city, which.max(daylight_secs)]
  min_daylight_idx <- cities_dt[city_name==city, which.min(daylight_secs)]
  
  max_sunrise_idx <- cities_dt[city_name==city, which.max(sunrise_time)]
  min_sunrise_idx <- cities_dt[city_name==city, which.min(sunrise_time)]
  
  max_sunset_idx <- cities_dt[city_name==city, which.max(sunset_time)]
  min_sunset_idx <- cities_dt[city_name==city, which.min(sunset_time)]
  
  dt_idxs <- c(max_daylight_idx, min_daylight_idx, max_sunrise_idx, min_sunrise_idx, max_sunset_idx, min_sunset_idx)
  
  print_res <- cities_dt[city_name==city, .(date, sunrise=format(sunrise, format='%H:%M:%S'), 
                                  sunset=format(sunset, format='%H:%M:%S'), 
                                  daylight=seconds_to_hrs_mins(daylight_secs))][dt_idxs, ]
  print_res[, label := c('max daylight', 'min daylight', 'max sunrise', 'min sunrise', 'max sunset', 'min susnset')]
  
  print(print_res[, ])
  
  max_mins_ls[[city]] <- print_res
  
}

fwrite(rbindlist(max_mins_ls, idcol='city_name'), '')


# graphs ------------------------------------------------------------------

# daylight month over month
# sunrise and sunset month over month
city <- 'Denver, CO'
cities_dt[city_name==city & date > '2018-03-09' & date < '2018-03-12', ]

daylight_plt <- ggplot(cities_dt, aes(date, daylight_secs, color=city_name)) + geom_line(size=1)
plot_save(daylight_plt, width=898, height=698, text_factor=1, filename='')

cities_dt_melt <- melt(cities_dt[, .(city_name, date, sunrise_time, sunset_time)], id.vars=c('city_name', 'date'))
cities_dt_melt
ggplot(cities_dt_melt[city_name=='Denver, CO', ], aes(date, value, group=city_name, color=variable)) + geom_line()
ggplot(cities_dt_melt[city_name=='Anchorage, AK', ], aes(date, value, color=variable)) + geom_line()
ggplot(cities_dt_melt[city_name=='Honolulu, HI', ], aes(date, value, color=variable)) + geom_line()


sunrise_sunset_plt <- ggplot(cities_dt, aes(x=date)) + 
  geom_line(size=1, aes(y=sunrise_time, color=city_name)) + 
  geom_line(size=1, aes(y=sunset_time, color=city_name)) + 
  labs(y='time')
plot_save(sunrise_sunset_plt, width=898, height=698, text_factor=1, filename='')


# understand dates --------------------------------------------------------

# strptime returns POSIXlt (list) while strftime returns character which can be converted to POSIXct
class(strptime(paste0(year_input, '-01-01 07:16:50'), format='%Y-%d-%m %H:%M:%S'))
class(strftime(paste0(year_input, '-01-01 07:16:50'), format='%Y-%d-%m %H:%M:%S'))
class(strftime(paste0(year_input, '-01-01 07:16:50'), format='%Y-%d-%m %H:%M:%S'))
class(as.POSIXct(strftime(paste0(year_input, '-01-01 07:16:50'), format='%Y-%d-%m %H:%M:%S')))

# convert beween character and POSIXlt
# strftime('07:16:50', format='%H:%M:%S')
strftime(paste0(year_input, '-01-01 07:16:50'), format='%Y-%d-%m %H:%M:%S')
strptime('07:16:50', format='%H:%M:%S')

# format converts it to readable
format(as.POSIXct(strftime(paste0(year_input, '-01-01 07:16:50'), format='%Y-%d-%m %H:%M:%S')), format='%H:%M:%S')





