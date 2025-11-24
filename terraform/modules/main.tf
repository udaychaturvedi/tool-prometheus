variable "project_name" { }
variable "region" { }
variable "bucket_suffix" { default = "" }

resource "aws_s3_bucket" "monitoring_backup" {
  bucket = "${var.project_name}-monitoring-backup-${var.region}${var.bucket_suffix}"
  acl    = "private"
  force_destroy = false

  versioning { enabled = true }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.monitoring_kms.arn
      }
    }
  }

  tags = {
    Name = "monitoring-backup-${var.region}"
    Env  = "prod"
  }
}

resource "aws_kms_key" "monitoring_kms" {
  description             = "KMS key for monitoring backups ${var.region}"
  deletion_window_in_days = 30
}

resource "aws_iam_policy" "monitoring_s3_policy" {
  name        = "${var.project_name}-monitoring-s3-policy-${var.region}"
  description = "Allow instance to write/read monitoring backups"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        Resource = [
          aws_s3_bucket.monitoring_backup.arn,
          "${aws_s3_bucket.monitoring_backup.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.monitoring_kms.arn
      }
    ]
  })
}

output "monitoring_bucket_name" {
  value = aws_s3_bucket.monitoring_backup.bucket
}

output "monitoring_kms_arn" {
  value = aws_kms_key.monitoring_kms.arn
}

