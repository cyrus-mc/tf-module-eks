provider aws {
  profile = "dev"
  region  = "us-west-2"
}

provider local {}

data "template_file" "stub" {
  template = ""

  vars {}
}

resource null_resource "stub" {}
