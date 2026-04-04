"""Prefect-based data pipeline for preprocessing, EDA, and artifact generation."""

from datetime import datetime, timezone
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from prefect import flow, get_run_logger, task
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import MinMaxScaler

# Business Understanding: Predict heart disease based on patient attributes to aid early diagnosis and treatment.

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_ROOT / "data" / "heart.csv"
DEPLOYMENT_PATH = PROJECT_ROOT / "deployment"

@task
def load_data():
    """Load the heart disease dataset from the repository data directory."""
    logger = get_run_logger()
    df = pd.read_csv(DATA_PATH)
    logger.info("Loaded dataset from %s with shape=%s", DATA_PATH, df.shape)
    return df

@task
def display_summary_stats(df):
    """Compute summary statistics for numeric and categorical columns."""
    logger = get_run_logger()
    summary = df.describe(include="all").transpose().astype(object).where(pd.notnull, "NA")
    logger.info("Computed summary statistics for %d columns", len(summary))
    return summary

@task
def check_missing_values(df):
    """Count missing values per column for monitoring and reporting."""
    logger = get_run_logger()
    missing = df.isnull().sum().to_dict()
    logger.info("Missing values by column: %s", missing)
    return missing

@task
def impute_missing(df):
    """Fill missing numeric feature values with column means."""
    logger = get_run_logger()
    # Impute numeric columns with the mean to keep all rows for training.
    numeric_cols = [
        col for col in df.select_dtypes(include=[np.number]).columns if col != "HeartDisease"
    ]
    df[numeric_cols] = df[numeric_cols].fillna(df[numeric_cols].mean())
    logger.info("Imputed missing values for numeric columns: %s", list(numeric_cols))
    return df

@task
def display_data_types(df):
    """Capture the inferred pandas data type of each column."""
    logger = get_run_logger()
    dtype_map = df.dtypes.astype(str).to_dict()
    logger.info("Data types captured for all columns")
    return dtype_map

@task
def encode_categorical(df):
    """One-hot encode categorical variables for downstream numeric analysis."""
    return pd.get_dummies(df, drop_first=True)

@task
def normalize_data(df):
    """Scale numeric feature columns to the 0-1 range."""
    logger = get_run_logger()
    # Normalize numeric data except the target to preserve labels.
    scaler = MinMaxScaler()
    numeric_cols = [
        col for col in df.select_dtypes(include=[np.number]).columns if col != "HeartDisease"
    ]
    df[numeric_cols] = scaler.fit_transform(df[numeric_cols])
    logger.info("Normalized numeric columns: %s", numeric_cols)
    return df

@task
def eda_correlations(df):
    """Calculate the correlation matrix for numeric columns."""
    corr = df.select_dtypes(include=[np.number]).corr()
    return corr

@task
def eda_categorical_correlations(df):
    """Summarize categorical distributions and their relationship to the target."""
    categorical_results = {}
    for col in df.select_dtypes(include=["object"]).columns:
        value_counts = df[col].value_counts().to_dict()
        by_target = {}
        if "HeartDisease" in df.columns:
            by_target = pd.crosstab(df[col], df["HeartDisease"]).to_dict()
        categorical_results[col] = {
            "value_counts": value_counts,
            "by_target": by_target,
        }
    return categorical_results

@task
def binning(df):
    """Create age bins for a simple categorical age-group analysis."""
    logger = get_run_logger()
    df["Age_Bin"] = pd.cut(
        df["Age"], bins=[0, 40, 50, 60, 100], labels=["Young", "Middle", "Senior", "Elder"]
    )
    logger.info("Created Age_Bin column")
    return df

@task
def feature_importance(df):
    """Estimate feature importance with a random forest classifier."""
    X = df.drop("HeartDisease", axis=1).select_dtypes(include=[np.number])
    y = df["HeartDisease"]
    model = RandomForestClassifier(random_state=42)
    model.fit(X, y)
    return dict(zip(X.columns, model.feature_importances_))

@task
def visualizations(df):
    """Generate and save the required univariate and bivariate EDA charts."""
    logger = get_run_logger()
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    DEPLOYMENT_PATH.mkdir(exist_ok=True)

    for col in numeric_cols[:5]:
        plt.figure()
        sns.histplot(df[col])
        plt.title(f"Histogram of {col}")
        plt.savefig(DEPLOYMENT_PATH / f"{col}_hist.png")
        plt.close()

    plt.figure()
    sns.scatterplot(data=df, x="Age", y="Cholesterol", hue="HeartDisease")
    plt.title("Age vs Cholesterol by Heart Disease")
    plt.savefig(DEPLOYMENT_PATH / "age_chol_scatter.png")
    plt.close()

    logger.info("Saved univariate and bivariate visualizations to %s", DEPLOYMENT_PATH)


@task
def persist_outputs(df, summary, missing, dtypes, corr, cat_corr, importances):
    """Write processed data and a structured EDA report to the deployment folder."""
    DEPLOYMENT_PATH.mkdir(exist_ok=True)

    cleaned_path = DEPLOYMENT_PATH / "heart_processed.csv"
    df.to_csv(cleaned_path, index=False)

    report = {
        "run_timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "row_count": int(df.shape[0]),
        "column_count": int(df.shape[1]),
        "missing_values": missing,
        "data_types": dtypes,
        "summary_statistics": summary.to_dict(orient="index"),
        "correlation_matrix": corr.round(4).to_dict(),
        "categorical_analysis": cat_corr,
        "feature_importance": {k: float(v) for k, v in importances.items()},
    }

    report_path = DEPLOYMENT_PATH / "data_pipeline_report.json"
    with open(report_path, "w", encoding="utf-8") as fp:
        json.dump(report, fp, indent=2)

    logger = get_run_logger()
    logger.info("Saved processed data to %s", cleaned_path)
    logger.info("Saved data pipeline report to %s", report_path)
    return {"processed_data": cleaned_path, "report": report_path}

@flow
def data_pipeline():
    """Run the full data pipeline from ingestion through reporting."""
    df = load_data()
    summary = display_summary_stats(df)
    missing = check_missing_values(df)
    df = impute_missing(df)
    dtypes = display_data_types(df)
    df = binning(df)
    cat_corr = eda_categorical_correlations(df)
    encoded_df = encode_categorical(df)
    normalized_df = normalize_data(encoded_df)
    corr = eda_correlations(normalized_df)
    importances = feature_importance(normalized_df)
    visualizations(df)
    return persist_outputs(normalized_df, summary, missing, dtypes, corr, cat_corr, importances)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run or schedule the Prefect data pipeline")
    parser.add_argument(
        "--serve",
        action="store_true",
        help="Serve this flow on a 3-minute interval for DataOps automation",
    )
    args = parser.parse_args()

    if args.serve:
        data_pipeline.serve(name="heart-dataops-3min", interval=180)
    else:
        data_pipeline()
