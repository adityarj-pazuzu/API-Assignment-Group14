# API Assignment 1: Heart Disease Prediction Pipeline

## Overview
This project implements a complete data science and machine learning pipeline for predicting heart disease risk using patient data. It covers data ingestion, preprocessing, exploratory data analysis (EDA), model training, evaluation, and deployment via APIs.

**Business Problem**: Predict heart disease based on patient attributes to enable early diagnosis and treatment.

**Dataset**: `heart.csv` (918 records) from Kaggle, containing features like Age, Sex, ChestPainType, RestingBP, Cholesterol, etc.

## Project Structure
```
API-Assignment-1/
├── README.md
├── requirements.txt
├── api/
│   ├── app.py                 # FastAPI for predictions
│   └── __pycache__/
├── data/
│   └── heart.csv              # Dataset
├── deployment/
│   ├── age_chol_scatter.png   # Bivariate plot
│   ├── Age_hist.png           # Univariate histograms
│   ├── Cholesterol_hist.png
│   ├── FastingBS_hist.png
│   ├── MaxHR_hist.png
│   └── RestingBP_hist.png
├── models/
│   └── model.pkl              # Trained model
├── mlruns/                    # MLflow logs
├── pipeline/
│   ├── data_pipeline.py       # Data preprocessing and EDA pipeline
│   └── ml_pipeline.py         # ML training and evaluation pipeline
└── api_details.py             # Script to retrieve Prefect flow/deployment details
```

## Installation
1. Clone or navigate to the project directory.
2. Create a virtual environment: `python -m venv .venv`
3. Activate it: `.venv\Scripts\activate` (Windows)
4. Install dependencies: `pip install -r requirements.txt`

## Usage

### 1. Data Pipeline (Preprocessing and EDA)
Run the data pipeline to perform preprocessing and EDA:
```bash
python pipeline/data_pipeline.py
```
- Outputs: Summary stats, missing values, data types, correlations, binning, feature importance, visualizations saved to `deployment/`.

### 2. ML Pipeline (Model Training)
Train and evaluate models:
```bash
python pipeline/ml_pipeline.py
```
- Trains Logistic Regression and Random Forest.
- Evaluates with accuracy, precision, recall, F1 score.
- Logs metrics to MLflow.

### 3. View Results
- **Console Logs**: Printed during pipeline runs.
- **Visualizations**: Open PNG files in `deployment/`.
- **MLflow UI**: `mlflow ui` → http://127.0.0.1:5000 (view metrics and models).
- **Prefect Dashboard**: `prefect orion start` → http://127.0.0.1:4200 (view pipeline runs and logs).
- **API Details**: `python api_details.py` (retrieves flow/deployment info via Prefect APIs).

### 4. Prediction API
Start the FastAPI server:
```bash
uvicorn api.app:app --reload
```
- Access at http://127.0.0.1:8000
- Interactive docs: http://127.0.0.1:8000/docs
- Predict heart disease:
  ```bash
  curl -X POST "http://127.0.0.1:8000/predict" \
       -H "Content-Type: application/json" \
       -d '{"Age": 50, "Sex": "M", "ChestPainType": "ATA", "RestingBP": 130, "Cholesterol": 200, "FastingBS": 0, "RestingECG": "Normal", "MaxHR": 150, "ExerciseAngina": "N", "Oldpeak": 1.0, "ST_Slope": "Up"}'
  ```
  Response: `{"prediction": 0}` (0 = No disease, 1 = Disease)

## Sub-Objectives Completed

### Sub-Objective 1: Data Pipeline (6 marks)
- 1.1 Business Understanding: Predict heart disease.
- 1.2 Data Ingestion: Loaded `heart.csv`.
- 1.3 Preprocessing: Stats, missing check, imputation, types, normalization.
- 1.4 EDA: Correlations, binning, encoding, importance, visualizations.
- 1.5 DataOps: Prefect pipeline with logging; schedule via deployment.

### Sub-Objective 2: ML Pipeline (4 marks)
- 2.1 Algorithms: Logistic Regression, Random Forest.
- 2.2 Training: 70% train / 30% test.
- 2.3 Evaluation: Accuracy metric.
- 2.4 MLOps: Logged 4+ metrics with MLflow.

### Sub-Objective 3: API Access (2 marks)
- 3.1 Retrieve Details: Used Prefect APIs for flows/deployments.
- 3.2 Display Details: Printed flow ID/Name and deployment info.

## Technologies Used
- Python, Pandas, Scikit-learn, Matplotlib, Seaborn
- Prefect (pipelines and orchestration)
- MLflow (model tracking)
- FastAPI (prediction API)

## Notes
- Ensure Prefect Orion and MLflow UI are running for dashboards.
- Visualizations are saved as PNGs.
- Model is pickled for API use.

## Cloud Deployment on AWS

### Option 1: Manual Deployment
1. Go to AWS EC2 Console > Launch Instance.
2. Choose Amazon Linux 2 or Ubuntu AMI.
3. Select t2.micro (free tier) or larger.
4. Configure security group: Allow SSH (22), HTTP (80), HTTPS (443), Custom TCP (4200 for Prefect, 5000 for MLflow, 8000 for FastAPI).
5. Launch and connect via SSH: `ssh -i your-key.pem ec2-user@public-ip`
6. Install dependencies: `sudo yum update -y; sudo yum install -y python3.11 python3.11-pip git`
7. Clone repo, create venv, install reqs, run pipelines, start services, set up cron as in the manual steps above.

### Option 2: Terraform Deployment (Automated)
Use Terraform to provision AWS resources automatically.

#### Prerequisites
- Install Terraform: https://www.terraform.io/downloads
- AWS CLI configured with credentials: `aws configure`
- SSH key pair created in AWS.

#### Steps
1. **Clone/Update Repo**:
   ```bash
   cd API-Assignment-1
   ```

2. **Update Variables**:
   - Edit `variables.tf` to set your `key_name`, `s3_bucket_name`, etc.
   - Update `main.tf` user_data with your actual GitHub repo URL.

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Plan Deployment**:
   ```bash
   terraform plan
   ```

5. **Apply Deployment**:
   ```bash
   terraform apply
   ```
   - Confirm with `yes`.
   - This creates EC2 instance, security group, S3 bucket, IAM role, and runs user data script.

6. **Get Outputs**:
   ```bash
   terraform output
   ```
   - Provides public IP and URLs for dashboards/API.

7. **Access Services**:
   - SSH: `ssh -i your-key.pem ec2-user@<public-ip>`
   - Prefect: http://<public-ip>:4200
   - MLflow: http://<public-ip>:5000
   - FastAPI: http://<public-ip>:8000

8. **Destroy Resources** (when done):
   ```bash
   terraform destroy
   ```

#### Resources Created
- EC2 instance with auto-setup via user data.
- Security group for required ports.
- S3 bucket for model/data backups.
- IAM role for S3 access.

#### Notes
- User data script installs dependencies, runs pipelines, starts services, and sets up cron for 3-minute scheduling.
- Monitor costs; use free tier where possible.
- For production, add VPC, subnets, etc., in Terraform.
