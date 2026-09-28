variable "db_password" {
  type        = string
  sensitive   = true
  description = "Operational database credential masked from state logs"
}

variable "environment" {
  type        = string
  description = "Deployment target: dev, staging, or prod."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}