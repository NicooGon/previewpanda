terraform {
  # key se pasa en el init: previews/<env_name>/terraform.tfstate
  backend "s3" {
    bucket       = "previewpanda-tfstate-nico2026"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
