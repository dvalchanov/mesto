resource "aws_s3_bucket" "source_archives" {
  bucket        = var.source_archive_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "source_archives" {
  bucket = aws_s3_bucket.source_archives.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "source_archives" {
  bucket = aws_s3_bucket.source_archives.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "source_archives" {
  bucket = aws_s3_bucket.source_archives.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_archives" {
  bucket = aws_s3_bucket.source_archives.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "source_archives" {
  bucket = aws_s3_bucket.source_archives.id

  depends_on = [aws_s3_bucket_versioning.source_archives]

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-unpublished-candidates"
    status = "Enabled"

    filter {
      tag {
        key   = "mesto-retention"
        value = "candidate"
      }
    }

    expiration {
      days = var.candidate_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "expire-rollback-artifacts"
    status = "Enabled"

    filter {
      tag {
        key   = "mesto-retention"
        value = "rollback"
      }
    }

    expiration {
      days = var.rollback_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "expire-noncurrent-manifests"
    status = "Enabled"

    filter {
      prefix = "${var.environment}/latest/"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.rollback_retention_days
    }
  }
}

data "aws_iam_policy_document" "require_tls" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.source_archives.arn,
      "${aws_s3_bucket.source_archives.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "source_archives" {
  bucket = aws_s3_bucket.source_archives.id
  policy = data.aws_iam_policy_document.require_tls.json

  depends_on = [aws_s3_bucket_public_access_block.source_archives]
}

data "aws_iam_policy_document" "source_archive_application" {
  statement {
    sid = "ReadArchiveBucketMetadata"
    actions = [
      "s3:GetBucketLocation"
    ]
    resources = [aws_s3_bucket.source_archives.arn]
  }

  statement {
    sid = "ManageSourceArchiveObjects"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:PutObject",
      "s3:PutObjectTagging"
    ]
    resources = ["${aws_s3_bucket.source_archives.arn}/*"]
  }
}
