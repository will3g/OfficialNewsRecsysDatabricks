# Serving endpoint do modelo: inferência online da versão @champion.
# Roda depois do Job (o modelo e o alias precisam existir): dev pelo make, QA/PROD no cd.yml (job serving).
# O gate decide quem é o @champion; aqui o endpoint passa a servir essa versão.

data "databricks_registered_model" "this" {
  full_name       = "workspace.${var.schema}.news_recommender"
  include_aliases = true
}

locals {
  champion = one([
    for a in data.databricks_registered_model.this.model_info[0].aliases :
    a.version_num if a.alias_name == "champion"
  ])
}

resource "databricks_model_serving" "this" {
  name = replace(var.schema, "_", "-") # news-recsys-qa - news-recsys-prod - news-recsys-dev-<usuário>

  config {
    served_entities {
      entity_name           = data.databricks_registered_model.this.full_name
      entity_version        = local.champion
      workload_type         = "CPU" # a Free Edition tem cota 0 de GPU
      workload_size         = "Small"
      scale_to_zero_enabled = true # desliga quando ninguém chama
    }
  }
}

output "endpoint" {
  value = "${databricks_model_serving.this.name} → ${data.databricks_registered_model.this.full_name} v${local.champion} (@champion)"
}
