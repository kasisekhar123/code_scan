terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"

    }
  }
}

terraform {
  backend "s3" {
    bucket         = "tksterraformstate657"
    key            = "terraform.tfstate"
    region         = "us-east-1"
  }
}


provider "aws" {
  region  = "us-east-1"

}


locals {
  folder_name = ["csv_data", "paraquet_data"]
}

resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}
resource "aws_s3_bucket" "data_conversion_bkt" {
  bucket = "data-csv-parq-bkt-${random_string.random.result}"
}

resource "aws_s3_object" "example" {
  for_each   = toset(local.folder_name)
  key        = "${each.key}/"
  bucket     = aws_s3_bucket.data_conversion_bkt.id
  source     = null
  depends_on = [aws_s3_bucket.data_conversion_bkt]
}


resource "aws_iam_role" "data_convert_role" {
  name = "data_conver_lambda_role"
  inline_policy {
    name = "s3_access_permissions"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Sid    = ""
          Effect = "Allow"
          Action = ["logs:CreateLogStream",
          "logs:PutLogEvents"]
          Resource = ["*"]
        },
        {
          Sid      = ""
          Effect   = "Allow"
          Action   = ["s3:*"]
          Resource = ["arn:aws:s3:::*"]
        },
      ]
    })
  }
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "LambdaAsumme"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }

    ]
  })
}

data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/lambda_function.py"
  output_path = "nametest.zip"
}

# data "archive_file" "layer_version" {
#   type        = "zip"
#   source_dir  = "${path.module}/lambda_code/layers"
#   output_path = "${path.module}test-layer.zip"

# }

# resource "aws_lambda_layer_version" "lambda_layer" {
#   layer_name          = "pandas-sdjjdkj"
#   source_code_hash    = data.archive_file.layer_version.output_base64sha256
#   filename            = data.archive_file.layer_version.output_path
#   compatible_runtimes = ["python3.10"]
# }





#Create Lmabda function
resource "aws_lambda_function" "data_convert_function" {
  function_name    = "data_conversion"
  role             = aws_iam_role.data_convert_role.arn
  filename         = "nametest.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  runtime          = "python3.10"
  handler          = "lambda_function.lambda_handler"
  timeout          = 300
  # layers           = [aws_lambda_layer_version.lambda_layer.arn]

}

resource "aws_lambda_permission" "allow_bucket1" {
  statement_id  = "AllowExecutionFromS3Bucket1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_convert_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_conversion_bkt.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_conversion_bkt.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_convert_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "csv_data/"
  }

  depends_on = [
    aws_lambda_permission.allow_bucket1
  ]
}

