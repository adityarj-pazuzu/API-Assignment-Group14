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

1. **Data ingestion and preprocessing**: `pipeline/data_pipeline.py` loads `data/heart.csv`, checks missing values, imputes numeric features, encodes categorical data, normalizes numeric features, and records summary statistics.
2. **EDA and reporting**: the same data pipeline computes correlations, age binning, categorical cross-tabs, feature importance, and saves charts plus a structured JSON report into `deployment/`.
3. **Model training and monitoring**: `pipeline/ml_pipeline.py` trains Logistic Regression and Random Forest models, evaluates them on a 70/30 split, logs metrics to MLflow, and saves the best model into `models/`.
4. **Serving and application access**: `api_details.py` uses Prefect APIs to display flow and deployment information for DataOps evidence.

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
To satisfy the assignment's cloud requirement, run the application on an **AWS EC2 instance**.

Two approaches are documented:

| Approach | When to use |
|---|---|
| **Terraform (automated)** — [`terraform/README.md`](terraform/README.md) | Recommended. One `terraform apply` command provisions the EC2 instance, security group, IAM role, and starts all services automatically. |
| **AWS CLI (manual)** — steps below | Use if you prefer to provision infrastructure step-by-step from the command line without Terraform. |

For the automated path, go to [`terraform/README.md`](terraform/README.md) first.

Below is the concrete **manual AWS CLI** workflow.

### Cloud architecture used for the assignment
- one Linux VM instance
- Prefect server for orchestration and dashboard
- scheduled Prefect-served data pipeline every 3 minutes
- MLflow UI for model monitoring

### Recommended EC2 setup
- OS: Ubuntu 22.04 LTS or Debian 12
- Instance type: `t2.micro` or larger
- Open inbound ports:
  - `22` for SSH
  - `4200` for Prefect dashboard
  - `5000` for MLflow UI

### AWS CLI commands to bring up the required infrastructure
If you want to provision the minimum infrastructure from the command line instead of the AWS Console, the following AWS CLI workflow creates:

- one EC2 instance
- one security group
- inbound access for SSH, Prefect, and MLflow

Before running these commands, make sure the AWS CLI is installed and configured:

```bash
aws configure
```

Also make sure you already have an EC2 key pair in your AWS account. Use its name in `KEY_NAME` and keep the matching `.pem` file locally for SSH.

Set the variables for your account and network. Replace the placeholder values with your own:

```bash
export AWS_REGION="us-east-1"
export VPC_ID="vpc-xxxxxxxx"
export SUBNET_ID="subnet-xxxxxxxx"
export KEY_NAME="your-keypair-name"
export MY_IP_CIDR="203.0.113.10/32"
export AMI_ID=$(aws ssm get-parameter \
  --region "$AWS_REGION" \
  --name "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp3/ami-id" \
  --query 'Parameter.Value' \
  --output text)
```

Create a security group:

```bash
export SG_ID=$(aws ec2 create-security-group \
  --region "$AWS_REGION" \
  --group-name "heart-disease-ml-sg" \
  --description "Security group for heart disease ML assignment" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)
```

Allow inbound traffic. The example below restricts access to your current public IP range for safer demos:

```bash
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP_CIDR"
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" --protocol tcp --port 4200 --cidr "$MY_IP_CIDR"
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" --protocol tcp --port 5000 --cidr "$MY_IP_CIDR"
```

Launch the EC2 instance:

```bash
export INSTANCE_ID=$(aws ec2 run-instances \
  --region "$AWS_REGION" \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --key-name "$KEY_NAME" \
  --network-interfaces "AssociatePublicIpAddress=true,DeviceIndex=0,SubnetId=$SUBNET_ID,Groups=$SG_ID" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Heart-Disease-Pipeline}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
```

Wait for the instance to become available and fetch its public IP:

```bash
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-status-ok --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
export PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
echo "$PUBLIC_IP"
```

Connect to the server:

```bash
ssh -i /path/to/your-key.pem ubuntu@"$PUBLIC_IP"
```

If your AMI uses a different default SSH user, adjust the username accordingly. After login, continue with the application setup commands in the next section.

### Optional cleanup commands
When you are done with the demo, you can remove the instance and security group:

```bash
aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$SG_ID"
```

### Cloud deployment steps
SSH into the VM and run the install and training steps first:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git
git clone <your-repository-url>
cd API-Assignment-Group14
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
python3 pipeline/ml_pipeline.py
```

> **Important — keep dashboards alive for screenshots:** do **not** start Prefect server in the foreground and then try to open a second terminal for the pipeline. If your SSH session closes, all foreground processes die and every dashboard disappears. Use `nohup` so all services stay alive after you disconnect.

Start all services persistently in the background with a single block:

```bash
cd API-Assignment-Group14
source .venv/bin/activate

# 1. Start Prefect server — dashboard available at port 4200
nohup prefect server start --host 0.0.0.0 --port 4200 > prefect.log 2>&1 &

# 2. Wait 20 seconds for the server to finish starting before registering the deployment
sleep 20

# 3. Register and serve the 3-minute scheduled data pipeline
nohup env PREFECT_API_URL=http://127.0.0.1:4200/api \
  python3 pipeline/data_pipeline.py --serve > dataops.log 2>&1 &

# 4. Start MLflow UI — dashboard available at port 5000
nohup mlflow ui --host 0.0.0.0 --port 5000 > mlflow.log 2>&1 &

echo "All services started."
sleep 5
ss -tlnp | grep -E '4200|5000'
```

You can now safely close the SSH session. All services remain running and the dashboards stay accessible at their public URLs for screenshots.

Print Prefect application details while still SSH'd in:

```bash
PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py
```

Check on any service log at any time:

```bash
tail -f prefect.log    # Prefect server — shows startup and heartbeat output
tail -f dataops.log    # Scheduled pipeline run history — new entry every 3 minutes
tail -f mlflow.log     # MLflow UI server output
```

If a service stops and needs restarting:

```bash
cd API-Assignment-Group14
source .venv/bin/activate
# Restart any stopped service — example for Prefect
nohup prefect server start --host 0.0.0.0 --port 4200 > prefect.log 2>&1 &
```

### What to show on the cloud dashboard for the assignment
To demonstrate the assignment objectives on cloud, show the following:
- Prefect dashboard with the `heart-dataops-3min` deployment
- recent flow runs and logs every 3 minutes
- MLflow UI with the logged evaluation metrics for both models
- `api_details.py` output showing flow and deployment metadata

Where to find these on the cloud VM after startup:
- Prefect dashboard: `http://<PUBLIC_IP>:4200`
- MLflow UI: `http://<PUBLIC_IP>:5000`
- generated data artifacts: inside the cloned repo under `deployment/`
- generated model artifacts: inside the cloned repo under `models/`

## Airflow vs Prefect — Dashboard Availability on AWS

### Short answer
Neither Prefect nor Apache Airflow provides a dashboard that is automatically hosted and managed by AWS out of the box. Both require you to run the web server process yourself on the VM, exactly as this project does with `nohup prefect server start`.

The only way to get a fully managed dashboard directly from AWS is to use **Amazon MWAA (Managed Workflows for Apache Airflow)**, which is a paid managed service.

### Detailed comparison

| Feature | Prefect (current project) | Airflow self-hosted on EC2 | AWS MWAA (managed Airflow) |
|---|---|---|---|
| Dashboard availability | You run the server on EC2 with `nohup` — accessible at `http://<EC2_IP>:4200` | You run `airflow webserver` on EC2 with `nohup` — accessible at `http://<EC2_IP>:8080` | AWS provides the URL automatically from the Console |
| Stays alive after SSH disconnect | Yes, with `nohup` as documented above | Yes, with `nohup` | Always on — managed by AWS |
| Cost | EC2 instance cost only (`t2.micro` is free tier eligible) | EC2 instance cost only | Approximately $350/month minimum for `mw1.small` |
| Setup effort | Low — already working in this project | Medium — requires rewriting all pipelines as Airflow DAGs | Medium-high — requires DAGs plus S3 bucket for DAG storage and MWAA environment setup |
| Code changes needed from current project | None | Full rewrite of `data_pipeline.py` and `ml_pipeline.py` as Airflow DAGs | Full rewrite plus S3 upload of DAGs |
| 3-minute schedule support | Built-in via `data_pipeline.serve(interval=180)` | Yes, via `schedule_interval` in a DAG | Yes, via DAG schedule |
| Dashboard visible in browser from laptop | Yes, via public IP and security group port | Yes, via public IP and security group port | Yes, via the MWAA Console URL |

### Recommendation for this assignment
**Keep Prefect.** It is already working, the 3-minute scheduling is registered and running, and the dashboard is accessible at the EC2 public IP once the server is started with `nohup` as documented in the Cloud Deployment Steps above. Switching to Airflow would require rewriting all pipeline code and provides no grading advantage.

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
