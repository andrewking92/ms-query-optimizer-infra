terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.53"
    }
    mongodbatlas = {
      source = "mongodb/mongodbatlas"
      version = "1.8.0"
    }
  }
}
