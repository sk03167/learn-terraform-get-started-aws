variable "environment" {
  type        = string
  description = "Explicit resource configuration target (dev, staging, prod)."
}

variable "lake_layers" {
  type        = list(string)
  default     = ["bronze", "silver", "gold"] # 👈 ADDED PLATINUM HERE
  description = "Medallion data architecture tiers"
}
