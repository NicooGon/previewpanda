variable "env_name" {
  description = "Nombre del entorno de preview "
  type        = string

  validation {
    condition     = can(regex("^pr-[0-9]+$", var.env_name))
    error_message = "env_name debe tener el formato pr-<numero>, por ejemplo pr-1 o pr-23."
  }
}

# Placeholder: el provider exige image_uri incluso en el destroy
variable "image_uri" {
  description = "URI de la imagen en ECR con tag"
  type        = string
  default     = "NOT_CONFIGURED"
}

variable "commit_sha" {
  description = "SHA del commit del PR (informativo, va como variable de entorno de la Lambda)"
  type        = string
  default     = "NOT_CONFIGURED"
}
