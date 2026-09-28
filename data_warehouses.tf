# data_warehouses.tf

# ==========================================
# SNOWFLAKE TRACK
# ==========================================
resource "snowflake_database" "medallion_db" {
  count   = var.enable_snowflake ? 1 : 0
  name    = "${upper(terraform.workspace)}_MEDALLION_DB"
  comment = "Database storing data platform tables managed via Terraform"
}

resource "snowflake_warehouse" "compute_wh" {
  count          = var.enable_snowflake ? 1 : 0
  name           = "${upper(terraform.workspace)}_COMPUTE_WH"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
}

# ==========================================
# DATABRICKS TRACK
# ==========================================
resource "databricks_cluster_policy" "fair_share_policy" {
  count = var.enable_databricks ? 1 : 0
  name  = "${terraform.workspace}-data-science-policy"
  definition = jsonencode({
    "spark_version" : { "type" : "fixed", "value" : "auto" },
    "node_type_id" : { "type" : "enum", "values" : ["m5.xlarge", "r5.xlarge"] }
  })
}
