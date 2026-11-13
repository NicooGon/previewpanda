provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project = "previewpanda"
      team    = "previewpanda"
      env     = "preview"
      owner   = "nicolas"
      pr      = var.pr_number
    }
  }
}
