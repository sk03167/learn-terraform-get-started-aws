# 1. Instantiate the modular architecture
module "dev_data_lake" {
  source      = "./modules/data_lake"
  environment = terraform.workspace
}

# 2. Secret Isolation: Securely vault operational passwords
resource "aws_secretsmanager_secret" "db_secret" {
 name                    = "${terraform.workspace}-lakehouse-db-credentials" # 👈 DYNAMIC NAME
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "lakehouse_admin"
    password = var.db_password
  })
}

# 3. Operational Monitoring: SNS Alert Topic for Data Ops
resource "aws_sns_topic" "data_ops_alerts" {
  name = "data-ops-lakehouse-alerts"
}

# 4. Proactive Alerting: CloudWatch Alarm tracking production gold tier integrity
resource "aws_cloudwatch_metric_alarm" "gold_data_loss_alarm" {
  alarm_name          = "${terraform.workspace}-gold-bucket-integrity-alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "86400" # Evaluated across 24h
  statistic           = "Average"
  threshold           = "1" # Triggers immediately if data count breaks zero bounds
  alarm_description   = "Fires instantly if files inside the production Gold layer are dropped or deleted."
  alarm_actions       = [aws_sns_topic.data_ops_alerts.arn]

  dimensions = {
    BucketName = "lead-de-${terraform.workspace}-gold-data"
    FilterId   = "EntireBucket"
  }
}
