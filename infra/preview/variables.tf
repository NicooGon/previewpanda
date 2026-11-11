variable "env_name" {
  description = "Nombre del entorno de preview "
  type        = string
  default     = "pr-1"

  validation {
    condition     = can(regex("^pr-[0-9]+$", var.env_name))
    error_message = "env_name debe tener el formato pr-<numero>, por ejemplo pr-1 o pr-23."
  }
}
