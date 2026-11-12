terraform {
  backend "s3" {
    bucket       = "previewpanda-tfstate-nico2026"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
