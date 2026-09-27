# 🏛️ Multi-Environment Medallion Data Platform Foundation

This repository contains a production-grade infrastructure blueprint designed to manage a secure, multi-environment Data Lakehouse architecture on AWS. It implements advanced Infrastructure as Code (IaC) principles, dynamic environment workspaces, automated secrets management, proactive alerting, and an integrated multi-branch GitOps CI/CD automation engine.

---

## 📂 Project Repository Anatomy

```text
learn-terraform-get-started-aws/
├── .github/workflows/
│   └── terraform-ci.yml      # CI/CD engine with Git branch-to-workspace auto-mapping
├── modules/
│   └── data_lake/
│       ├── main.tf           # Loop-driven logic building dynamic storage tiers
│       └── variables.tf      # Modular input configurations
├── .gitignore                # Protects secrets from leaking to GitHub
├── main.tf                   # Orchestration blueprint (Secrets, Monitors, dynamic workspace tags)
├── providers.tf              # Provider settings, Remote S3 Backend, and State Locking
├── variables.tf              # Sensitive variable schemas
└── terraform.tfvars          # Local secret values (Never Committed)
```

---

## 🛠️ Code Deep Dive & Operational Rationale

### 1. `providers.tf` (Global Strategy & Remote State Backend)
Defines the structural settings and implements a **Shared Cloud Backend**. By pointing tracking files to S3 and setting up a locking table, this allows collaborative engineering teams to work safely out of a single source of truth without concurrent deployment conflicts.
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "lead-de-global-tfstate-bucket" 
    key            = "data-platform/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock" 
  }
}

provider "aws" { region = "us-east-1" }
```

### 2. `modules/data_lake/main.tf` (Modular Abstraction Engine)
Eliminates copy-pasted block redundancies. It uses dynamic loop operators (`for_each`) to iterate through your medallion layers, implementing condition mappings (such as safety rules where `force_destroy` runs exclusively on non-production targets to shield live enterprise datasets).
```hcl
resource "aws_s3_bucket" "lake_bucket" {
  for_each      = toset(var.lake_layers)
  bucket        = "lead-de-${var.environment}-${each.value}-data"
  force_destroy = var.environment == "prod" ? false : true # Protect prod data at all costs!
  tags          = { Environment = var.environment, Layer = each.value, ManagedBy = "Terraform" }
}

resource "aws_s3_bucket_metric" "bucket_metrics" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id
  name     = "EntireBucket"
}
```

### 3. `main.tf` (Dynamic Workspace Isolation & Alerting)
Leverages the **`terraform.workspace`** parameter to isolate resource naming structures dynamically across platforms. It ensures strict secret isolation using AWS Secrets Manager to vault credentials, and wires up CloudWatch Metric Alarms alongside SNS alerting topics to track Gold layer integrity.
```hcl
module "data_lake" {
  source      = "./modules/data_lake"
  environment = terraform.workspace # Dev, Staging, or Prod mapped at runtime
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${terraform.workspace}-lakehouse-db-credentials"
  recovery_window_in_days = 0 
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({ username = "lakehouse_admin", password = var.db_password })
}

resource "aws_sns_topic" "data_ops_alerts" { name = "${terraform.workspace}-data-ops-alerts" }

resource "aws_cloudwatch_metric_alarm" "gold_data_loss_alarm" {
  alarm_name          = "${terraform.workspace}-gold-bucket-integrity-alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "3600"
  statistic           = "Average"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.data_ops_alerts.arn]
  dimensions          = { BucketName = "lead-de-${terraform.workspace}-gold-data", FilterId = "EntireBucket" }
}
```

### 4. `.github/workflows/terraform-ci.yml` (GitOps Multi-Branch CI/CD Pipeline)
Automates platform deployment governance using shell-mapping criteria to identify active base branches (`dev`, `staging`, `main`), match them immediately to the correct **Terraform Workspace**, and isolate the infrastructure blast radius:
```yaml
      # Automatically maps the active Git branch to the corresponding Terraform Workspace
      - name: Select Active Workspace
        run: |
          if [ "${{ github.base_ref }}" = "main" ] || [ "${{ github.ref }}" = "refs/heads/main" ]; then
            echo "TARGET_ENV=prod" >> $GITHUB_ENV
          elif [ "${{ github.base_ref }}" = "staging" ] || [ "${{ github.ref }}" = "refs/heads/staging" ]; then
            echo "TARGET_ENV=staging" >> $GITHUB_ENV
          else
            echo "TARGET_ENV=dev" >> $GITHUB_ENV
          fi

      - name: Switch Workspace
        run: terraform workspace select ${{ env.TARGET_ENV }} || terraform workspace new ${{ env.TARGET_ENV }}
```

---

## ⚡ The Enterprise Production Lifecycle Playbook

### 🏁 1. Initial State Backend Bootstrapping
Execute these administrative actions via the AWS CLI to provision the remote backend storage components before launching your code modules:
```bash
aws s3api create-bucket --bucket lead-de-global-tfstate-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket lead-de-global-tfstate-bucket --versioning-configuration Status=Enabled
```

### 🔀 2. Multi-Branch Progression Model
To deploy updates securely without configuration drift, code modifications must flow sequentially up the environment branch ladder:
1. Developer cuts a local branch from `dev` (`feat/change-parameters`).
2. Open a Pull Request on GitHub matching **`base: dev`** ➡️ `terraform plan` executes against the **Dev Workspace** to preview structural impact.
3. PR Merge to `dev` triggers `terraform apply` ➡️ updates roll out exclusively onto your Dev cloud assets.
4. Promote verified code from `dev` ➡️ `staging` branch via a new PR, which runs checks against the isolated **Staging Workspace** partition (`env:/staging/...`).
5. Final promotion from `staging` ➡️ `main` releases the fully validated updates cleanly onto the production architecture track.

### 🔬 3. Local Infrastructure Drift Remediation
If an asset is deleted or modified manually outside your pipeline controls via web dashboards, the decentralized state structure instantly captures and patches the drift:
```bash
# 1. Simulate an external deletion event
aws s3 rb s3://lead-de-dev-bronze-data --force

# 2. Audit reality against the code blueprint
terraform workspace select dev
terraform plan  # Identifies that the S3 asset and its metadata metric loops are missing

# 3. Heal the environment instantly
terraform apply -auto-approve # Rebuilds the infrastructure target blocks automatically
```

### 🧼 4. Complete Environment Teardown
To practice sound resource cost optimization controls and prevent running up unexpected cloud utility fees when testing architectures, completely erase temporary environments using the teardown sequence:
```bash
terraform workspace select dev && terraform destroy -auto-approve
terraform workspace select staging && terraform destroy -auto-approve
terraform workspace select prod && terraform destroy -auto-approve
terraform workspace select default
```

---

## 🚀 Future Platform Roadmap & Next Targets

As we scale this foundational architecture into a production-ready enterprise lakehouse, the following milestones represent our next targets:

### 📡 Target 1: Networking & IAM Security Hardening
* **Objective:** Remove the storage endpoints from the public internet entirely.
* **Execution:** Wrap the medallion layers inside an **AWS VPC with Private Subnets**. Set up **S3 VPC Gateway Endpoints** so your compute clusters route data internally without traveling over public transit. Enforce strict **IAM Role Assume Policies** and Service Control Policies (SCPs) to establish ironclad Least Privilege limits.

### ❄️ Target 2: Databricks & Snowflake Native Provider Integration
* **Objective:** Provision actual computing structures, role assignments, and schemas cleanly through code.
* **Execution:** Add the HashiCorp **Databricks and Snowflake Terraform Providers** to our global `providers.tf` configuration blocks. This will allow us to manage cluster policies, Unity Catalog metastores, virtual compute warehouses, access controls (RBAC), and table schemas natively alongside our cloud storage foundation using standard GitOps pipelines.

### 🌪️ Target 3: Orchestration Infrastructure with IaC
* **Objective:** Automate production data workflow pipelines using managed orchestrators.
* **Execution:** Provision an **AWS MWAA (Managed Workflows for Apache Airflow)** instance or a **Prefect Cloud Agent** framework completely via Terraform. This layer will manage the dynamic scheduling, execution dependencies, and pipeline workflows driving data moving across the Gold, Silver, and Bronze storage layers.
