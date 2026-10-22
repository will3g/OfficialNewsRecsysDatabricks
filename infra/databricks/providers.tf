terraform {
  required_version = ">= 1.6"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.138"
    }
  }
  # State local, um arquivo por ambiente (qa.tfstate / prod.tfstate, gitignored). O `make tf-db-plan`
  # baixa a cópia guardada no Volume workspace.default.tfstate e o `make tf-db-apply` devolve.
  backend "local" {}
}

# Autenticação: DATABRICKS_HOST e DATABRICKS_TOKEN (no Actions: secrets; local: ~/.databrickscfg)
provider "databricks" {}
