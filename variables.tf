variable "db_password" {
  type        = string
  sensitive   = true
  nullable    = true
  default     = null
  description = "Optional lab secret. Set through TF_VAR_db_password, never a committed tfvars file."
}

variable "alert_email_addresses" {
  type        = set(string)
  default     = []
  description = "Optional confirmed email recipients for data-operations alerts."
}

variable "gold_minimum_object_count" {
  type        = number
  default     = 1
  description = "Alert when daily Gold object count drops below this value."
}

variable "environment" {
  type        = string
  description = "Deployment target: dev, staging, or prod."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
