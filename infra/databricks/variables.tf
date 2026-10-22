variable "target" {
  description = "Ambiente compartilhado: qa ou prod (o dev de cada pessoa usa make setup)"
  type        = string

  validation {
    condition     = contains(["qa", "prod"], var.target)
    error_message = "target deve ser qa ou prod."
  }
}
