variable "environment" {
  type        = string
  description = "Deployment environment for this artifact bucket."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}