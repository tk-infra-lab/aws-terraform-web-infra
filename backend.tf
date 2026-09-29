terraform {
  backend "s3" {
    bucket       = "aws-terraform-ts-tfstate-101019"
    key          = "portfolio/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}