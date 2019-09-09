import pandas as pd
import datetime
import pandas_datareader.data as web
from pandas import Series, DataFrame

import math
import numpy as np
from sklearn import preprocessing, svm
from sklearn.model_selection import train_test_split

import json

from sklearn.linear_model import LinearRegression

def aiml():
  start = datetime.datetime(2008, 1, 1)
  end = datetime.datetime(2019, 8, 14)

  df = web.DataReader('SPY', 'yahoo', start, end)
  print(df.tail())

  close_px = df['Adj Close']
  mavg = close_px.rolling(window=100).mean()
  print(mavg.tail(10))

  rets = close_px / close_px.shift(1) - 1
  print(rets.head())

  dfreg = df.loc[:,['Adj Close','Volume']]
  dfreg['HL_PCT'] = (df['High'] - df['Low']) / df['Close'] * 100.0
  dfreg['PCT_change'] = (df['Close'] - df['Open']) / df['Open'] * 100.0
  print(dfreg.head())

  # Drop missing value
  dfreg.fillna(value=-99999, inplace=True)

  print(dfreg.shape)
  # We want to separate 1 percent of the data to forecast
  forecast_out = int(math.ceil(0.01 * len(dfreg)))

  # Separating the label here, we want to predict the AdjClose
  forecast_col = 'Adj Close'
  dfreg['label'] = dfreg[forecast_col].shift(-forecast_out)
  X = np.array(dfreg.drop(['label'], 1))
 
  # Scale the X so that everyone can have the same distribution for linear regression
  X = preprocessing.scale(X)

  # Finally We want to find Data Series of late X and early X (train) for model generation and evaluation
  X_lately = X[-forecast_out:]
  X = X[:-forecast_out]

  # Separate label and identify it as y
  y = np.array(dfreg['label'])
  y = y[:-forecast_out]

  print('Dimension of X',X.shape)
  print('Dimension of y',y.shape)

  X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

  # Linear regression
  clfreg = LinearRegression(n_jobs=-1)
  clfreg.fit(X_train, y_train)
  
  confidencereg = clfreg.score(X_test, y_test)
  print("The linear regression confidence is ",confidencereg)

  # Printing the forecast
  forecast_set = clfreg.predict(X_lately)
  dfreg['Forecast'] = np.nan
  print(forecast_set, confidencereg, forecast_out)

  last_date = dfreg.iloc[-1].name
  print(last_date)
  last_unix = last_date
  next_unix = last_unix + datetime.timedelta(days=1)

  for i in forecast_set:
    next_date = next_unix
    next_unix += datetime.timedelta(days=1)
    dfreg.loc[next_date] = [np.nan for _ in range(len(dfreg.columns)-1)]+[i]

  forecast = dfreg['Forecast'].tail(30).to_json(date_format='iso')
  return forecast