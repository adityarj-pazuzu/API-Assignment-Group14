from fastapi import FastAPI
import pickle
import numpy as np
import os

app = FastAPI()

# Load model
model_path = os.path.join(os.path.dirname(__file__), "../models/model.pkl")
model = pickle.load(open(model_path, "rb"))

@app.get("/")
def home():
    return {"message": "Heart Disease Prediction API"}

@app.post("/predict")
def predict(data: dict):
    values = list(data.values())
    prediction = model.predict([values])
    return {"prediction": int(prediction[0])}