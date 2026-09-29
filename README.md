# 🏛️ Multi-Environment Medallion Data Platform Foundation

This repository is a learning-oriented AWS data-platform foundation. Terraform workspaces isolate state for `dev`, `staging`, and `prod`, while explicit environment files control resource names and configuration.

---

## 📂 Project Repository Anatomy

```text
learn-terraform-get-started-aws/
├── .github/workflows/
│   └── terraform-ci.yml      # CI/CD engine with Git branch-to-workspace auto-mapping
├── environments/             # Explicit dev, staging, and prod input values
├── modules/
│   ├── artifact_bucket/      # Versioned, encrypted Glue code-artifact storage
│   └── data_lake/
│       ├── main.tf           # Loop-driven logic building dynamic storage tiers
│       └── variables.tf      # Modular input configurations
├── .gitignore                # Protects secrets from leaking to GitHub
├── main.tf                   # Secrets, alerts, and environment-specific resource configuration
├── providers.tf              # Provider settings, Remote S3 Backend, and State Locking
├── variables.tf              # Sensitive variable schemas
└── terraform.tfvars          # Local secret values (Never Committed)
```

---

## 🛠️ Code Deep Dive & Operational Rationale

### 1. `providers.tf` (Global Strategy & Remote State Backend)
Defines the shared S3 backend. Workspaces partition its state, while environment `.tfvars` files explicitly set values used by resources.
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "lead-de-global-tfstate-bucket" 
    key            = "data-platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock" 
  }
}

provider "aws" { region = "us-east-1" }
```

### 2. `modules/data_lake/main.tf` (Modular Abstraction Engine)
Eliminates copy-pasted block redundancies. It iterates through the medallion layers and applies public-access blocking, versioning, encryption, and lifecycle protection. Only dev permits forced deletion.
```hcl
resource "aws_s3_bucket" "lake_bucket" {
  for_each      = toset(var.lake_layers)
  bucket        = "lead-de-${var.environment}-${each.value}-data"
  force_destroy = var.environment == "dev"
  tags          = { Environment = var.environment, Layer = each.value, ManagedBy = "Terraform" }
}

resource "aws_s3_bucket_metric" "bucket_metrics" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id
  name     = "EntireBucket"
}
```

### 3. `main.tf` (Explicit Environment Configuration & Alerting)
Uses `var.environment`, supplied by an environment `.tfvars` file, for resource naming. The selected Terraform workspace remains responsible only for state isolation.
```hcl
module "data_lake" {
  source      = "./modules/data_lake"
  environment = var.environment
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.environment}-lakehouse-db-credentials"
  recovery_window_in_days = var.environment == "dev" ? 0 : 7
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({ username = "lakehouse_admin", password = var.db_password })
}

resource "aws_sns_topic" "data_ops_alerts" { name = "${var.environment}-data-ops-alerts" }

resource "aws_cloudwatch_metric_alarm" "gold_data_loss_alarm" {
  alarm_name          = "${var.environment}-gold-bucket-integrity-alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.data_ops_alerts.arn]
  dimensions          = { BucketName = "lead-de-${var.environment}-gold-data", StorageType = "AllStorageTypes" }
}
```

### 4. `.github/workflows/terraform-ci.yml` (GitOps Multi-Branch CI/CD Pipeline)
Automates platform deployment governance using shell-mapping criteria to identify active base branches (`dev`, `staging`, `main`), match them immediately to the correct **Terraform Workspace**, and isolate the infrastructure blast radius:
```yaml
      # Map the active branch to a workspace and matching explicit input file.
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

      - name: Terraform Plan Preview
        run: terraform plan -var-file="environments/${{ env.TARGET_ENV }}.tfvars"
```

### 5. `modules/artifact_bucket` (Deployable Code Storage)
The data-jobs repository builds two deployable pieces: a Python wheel containing
reusable pipeline code and a small Glue entry script. This module creates a
separate bucket for those artifacts instead of mixing them with Bronze/Silver/
Gold data:

```text
lead-de-dev-artifacts
lead-de-staging-artifacts
lead-de-prod-artifacts
```

The bucket blocks public access, enables versioning, uses S3-managed encryption,
and permits `force_destroy` only in `dev`. Its name and ARN are module outputs
so a later GitHub OIDC publishing role can receive access to this one bucket
rather than broad S3 permissions.

---

## 🧭 Infrastructure Learning Path and Decisions

### From implicit workspaces to explicit environment inputs
The first version used `terraform.workspace` both to isolate state and to name
resources. That worked for a small lab, but it made resource configuration
depend on hidden CLI state: the same command could describe a different
environment if the wrong workspace was selected.

The current design separates the concerns:

```text
Terraform workspace  → isolates remote state
environment tfvars    → explicitly selects resource configuration
```

Each environment file sets `environment = "dev"`, `"staging"`, or `"prod"`.
Resources use `var.environment`; workspaces remain in the workflow to keep
their state files separate. This makes a plan reviewable from its command line:

```bash
terraform workspace select dev
terraform plan -var-file=environments/dev.tfvars
```

### Branches are deployment tracks, not merely labels
Terraform CI maps a PR base branch or a direct push to one matching workspace
and `.tfvars` file:

```text
feature PR → dev     → dev workspace + environments/dev.tfvars
dev → staging         → staging workspace + environments/staging.tfvars
staging → main        → prod workspace + environments/prod.tfvars
```

Pull requests run a plan. A merge/direct push to the target track runs the
apply. This is why the Glue artifact bucket was planned on a feature branch,
merged to `dev`, and created by the `dev` deployment pipeline rather than by a
manual apply.

### A source-control lesson: deployed is not the same as merged
While adding the artifact bucket, a plan against `feat/add_vpc` showed
`No changes`: its explicit-environment and VPC configuration had already been
applied to `dev`. The same configuration was missing from `main`, however.

The correct fix was not to deploy the older `main` configuration again. The
branch was first promoted into `main`, then the artifact-bucket feature was
rebased onto that baseline. This preserved a one-to-one relationship between
the deployed state, the approved branch history, and future plans.

### Artifact delivery boundary
The data-jobs repository now lint-tests-builds the Glue script and wheel in CI,
then stores a short-lived GitHub Actions artifact for inspection. This Terraform
repository now provides the dev artifact bucket. The next step is restricted
GitHub OIDC publishing from `main` into immutable Git-SHA paths, followed by a
Glue job that pins an exact published artifact.

### Known backend follow-up
Terraform currently warns that the S3 backend `dynamodb_table` parameter is
deprecated. State locking still works today; a future maintenance change should
migrate the backend to `use_lockfile` after confirming the team no longer needs
the DynamoDB lock table.

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
2. Open a Pull Request targeting **`dev`** ➡️ CI selects the **Dev Workspace** and passes `environments/dev.tfvars` to `terraform plan`.
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
terraform plan -var-file=environments/dev.tfvars

# 3. Heal the environment instantly
terraform apply -var-file=environments/dev.tfvars
```

### 🧼 4. Complete Environment Teardown
To practice sound resource cost optimization controls and prevent running up unexpected cloud utility fees when testing architectures, completely erase temporary environments using the teardown sequence:
```bash
terraform workspace select dev && terraform destroy -var-file=environments/dev.tfvars
terraform workspace select staging && terraform destroy -var-file=environments/staging.tfvars
terraform workspace select prod && terraform destroy -var-file=environments/prod.tfvars
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
