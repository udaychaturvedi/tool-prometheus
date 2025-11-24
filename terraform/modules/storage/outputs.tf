output "monitoring_bucket_name" {
  value = aws_s3_bucket.monitoring_backup.bucket
}

output "monitoring_kms_arn" {
  value = aws_kms_key.monitoring_kms.arn
}

output "monitoring_s3_policy_arn" {
  value = aws_iam_policy.monitoring_s3_policy.arn
}

