# GitHub como código: environments (qa e prod) e proteção da develop e da main.
# Roda no cd.yml (job infra). O repositório e os secrets são criados uma vez à mão
# (make gh-repo / gh-secrets): a esteira não pode criar as próprias credenciais.

data "github_repository" "this" {
  name = var.repository_name
}

# develop → qa - main → prod (o cd.yml escolhe o environment pela branch)
resource "github_repository_environment" "env" {
  for_each    = toset(["qa", "prod"])
  repository  = data.github_repository.this.name
  environment = each.key
}

# URL da app do Streamlit Cloud de cada ambiente (o cd.yml confere se ela responde).
# O Streamlit não aceita "qa" nem "prod" no subdomínio: QA = "-homolog", PROD = nome limpo.
locals {
  app_streamlit = {
    qa   = "${var.github_owner}-news-recsys-homolog"
    prod = "${var.github_owner}-news-recsys"
  }
}

resource "github_actions_environment_variable" "streamlit_url" {
  for_each      = github_repository_environment.env
  repository    = data.github_repository.this.name
  environment   = each.value.environment
  variable_name = "STREAMLIT_URL"
  value         = "https://${local.app_streamlit[each.key]}.streamlit.app"
}

# develop e main só recebem PR com CI verde
resource "github_branch_protection" "branch" {
  for_each      = toset(["develop", "main"])
  repository_id = data.github_repository.this.node_id
  pattern       = each.key

  required_status_checks {
    strict   = true
    contexts = ["test"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 0
  }

  enforce_admins      = false
  allows_force_pushes = false
  allows_deletions    = false
}
