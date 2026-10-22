variable "github_owner" {
  description = "Usuário ou organização dona do repositório (no Actions: github.repository_owner)"
  type        = string
}

variable "repository_name" {
  description = "Nome do repositório"
  type        = string
  default     = "news-recsys-databricks"
}
