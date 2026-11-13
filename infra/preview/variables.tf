variable "env_name" {
  description = "Nombre del entorno de preview "
  type        = string
  default     = "pr-1"

  validation {
    condition     = can(regex("^pr-[0-9]+$", var.env_name))
    error_message = "env_name debe tener el formato pr-<numero>, por ejemplo pr-1 o pr-23."
  }
}

variable "pr_number" {
  description = "Numero del Pull Request, solo el numero (ej: 1, 23)"
  type        = string
  default     = "1"

  validation {
    condition     = can(regex("^[0-9]+$", var.pr_number))
    error_message = "pr_number debe ser solo numeros, por ejemplo 1 o 23."
  }
}

# Placeholder: el provider exige image_uri incluso en el destroy
variable "image_uri" {
  description = "URI de la imagen en ECR con tag (ej: <cuenta>.dkr.ecr.us-east-1.amazonaws.com/previewpanda:pr-23-abc1234)"
  type        = string
  default     = "NOT_CONFIGURED"

  validation {
    condition     = var.image_uri == "NOT_CONFIGURED" || can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/[a-z0-9._/-]+:[A-Za-z0-9._-]+$", var.image_uri))
    error_message = "image_uri debe ser una URI de ECR con tag, por ejemplo 123456789012.dkr.ecr.us-east-1.amazonaws.com/previewpanda:pr-23-abc1234."
  }
}

variable "commit_sha" {
  description = "SHA completo (40 caracteres) del commit del PR que se despliega"
  type        = string
  default     = null

  validation {
    condition     = var.commit_sha == null || can(regex("^[0-9a-f]{40}$", var.commit_sha))
    error_message = "commit_sha debe ser el SHA completo de 40 caracteres hexadecimales."
  }
}
