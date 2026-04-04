import pandas as pd
import mlflow
import mlflow.sklearn
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
import pickle
import os

# Load data
data_path = os.path.join(os.path.dirname(__file__), "../data/heart.csv")
df = pd.read_csv(data_path)

# Preprocessing
df = pd.get_dummies(df, drop_first=True)

X = df.drop("HeartDisease", axis=1)
y = df["HeartDisease"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42
)

models = {
    "logistic_regression": LogisticRegression(max_iter=1000),
    "random_forest": RandomForestClassifier()
}

best_model = None
best_score = 0

for name, model in models.items():
    with mlflow.start_run(run_name=name):
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)

        acc = accuracy_score(y_test, y_pred)
        prec = precision_score(y_test, y_pred)
        rec = recall_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred)

        mlflow.log_metric("accuracy", acc)
        mlflow.log_metric("precision", prec)
        mlflow.log_metric("recall", rec)
        mlflow.log_metric("f1_score", f1)

        mlflow.sklearn.log_model(model, "model")

        if acc > best_score:
            best_score = acc
            best_model = model

# Save best model
model_path = os.path.join(os.path.dirname(__file__), "../models/model.pkl")
with open(model_path, "wb") as f:
    pickle.dump(best_model, f)

print("Best model saved!")