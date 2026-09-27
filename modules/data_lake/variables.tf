variable "environment" {
  type        = string
  description = "Target deployment workspace (dev, staging, prod)"
}

variable "lake_layers" {
  type        = list(string)
  default     = ["bronze", "silver", "gold"]
  description = "Medallion data architecture tiers"
}
