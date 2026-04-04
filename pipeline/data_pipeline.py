from prefect import flow, task
import pandas as pd
from sklearn.preprocessing import MinMaxScaler
from sklearn.ensemble import RandomForestClassifier
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import os

# Business Understanding: Predict heart disease based on patient attributes to aid early diagnosis and treatment.

@task
def load_data():
    data_path = os.path.join(os.path.dirname(__file__), "../data/heart.csv")
    df = pd.read_csv(data_path)
    return df

@task
def display_summary_stats(df):
    print("Summary Statistics:")
    print(df.describe())
    return df

@task
def check_missing_values(df):
    print("Missing Values:")
    print(df.isnull().sum())
    return df

@task
def impute_missing(df):
    # Impute missing values for numeric columns
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    df[numeric_cols] = df[numeric_cols].fillna(df[numeric_cols].mean())
    return df

@task
def display_data_types(df):
    print("Data Types:")
    print(df.dtypes)
    return df

@task
def encode_categorical(df):
    # Encode categorical variables
    df = pd.get_dummies(df, drop_first=True)
    return df

@task
def normalize_data(df):
    # Normalize numeric data
    scaler = MinMaxScaler()
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    df[numeric_cols] = scaler.fit_transform(df[numeric_cols])
    return df

@task
def eda_correlations(df):
    # Calculate correlation coefficients
    print("Correlation Matrix:")
    corr = df.select_dtypes(include=[np.number]).corr()
    print(corr)
    return df

@task
def eda_categorical_correlations(df):
    # For categorical, print value counts and crosstabs
    print("Categorical Feature Distributions and Correlations:")
    for col in df.select_dtypes(include=['object']).columns:
        print(f"{col}:")
        print(df[col].value_counts())
        if 'HeartDisease' in df.columns:
            print(pd.crosstab(df[col], df['HeartDisease']))
    return df

@task
def binning(df):
    # Binning age into categories
    df['Age_Bin'] = pd.cut(df['Age'], bins=[0, 40, 50, 60, 100], labels=['Young', 'Middle', 'Senior', 'Elder'])
    print("Age Binning:")
    print(df['Age_Bin'].value_counts())
    return df

@task
def feature_importance(df):
    # Assess feature importance using Random Forest
    X = df.drop('HeartDisease', axis=1).select_dtypes(include=[np.number])
    y = df['HeartDisease']
    model = RandomForestClassifier(random_state=42)
    model.fit(X, y)
    importances = model.feature_importances_
    features = X.columns
    print("Feature Importances:")
    for f, imp in zip(features, importances):
        print(f"{f}: {imp}")
    return df

@task
def visualizations(df):
    # Univariate analysis
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    deployment_path = os.path.join(os.path.dirname(__file__), "../deployment")
    for col in numeric_cols[:5]:  # Limit to first 5
        plt.figure()
        sns.histplot(df[col])
        plt.title(f'Histogram of {col}')
        plt.savefig(os.path.join(deployment_path, f"{col}_hist.png"))
        plt.close()

    # Bivariate analysis
    plt.figure()
    sns.scatterplot(data=df, x='Age', y='Cholesterol', hue='HeartDisease')
    plt.title('Age vs Cholesterol by Heart Disease')
    plt.savefig(os.path.join(deployment_path, "age_chol_scatter.png"))
    plt.close()

    print("Visualizations saved.")
    return df

@flow
def data_pipeline():
    df = load_data()
    df = display_summary_stats(df)
    df = check_missing_values(df)
    df = impute_missing(df)
    df = display_data_types(df)
    df = binning(df)
    df = eda_categorical_correlations(df)
    df = encode_categorical(df)
    df = normalize_data(df)
    df = eda_correlations(df)
    df = feature_importance(df)
    df = visualizations(df)

if __name__ == "__main__":
    data_pipeline()