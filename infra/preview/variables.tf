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
