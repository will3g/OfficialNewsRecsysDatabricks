# Plataforma de QA e PROD como código: o schema e o Volume onde o Job grava.
# O Job em si (notebooks + tasks) é do Asset Bundle, igual nos 3 ambientes.
# Roda no cd.yml (job infra) com TARGET=qa (develop) ou TARGET=prod (main).

resource "databricks_schema" "this" {
  catalog_name  = "workspace"
  name          = "news_recsys_${var.target}"
  comment       = "news-recsys ${var.target} (gerenciado pelo Terraform)"
  force_destroy = false # o Terraform se recusa a apagar um schema que tem tabelas
}

# Onde o sitemap chega (raw/sitemaps/*.xml) e o notebook 01_dados lê
resource "databricks_volume" "raw" {
  catalog_name = "workspace"
  schema_name  = databricks_schema.this.name
  name         = "raw"
  volume_type  = "MANAGED"
}
