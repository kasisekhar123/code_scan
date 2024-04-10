terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"
    }
  }
}


locals {
  folder_name = ["csv_data", "paraquet_data"]
}

resource "aws_s3_bucket" "data_conversion_bkt" {
  bucket = "data_csv_parquet_bket"

}
resource "aws_s3_object" "example" {
  for_each = toset(local.folder_name)
  key      = each.key
  bucket   = aws_s3_bucket.data_conversion_bkt.id
}