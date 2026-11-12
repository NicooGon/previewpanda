output "ecr_repository_url" {
  description = "URL del repositorio ECR donde se suben las imagenes de la app"
  value       = aws_ecr_repository.app.repository_url
}
