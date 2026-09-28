variable "db_password" {
  type        = string
  sensitive   = true
  description = "Operational database credential masked from state logs"
}