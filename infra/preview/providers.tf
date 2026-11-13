provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project = "previewpanda"
      team    = "previewpanda"
      env     = "preview"
      owner   = "nicolas"
      pr      = trimprefix(var.env_name, "pr-")
    }
  }
}
