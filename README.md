Here is a brief guide to our code:

* `load.R`: loading / processing data from the Twitter API.
* `sentiment_eda.Rmd`: EDA on said data, as well as `syuzhet` sentiment calculations.
* `bert_sentiment.py`: a sample file for how we generated BERT sentiment scores. Running this file requires fairly extensive setup, which is well documented on [this page](https://huggingface.co/cardiffnlp/twitter-roberta-base-sentiment-latest).
* `map.R`: code to generate the heatmaps, with `kknn` smoothing.
* `paper.Rmd` and `paper.pdf`: the raw and compiled versions of the paper.
