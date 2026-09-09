output "source_archive_bucket_name" {
  description = "Set this as SOURCE_ARCHIVE_BUCKET in Heroku."
  value       = aws_s3_bucket.source_archives.bucket
}

output "source_archive_bucket_region" {
  description = "Set this as SOURCE_ARCHIVE_REGION in Heroku."
  value       = var.aws_region
}

output "source_archive_prefix" {
  description = "Set this as SOURCE_ARCHIVE_PREFIX in Heroku."
  value       = var.environment
}

output "source_archive_expected_bucket_owner" {
  description = "Set this as SOURCE_ARCHIVE_EXPECTED_BUCKET_OWNER in Heroku."
  value       = data.aws_caller_identity.current.account_id
}

output "source_archive_application_iam_policy" {
  description = "Attach this least-privilege policy to the application IAM principal created separately."
  value       = data.aws_iam_policy_document.source_archive_application.json
}

data "aws_caller_identity" "current" {}
