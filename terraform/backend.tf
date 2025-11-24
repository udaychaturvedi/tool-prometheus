###############################################
# backend.tf  (Remote Terraform State - S3)
###############################################

terraform {
  backend "s3" {
    bucket  = "tf-state-uday-ap-south-1"
    key     = "tool-prometheus/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
