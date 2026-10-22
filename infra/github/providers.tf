terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  # State local (terraform.tfstate, gitignored). O `make tf-plan` baixa a cópia guardada no
  # Volume workspace.default.tfstate e o `make tf-apply` devolve: o runner do Actions é descartável.
}

# Autenticação: GITHUB_TOKEN (no Actions: secret TF_GITHUB_TOKEN; local: gh auth token)
provider "github" {
  owner = var.github_owner
}
