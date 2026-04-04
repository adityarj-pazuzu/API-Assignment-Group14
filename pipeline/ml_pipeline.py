"""Train, evaluate, log, and persist heart disease classification models."""

import json
import pickle
from pathlib import Path

import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler


def build_pipeline(model):
    """Create an end-to-end preprocessing and modeling pipeline."""
    numeric_features = ["Age", "RestingBP", "Cholesterol", "FastingBS", "MaxHR", "Oldpeak"]
    categorical_features = ["Sex", "ChestPainType", "RestingECG", "ExerciseAngina", "ST_Slope"]

    preprocessor = ColumnTransformer(
        transformers=[
            ("num", StandardScaler(), numeric_features),
            ("cat", OneHotEncoder(handle_unknown="ignore"), categorical_features),
        ]
    )

    return Pipeline(steps=[("preprocessor", preprocessor), ("model", model)])


def train_and_evaluate():
    """Train two candidate models, log metrics, and save the best performer."""
    project_root = Path(__file__).resolve().parents[1]
    data_path = project_root / "data" / "heart.csv"
    df = pd.read_csv(data_path)

    X = df.drop("HeartDisease", axis=1)
    y = df["HeartDisease"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.3, random_state=42, stratify=y
    )

    candidates = {
        "logistic_regression": LogisticRegression(max_iter=1000, random_state=42),
        "random_forest": RandomForestClassifier(n_estimators=300, random_state=42),
    }

    best_name = None
    best_model = None
    best_accuracy = -1.0
    all_metrics = {}

    mlflow.set_experiment("heart_disease_prediction")

    for name, estimator in candidates.items():
        pipeline = build_pipeline(estimator)
        with mlflow.start_run(run_name=name):
            pipeline.fit(X_train, y_train)
            y_pred = pipeline.predict(X_test)

            metrics = {
                "accuracy": accuracy_score(y_test, y_pred),
                "precision": precision_score(y_test, y_pred),
                "recall": recall_score(y_test, y_pred),
                "f1_score": f1_score(y_test, y_pred),
            }

            mlflow.log_metrics(metrics)
            mlflow.sklearn.log_model(pipeline, name="model")
            all_metrics[name] = metrics

            if metrics["accuracy"] > best_accuracy:
                best_accuracy = metrics["accuracy"]
                best_name = name
                best_model = pipeline

    models_path = project_root / "models"
    models_path.mkdir(exist_ok=True)

    model_path = models_path / "model.pkl"
    with open(model_path, "wb") as fp:
        pickle.dump(best_model, fp)

    report = {
        "best_model": best_name,
        "split": {"train": 0.7, "test": 0.3},
        "metrics": all_metrics,
    }
    report_path = models_path / "metrics_report.json"
    with open(report_path, "w", encoding="utf-8") as fp:
        json.dump(report, fp, indent=2)

    print(f"Best model: {best_name}")
    print(f"Saved model to: {model_path}")
    print(f"Saved metrics report to: {report_path}")


if __name__ == "__main__":
    train_and_evaluate()
