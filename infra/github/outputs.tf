output "repository_url" {
  value = data.github_repository.this.html_url
}

output "streamlit_next_step" {
  value = "share.streamlit.io -> Create app -> ${data.github_repository.this.full_name}: develop -> ${var.github_owner}-news-recsys-homolog, main -> ${var.github_owner}-news-recsys"
}
