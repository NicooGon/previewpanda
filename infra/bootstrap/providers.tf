provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project = "previewpanda"
      team    = "previewpanda"
      env     = "shared"
      owner   = "nicolas"
    }
  }
}
