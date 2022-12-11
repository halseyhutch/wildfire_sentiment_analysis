from transformers import AutoTokenizer, AutoModelForSequenceClassification
from transformers import pipeline
import pandas as pd
import pyreadr
import re

in_df = pyreadr.read_r('C:/Users/halse/Documents/msp/wildfire_sentiment_analysis/data/tubbs_fire_tweets.RDS')
in_df = in_df[None]
tweets = list(in_df.text)
# remove links
tweets = [re.sub(r'https?://\S+', '', t) for t in tweets]
# remove usernames
tweets = [re.sub(r'@[^\s]+', '', t) for t in tweets]


MODEL = f"cardiffnlp/twitter-roberta-base-sentiment-latest"
tokenizer = AutoTokenizer.from_pretrained(MODEL)
model = AutoModelForSequenceClassification.from_pretrained(MODEL)
# tokenizer.save_pretrained(MODEL)
# model.save_pretrained(MODEL)

sentiment_task = pipeline('sentiment-analysis', model=model, tokenizer=tokenizer)
out_df = pd.DataFrame(sentiment_task(tweets))
out_df['text'] = tweets
out_df.to_csv('tubbs_fire_sentiment.csv', index=False)