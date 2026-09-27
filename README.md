# 🏛️ Multi-Environment Medallion Data Platform Foundation

This repository contains a production-grade infrastructure blueprint designed to manage a secure, multi-environment Data Lakehouse architecture on AWS. It implements advanced Infrastructure as Code (IaC) principles, state isolation, automated alerting, and an integrated CI/CD GitOps workflow.

---

## 📂 Project Repository Anatomy

```text
learn-terraform-get-started-aws/
├── .github/workflows/
│   └── terraform-ci.yml      # CI/CD engine automating validations and merges
├── modules/
│   └── data_lake/
│       ├── main.tf           # Loop-driven logic building storage tiers
│       └── variables.tf      # Modular input configurations
├── .gitignore                # Protects secrets from leaking to GitHub
├── main.tf                   # Orchestration blueprint (Secrets, Monitors)
├── providers.tf              # Engine core settings and S3 Remote Backend
├── variables.tf              # Sensitive database credential schemas
└── terraform.tfvars          # Local variable injection rules (Never Committed)
```

---

## 🛠️ Code Deep Dive & Operational Rationale

### 1. `providers.tf` (Global Strategy & Remote State Backend)
Defines the structural settings and implements a **Shared Cloud Backend**. By pointing tracking files to S3 and setting up distributed state structures, this allows a collaborative engineering team to work safely out of a centralized state file while preventing concurrent pipeline overlap.
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
Eliminates copy-pasted blocks. It uses dynamic loop operators (`for_each`) to iterate through your medallion layers, implementing condition mappings (such as safety rules where `force_destroy` runs exclusively on `dev` targets to shield live production files).
```hcl
resource "aws_s3_bucket" "lake_bucket" {
  for_each      = toset(var.lake_layers)
  bucket        = "lead-de-${var.environment}-${each.value}-data"
  force_destroy = var.environment == "dev" ? true : false
  tags          = { Environment = var.environment, Layer = each.value, ManagedBy = "Terraform" }
}

resource "aws_s3_bucket_metric" "bucket_metrics" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id
  name     = "EntireBucket"
}
```

### 3. `main.tf` (Secrets Management & Proactive Alerting)
Ensures full **Secret Isolation** using AWS Secrets Manager to vault database passphrases securely so plain text variables never print to clear text console screens. Concurrently, it configures live platform monitoring and an SNS notification topic to alert data ops teams immediately if unexpected objects are deleted from the production **Gold** tier.
```hcl
module "dev_data_lake" {
  source      = "./modules/data_lake"
  environment = "dev"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "dev-lakehouse-db-credentials"
  recovery_window_in_days = 0 
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({ username = "lakehouse_admin", password = var.db_password })
}

resource "aws_sns_topic" "data_ops_alerts" { name = "data-ops-lakehouse-alerts" }

resource "aws_cloudwatch_metric_alarm" "gold_data_loss_alarm" {
  alarm_name          = "prod-gold-bucket-integrity-alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.data_ops_alerts.arn]
  dimensions          = { BucketName = "lead-de-dev-gold-data", FilterId = "EntireBucket" }
}
```

### 4. `.github/workflows/terraform-ci.yml` (GitOps Automation Pipeline)
Implements target pipeline triggers based on team actions:
* **Pull Request Open:** Automates style rules (`terraform fmt`), tests structural integrity (`terraform validate`), and compiles a blueprint preview (`terraform plan`) so the architecture can be verified inside the code review dashboard **without changing cloud resources**.
* **Main Branch Merge Push:** Evaluates branch target validation conditions to execute live deployment pipelines (`terraform apply`) seamlessly.
```yaml
# Simplified conditional execution logic snippet
- name: Preview Infrastructure Impact (Plan)
  if: github.event_name == 'pull_request'
  run: terraform plan -no-color

- name: Execute Verified Deployments (Apply)
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: terraform apply -auto-approve -no-color
```

---

## ⚡ The Production Lifecycle Playbook

### 🏁 1. Bootstrapping the Backend Storage
Before initializing code modules, execute the administrative steps via terminal to establish the cloud-side tracking system:
```bash
aws s3api create-bucket --bucket lead-de-global-tfstate-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket lead-de-global-tfstate-bucket --versioning-configuration Status=Enabled
```

### 🔁 2. Core Initializations
```bash
terraform init -migrate-state  # Centralizes your local records up into the cloud S3 bucket
terraform fmt -recursive       # Sweeps the project to enforce tidy indentation standards
```

### 🔬 3. Simulating Infrastructure Drift Recovery
If a developer bypasses your code pipeline and manually deletes an asset out-of-band via console, Terraform tracks down the variance:
```bash
# 1. Simulate an external deletion
aws s3 rb s3://lead-de-dev-bronze-data --force

# 2. Trace the imbalance
terraform plan  # Identifies that a bucket and its attached metrics are missing from the cloud

# 3. Heal the framework instantly
terraform apply -auto-approve # Rebuilds the missing assets, restoring environment alignment
```

### 🧼 4. Complete Environment Teardown
To practice sound platform governance and prevent unexpected charges when testing design frameworks, clean up resources using the complete teardown operator:
```bash
terraform destroy -auto-approve
```
