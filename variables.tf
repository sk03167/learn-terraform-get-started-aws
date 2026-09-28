variable "db_password" {
  type        = string
  sensitive   = true
  description = "Operational database credential masked from state logs"
}

variable "enable_snowflake" {
  type        = bool
  default     = false # Safely turned off
  description = "Toggle to provision Snowflake databases and warehouses"
}

variable "enable_databricks" {
  type        = bool
  default     = false # Safely turned off
  description = "Toggle to provision Databricks metastores and cluster policies"
}
