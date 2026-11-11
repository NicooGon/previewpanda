output "function_url" {
  description = "URL publica de la funcion Lambda de este entorno de preview"
  value       = aws_lambda_function_url.app_url.function_url
}

output "function_name" {
  description = "Nombre de la funcion Lambda creada"
  value       = aws_lambda_function.app.function_name
}
