# 1. Instantiate the modular architecture
module "data_lake" {
  source      = "./modules/data_lake"
  environment = var.environment
}

# 2. Secret Isolation: Securely vault operational passwords
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.environment}-lakehouse-db-credentials" # 👈 DYNAMIC NAME
  recovery_window_in_days = var.environment == "dev" ? 0 : 7
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  count     = var.db_password == null ? 0 : 1
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "lakehouse_admin"
    password = var.db_password
  })
}

# 3. Operational Monitoring: SNS Alert Topic for Data Ops
resource "aws_sns_topic" "data_ops_alerts" {
  name = "${var.environment}-data-ops-lakehouse-alerts"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  for_each  = var.alert_email_addresses
  topic_arn = aws_sns_topic.data_ops_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# 4. Proactive Alerting: CloudWatch Alarm tracking production gold tier integrity
resource "aws_cloudwatch_metric_alarm" "gold_data_loss_alarm" {
  alarm_name          = "${var.environment}-gold-bucket-integrity-alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = 86400 # S3 storage metrics are emitted daily.
  statistic           = "Average"
  threshold           = var.gold_minimum_object_count
  alarm_description   = "Fires instantly if files inside the production Gold layer are dropped or deleted."
  alarm_actions       = [aws_sns_topic.data_ops_alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    BucketName  = "lead-de-${var.environment}-gold-data"
    StorageType = "AllStorageTypes"
  }
}
