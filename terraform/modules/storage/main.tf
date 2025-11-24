############################################################
# Get Account ID for Key Policy
############################################################
data "aws_caller_identity" "current" {}

############################################################
# KMS Key with Proper Policy for EC2 Role
############################################################
resource "aws_kms_key" "monitoring_kms" {
  description             = "KMS key for monitoring backups ${var.region}"
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Root Full Access
      {
        Sid: "EnableRootAccess",
        Effect: "Allow",
        Principal: {
          AWS: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action: "kms:*",
        Resource: "*"
      },
      # Allow EC2 Monitoring Role Access
      {
        Sid: "AllowEC2MonitoringRoleUse",
        Effect: "Allow",
        Principal: {
          AWS: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-tools-role"
        },
        Action: [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource: "*"
      }
    ]
  })
}

############################################################
# S3 Bucket
############################################################
resource "aws_s3_bucket" "monitoring_backup" {
  bucket = "${var.project_name}-monitoring-backup-${var.region}${var.bucket_suffix}"
}

############################################################
# S3 Bucket Versioning (Terraform new recommended way)
############################################################
resource "aws_s3_bucket_versioning" "monitoring_versioning" {
  bucket = aws_s3_bucket.monitoring_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################################
# S3 Encryption (now separate resource)
############################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring_sse" {
  bucket = aws_s3_bucket.monitoring_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.monitoring_kms.arn
    }
  }
}

############################################################
# IAM Policy to Allow EC2 to Write Backups
############################################################
resource "aws_iam_policy" "monitoring_s3_policy" {
  name        = "${var.project_name}-monitoring-s3-policy"
  description = "Allows EC2 instances to write monitoring backups to S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Action: [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.monitoring_backup.arn}",
          "${aws_s3_bucket.monitoring_backup.arn}/*"
        ]
      }
    ]
  })
}

