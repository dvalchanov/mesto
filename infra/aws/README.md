# Mesto source-archive infrastructure

This Terraform root creates only the private S3 storage required by Part 2. It does not create IAM users or access keys, Heroku resources, Route 53 records, ACM certificates, or CloudFront distributions.

The bucket configuration:

- blocks every form of public access;
- rejects non-TLS requests;
- enables S3-managed encryption and versioning;
- aborts incomplete multipart uploads after one day;
- expires failed/unpublished candidates after two days;
- keeps at most one previous validated artifact for up to 14 days; and
- preserves the current validated object and manifest.

Copy `terraform.tfvars.example` to an untracked `terraform.tfvars`, choose a globally unique bucket name, and use your normal remote Terraform state configuration before applying:

```sh
terraform init
terraform plan
terraform apply
```

After applying, attach the `source_archive_application_iam_policy` output to the separately managed application principal. Set the bucket, region, prefix, account ID, and that principal's credentials as Heroku config vars. The prefix must match the Terraform `environment` value so manifest-version lifecycle rules apply. Use separate buckets or isolated principals for staging and production.
