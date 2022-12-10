library(httr)
library(jsonlite)
library(tidyverse)

# https://developer.twitter.com/en/docs/tutorials/getting-historical-tweets-using-the-full-archive-search-endpoint
# https://developer.twitter.com/en/docs/twitter-api/tweets/search/integrate/build-a-query
# https://developer.twitter.com/en/docs/twitter-api/data-dictionary/introduction
bearer_token = readLines('~/msp/wildfire_sentiment_analysis/bearer_token.txt')

headers = c(
  `Authorization` = sprintf('Bearer %s', bearer_token)
)

n <- 100000

# search in the US 
# place_country:US
# search in CA [note: this bounding box is too big]
# bounding_box:[-124.48200 32.52883 -114.13121 42.00952]
# dixie fire: August 2021
# bay area fire: 8/15/20 - 9/15/20
# camp fire: November 2018
# tubbs fire: October 2017
params = list(
  `query` = 'fire -is:retweet lang:en place_country:US',
  `start_time` = '2020-08-15T00:00:00.00Z',
  `end_time` = '2020-09-15T00:00:00.00Z',
  `max_results` = '500',
  `tweet.fields` = 'created_at,lang,public_metrics',
  `expansions` = 'geo.place_id',
  # `user.fields` = 'description,location,public_metrics',
  `place.fields` = 'geo,place_type'
)

tweets <- data.frame(
  text = character(0),
  # author_id = character(0),
  place_id = character(0),
  created_at = as.Date(character(0)),
  retweet_count = numeric(0),
  reply_count = numeric(0),
  like_count = numeric(0),
  quote_count = numeric(0)
)

users <- data.frame(
  id = character(0),
  username = character(0),
  name = character(0),
  description = character(0),
  followers_count = numeric(0),
  following_count = numeric(0),
  tweet_count = numeric(0),
  listed_count = numeric(0)
)

places <- data.frame(
  id = character(0),
  full_name = character(0),
  place_type = character(0),
  bbox = character(0)
)

while (nrow(tweets) < n) {
  
  print(paste("Loaded", nrow(tweets), "tweets..."))
  
  response <- httr::GET(
    url = 'https://api.twitter.com/2/tweets/search/all',
    httr::add_headers(.headers=headers),
    query = params
  )
  
  result <- content(
    response,
    as = 'parsed',
    type = 'application/json',
    simplifyDataFrame = TRUE
  )
  
  
  tweet_df <- cbind(
    result$data$text,
    # result$data$author_id,
    result$data$geo$place_id,
    result$data$created_at,
    result$data$public_metrics
  )
  
  colnames(tweet_df)[1:3] <- c('text', 'place_id', 'created_at')
  
  tweets <- rbind(tweets, tweet_df)
  
  
  # user_df <- cbind(
  #   result$includes$users$id,
  #   result$includes$users$username,
  #   result$includes$users$name,
  #   result$includes$users$description,
  #   result$includes$users$public_metrics
  # )
  # 
  # colnames(user_df)[1:4] <- c('id', 'username', 'name', 'description')
  # 
  # users <- rbind(users, user_df)
  
  
  place_df <- as.data.frame(cbind(
    result$includes$places$id,
    result$includes$places$full_name,
    result$includes$places$place_type,
    unlist(lapply(result$includes$places$geo$bbox, function(x) paste(x, collapse = " ")))
  ))
  
  colnames(place_df) <- c('id', 'full_name', 'place_type', 'bbox')
  
  places <- rbind(places, place_df)
  
  
  nt <- result$meta$next_token
  if (is.null(nt)) break
  params['next_token'] = nt
  
}

saveRDS(tweets, 'bay_area_fire_tweets.RDS')
saveRDS(places, 'bay_area_fire_places.RDS')

# t3 <- readRDS('dixie_tweets.RDS')

