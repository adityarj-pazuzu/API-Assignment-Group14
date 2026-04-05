# Heart Disease Prediction Pipeline

## Overview
This project is a cloud-ready data science and machine learning application for predicting heart disease from patient attributes. It includes:

- a **data pipeline** for ingestion, preprocessing, EDA, reporting, and DataOps scheduling
- a **machine learning pipeline** for model preparation, training, evaluation, and metric logging
- a **Prefect API details script** that retrieves flow and deployment information

**Business problem:** predict whether a patient is likely to have heart disease so healthcare teams can support earlier risk identification.

**Dataset:** `data/heart.csv` with 918 records and the attributes provided in the assignment brief.

## How the Entire Project Works
At a high level, the project runs in four stages:

1. **Data ingestion and preprocessing**: `pipeline/data_pipeline.py` (powered by Pandas and Scikit-learn) loads `data/heart.csv`, checks missing values, imputes numeric features, encodes categorical data, normalizes numeric features, and records summary statistics. This stage ensures data quality and consistency by cleaning raw patient records and preparing them for machine learning. The processed dataset is exported as `deployment/heart_processed.csv` for reproducibility and audit trails.

2. **EDA and reporting**: the same data pipeline (using Matplotlib and Seaborn) computes correlations, age binning, categorical cross-tabs, feature importance, and saves charts plus a structured JSON report into `deployment/`. This stage uncovers data patterns, identifies feature relationships, and generates visual insights (histograms and scatter plots) that guide feature selection. A comprehensive JSON report documents all statistics, distributions, and correlations for stakeholder review.

3. **Model training and monitoring**: `pipeline/ml_pipeline.py` (powered by Scikit-learn and MLflow) trains Logistic Regression and Random Forest models, evaluates them on a 70/30 split, logs metrics to MLflow, and saves the best model into `models/`. MLflow automatically tracks hyperparameters, metrics (accuracy, precision, recall, F1), and artifacts for each experiment run, enabling comparison and reproducibility. The winning model is persisted as a serialized pickle file for deployment.

4. **Serving and application access**: `api_details.py` (powered by Prefect's Python client) uses Prefect's built-in APIs to retrieve and display flow and deployment metadata such as flow counts, deployment IDs, and execution history. This stage provides DataOps visibility and governance by exposing orchestration details through a programmatic interface, allowing teams to monitor pipeline health and scheduling status without manual dashboard checks.

In the cloud deployment, Prefect runs the data pipeline on a **3-minute schedule** and MLflow stores model metrics.

## Repository Structure
```text
API-Assignment-Group14/
├── README.md
├── requirements.txt
├── data/
│   └── heart.csv
├── deployment/
│   ├── .gitkeep
│   ├── Age_hist.png
│   ├── Cholesterol_hist.png
│   ├── FastingBS_hist.png
│   ├── MaxHR_hist.png
│   ├── RestingBP_hist.png
│   ├── age_chol_scatter.png
│   ├── data_pipeline_report.json
│   └── heart_processed.csv
├── models/
│   ├── .gitkeep
│   ├── metrics_report.json
│   └── model.pkl
├── pipeline/
│   ├── data_pipeline.py
│   └── ml_pipeline.py
├── api_details.py
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── README.md
```

## Technology Stack
- Python
- Pandas, NumPy
- Scikit-learn
- Matplotlib, Seaborn
- Prefect
- MLflow

## Local Setup
1. Create a virtual environment.
2. Activate it.
3. Install dependencies.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## How to Run the Project Locally

### 1. Run the data pipeline
This performs ingestion, preprocessing, EDA, feature analysis, visualization, and artifact generation.

```bash
python3 pipeline/data_pipeline.py
```

Generated outputs:
- `deployment/heart_processed.csv`
- `deployment/data_pipeline_report.json`
- `deployment/Age_hist.png`
- `deployment/Cholesterol_hist.png`
- `deployment/FastingBS_hist.png`
- `deployment/MaxHR_hist.png`
- `deployment/RestingBP_hist.png`
- `deployment/age_chol_scatter.png`

### 2. Run the machine learning pipeline
This trains two classification models, evaluates them, logs metrics to MLflow, and stores the best model.

```bash
python3 pipeline/ml_pipeline.py
```

Generated outputs:
- `models/model.pkl`
- `models/metrics_report.json`
- MLflow tracking data in `mlruns/`
- MLflow local metadata database in `mlflow.db`

### 3. Start the supporting services
Start Prefect so the flow and deployment can be monitored from a dashboard.

```bash
prefect server start --host 127.0.0.1 --port 4200
```

In a second terminal, register and serve the scheduled data pipeline every 3 minutes.

```bash
source .venv/bin/activate
PREFECT_API_URL=http://127.0.0.1:4200/api python3 pipeline/data_pipeline.py --serve
```

Optional: start MLflow UI.

```bash
mlflow ui --host 127.0.0.1 --port 5000
```

Where to view the dashboards locally:
- Prefect dashboard: `http://127.0.0.1:4200`
- MLflow UI: `http://127.0.0.1:5000`

### 4. Retrieve application details through APIs
This script uses Prefect's built-in client APIs to retrieve application metadata.

```bash
PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py
```

The script displays at least two application details such as:
- flow count
- deployment count
- flow ID and flow name
- deployment ID and deployment name

## Where Each Output Can Be Found

| Output | Location |
|---|---|
| Raw dataset | `data/heart.csv` |
| Processed dataset from the data pipeline | `deployment/heart_processed.csv` |
| Data pipeline report with summary stats, dtypes, correlations, categorical analysis, and feature importance | `deployment/data_pipeline_report.json` |
| Univariate histogram for `Age` | `deployment/Age_hist.png` |
| Univariate histogram for `Cholesterol` | `deployment/Cholesterol_hist.png` |
| Univariate histogram for `FastingBS` | `deployment/FastingBS_hist.png` |
| Univariate histogram for `MaxHR` | `deployment/MaxHR_hist.png` |
| Univariate histogram for `RestingBP` | `deployment/RestingBP_hist.png` |
| Bivariate scatter plot | `deployment/age_chol_scatter.png` |
| Saved best trained model | `models/model.pkl` |
| Evaluation metrics for both trained models | `models/metrics_report.json` |
| MLflow experiment files | `mlruns/` |
| MLflow local metadata DB | `mlflow.db` |
| Prefect flow and deployment details script | `api_details.py` |
| Local Prefect dashboard | `http://127.0.0.1:4200` |
| Local MLflow UI | `http://127.0.0.1:5000` |

## Cloud Execution Guide

To run the application on a cloud or on-premises Linux machine:

**[→ See Rocky Linux Deployment Guide](ROCKY_LINUX_DEPLOYMENT.md)** — Complete step-by-step instructions for Rocky Linux, CentOS, or any RHEL-based system with automated and manual deployment options.

### Cloud Architecture

The application runs on a single Linux VM with three persistent services:

- **Prefect Server** (port 4200) — Orchestration engine and dashboard for monitoring
- **Data Pipeline Service** — Scheduled every 3 minutes via Prefect
- **MLflow UI** (port 5000) — Model metrics tracking and visualization

### Quick Cloud Deployment

For automated setup on Rocky Linux:

```bash
sudo bash setup_rocky_linux.sh
```

This handles all installation, configuration, and service startup automatically (~10-15 minutes total).

For step-by-step manual deployment, see [ROCKY_LINUX_DEPLOYMENT.md](ROCKY_LINUX_DEPLOYMENT.md).

### Access Cloud Dashboards

After deployment completes:

- **Prefect Dashboard:** http://<instance-ip>:4200
- **MLflow UI:** http://<instance-ip>:5000

### Verify Cloud Deployment

```bash
# SSH into your cloud instance
ssh user@instance-ip

# Verify services are running
sudo systemctl status prefect-server.service data-pipeline.service mlflow-ui.service

# Retrieve application details via Prefect APIs
cd /opt/heart-disease-ml
source venv/bin/activate
PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py
```

### Monitor Cloud Pipelines

```bash
# View live Prefect server logs
sudo journalctl -u prefect-server.service -f

# View scheduled pipeline execution
sudo journalctl -u data-pipeline.service -f

# View MLflow server logs
sudo journalctl -u mlflow-ui.service -f
```

### Cloud Artifacts

After deployment, you will see:

- **Prefect Dashboard** showing the `heart-dataops-3min` deployment with 3-minute runs
- **MLflow Dashboard** showing both trained models and their metrics
- **Generated data artifacts** in `/opt/heart-disease-ml/deployment/`
- **Generated model artifacts** in `/opt/heart-disease-ml/models/`

## How the Project Satisfies Each Assignment Objective

### Sub-Objective 1: Design and Development of a Data Pipeline

| Requirement | How it is satisfied | Evidence |
|---|---|---|
| 1.1 Business Understanding | The project predicts heart disease risk from patient clinical attributes. | `README.md`, `pipeline/data_pipeline.py` |
| 1.2 Data Ingestion | The dataset is loaded from `data/heart.csv` using Pandas. | `pipeline/data_pipeline.py` -> `load_data()` |
| 1.3 Data Pre-processing | The pipeline computes summary statistics, checks missing values, imputes numeric feature columns, records data types, encodes features, and normalizes numeric columns. | `display_summary_stats()`, `check_missing_values()`, `impute_missing()`, `display_data_types()`, `encode_categorical()`, `normalize_data()`, `deployment/data_pipeline_report.json` |
| 1.4 Exploratory Data Analysis | The pipeline computes numeric correlations, categorical cross-tabs, age binning, feature importance, and visualization outputs for univariate and bivariate analysis. | `eda_correlations()`, `eda_categorical_correlations()`, `binning()`, `feature_importance()`, `visualizations()`, `deployment/*.png` |
| 1.5 DataOps | The Prefect flow automates preprocessing and EDA, can be served on a 3-minute interval, logs activity, and is visible through the Prefect dashboard. | `@flow data_pipeline`, `python3 pipeline/data_pipeline.py --serve`, Prefect dashboard on port `4200` |

### Sub-Objective 2: Design and Development of a Machine Learning Pipeline

| Requirement | How it is satisfied | Evidence |
|---|---|---|
| 2.1 Model Preparation | Two classification algorithms were selected: Logistic Regression and Random Forest. | `pipeline/ml_pipeline.py` -> `candidates` |
| 2.2 Model Training | The data is split using 70% training and 30% testing before model fitting. | `train_test_split(..., test_size=0.3, ...)` |
| 2.3 Model Evaluation | Models are evaluated with accuracy and additional classification metrics. | `accuracy_score`, `precision_score`, `recall_score`, `f1_score`, `models/metrics_report.json` |
| 2.4 MLOps | MLflow logs at least four metrics per run and stores experiment history for monitoring. | `mlflow.log_metrics(...)`, `mlruns/`, `mlflow.db` |

### Sub-Objective 3: API Access

| Requirement | How it is satisfied | Evidence |
|---|---|---|
| 3.1 Retrieve Key Application Details | The project uses Prefect's built-in client APIs to retrieve flow and deployment metadata. | `api_details.py` |
| 3.2 Display Application Details | The script prints flow count, deployment count, flow ID/name, and deployment ID/name. | `api_details.py` output |

## Key Generated Artifacts
- `deployment/heart_processed.csv`: processed dataset output from the data pipeline
- `deployment/data_pipeline_report.json`: structured preprocessing and EDA report
- `deployment/*.png`: EDA charts
- `models/model.pkl`: best trained model pipeline used by the API
- `models/metrics_report.json`: evaluation metrics for both candidate models

## Verified Local Results
The current project state has been executed successfully with:
- `python3 pipeline/data_pipeline.py`
- `python3 pipeline/ml_pipeline.py`
- `PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py`

Observed model metrics from `models/metrics_report.json`:
- Logistic Regression accuracy: `0.8841`
- Random Forest accuracy: `0.9022`

## Submission Notes
For the assignment demo, the simplest way to satisfy the cloud requirement is:
1. deploy this repository to a cloud VM using Terraform
2. start Prefect server
3. serve the data pipeline every 3 minutes
4. start MLflow UI
5. run `api_details.py`
6. show the dashboards, logs, metrics, and generated artifacts
