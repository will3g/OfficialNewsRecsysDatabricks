variable "schema" {
  description = "Schema do ambiente (dev: news_recsys_dev_<usuário> - qa - prod); o Makefile passa o do databricks.yml"
  type        = string
}
