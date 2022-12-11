# This code is heavily based on Prof. David Brown's lab replicating Joshua 
# Katz's geographic plots of lexical variants. Thanks to him for providing it!

library(tidyverse)
library(kknn)

library(foreach)
library(doParallel)

library(sf)
library(rnaturalearth)
library(housingData)
require(rgeos)


setwd("~/msp/wildfire_sentiment_analysis/data")

fire_name <- 'bay_area'
tweets <- readRDS(paste0(fire_name, '_fire_tweets.RDS'))
places <- readRDS(paste0(fire_name, '_fire_places.RDS'))
sentiment <- read.csv(paste0(fire_name, '_fire_sentiment.csv'))

# number of words in file.
# sum(unlist(lapply(sentiment$text, function(x) str_count(x, '\\w+'))))


sentiment$text_cleaned <- sentiment$text
sentiment$text <- NULL
places <- distinct(places)

pattern <- '^([^\\s]+) ([^\\s]+) ([^\\s]+) ([^\\s]+)$'

data <- cbind(tweets, sentiment) %>%
  # filter(like_count > 0 & retweet_count > 0) %>%
  filter(label != "neutral") %>%
  mutate(label = str_to_title(label)) %>%
  left_join(places, by = c('place_id' = 'id')) %>%
  transmute(
    sentiment = as.factor(label),
    long = (as.numeric(gsub(pattern, '\\1', bbox)) + 
              as.numeric(gsub(pattern, '\\3', bbox)))/2,
    lat = (as.numeric(gsub(pattern, '\\2', bbox)) + 
             as.numeric(gsub(pattern, '\\4', bbox)))/2
  )



states_us <- rnaturalearthdata::states50
states_us <- states_us[states_us$iso_a2 == 'US',]
states_us <- states_us[ !grepl( "Alaska|Hawaii" , states_us$name ) , ]
states_us <- st_as_sf(states_us)

nalcc <- "+proj=lcc +lat_1=20 +lat_2=60 +lat_0=40 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"

us <- states_us %>% st_transform(nalcc)

coord_data <- data %>%
  drop_na() %>%
  # limit to tweets in the lower 48.
  filter(long < -65, long > -125) %>%
  filter(lat < 50, lat > 24) %>%
  st_as_sf(coords = c("long", "lat"), crs = "+proj=longlat +ellps=WGS84") %>%
  st_transform(nalcc)

map_df <- data.frame(
  sentiment = coord_data$sentiment, 
  lon = st_coordinates(coord_data)[, 1], 
  lat = st_coordinates(coord_data)[, 2]
)

# helpful plot to debug individual points if needed
# ggplot(data = map_df) +
#   geom_sf(data = us) +
#   geom_point(aes(x = lon, y = lat, color = sentiment), alpha = 1) +
#   scale_color_brewer(palette = "Dark2",  name = "Sentiment")


set.seed(123)
valid_split <- rsample::initial_split(map_df, .75)
map_df_train <- rsample::analysis(valid_split)
map_df_test <- rsample::assessment(valid_split)

width_in_pixels <- 300
dx <- ceiling( (st_bbox(us)["xmax"] - st_bbox(us)["xmin"]) / width_in_pixels)
dy <- dx
height_in_pixels <- floor( (st_bbox(us)["ymax"] - st_bbox(us)["ymin"]) / dy)
grid <- st_make_grid(
  us,
  cellsize = dx,
  n = c(width_in_pixels, height_in_pixels),
  what = "centers"
)
k <- 1000

compute_grid <- function(grid, sentiment_train, knn) {

  result <- data.frame(
    sentiment = as.factor(NA), 
    lon = st_coordinates(grid)[, 1], 
    lat = st_coordinates(grid)[, 2]
  )
  sentiment_kknn <- kknn::kknn(
    sentiment ~ ., 
    train = sentiment_train, 
    test = result, 
    kernel = "gaussian",
    k=knn
  )
  result <- result %>%
    mutate(
      sentiment = fitted(sentiment_kknn),
      prob = apply(sentiment_kknn$prob, 1, function(x) max(x))
    )
  
  return(result)
  
}

registerDoParallel(cores = 8)
no_batches <- 40
batch_size <- ceiling(length(grid) / no_batches)

sentiment_result <- foreach(.packages = c("sf", "tidyverse"), batch_no = 1:no_batches, .combine = rbind, .inorder = FALSE) %dopar% {
   start_idx <- (batch_no - 1) * batch_size + 1
   end_idx <- batch_no * batch_size
   grid_batch <- grid[start_idx:ifelse(end_idx > length(grid), length(grid), end_idx)]
   df <- compute_grid(grid_batch, map_df_train, k)
}

sentiment_raster <- st_as_sf(
  sentiment_result, 
  coords = c("lon", "lat"),
  crs = nalcc,
  remove = F
)

sentiment_raster <- sentiment_raster[us, ]

saveRDS(sentiment_raster, paste0(fire_name, '_map_data.RDS'))
saveRDS(us, 'us_map_data.RDS')

ggplot(data = sentiment_raster) +
  geom_raster(aes(x = lon, y = lat, fill = sentiment, alpha = prob)) +
  scale_fill_manual(values = c("tomato", "steelblue", "forestgreen")) +
  scale_alpha(guide = 'none') +
  geom_sf(data = us, alpha = 0, size = 0.25) +
  theme_void() +
  theme(legend.position = c(0.1, 0.2), legend.box = "horizontal") +
  theme(legend.title=element_blank())

stopImplicitCluster()