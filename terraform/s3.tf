# Bucket to store the application JAR file
resource "aws_s3_bucket" "jar_bucket" {
  bucket = "jar-bucket-${random_pet.suffix.id}"
   force_destroy = true
  tags = {
    Name = "${var.stage}-jar-bucket"
  }
}

# Bucket to store logs from the EC2 instances
resource "aws_s3_bucket" "ec2_logs_bucket" {
  bucket = "ec2-logs-bucket-${random_pet.suffix.id}"
   force_destroy = true
  tags = {
    Name = "${var.stage}-ec2-logs-bucket"
  }
}

# Bucket to store logs from the Application Load Balancer
resource "aws_s3_bucket" "elb_logs_bucket" {
  bucket = "elb-logs-bucket-${random_pet.suffix.id}"
  force_destroy = true
  tags = {
    Name = "${var.stage}-elb-logs-bucket"
  }
}

# This resource helps generate a unique suffix for our bucket names
resource "random_pet" "suffix" {
  length = 2
}

# Add a 7-day lifecycle rule to the EC2 logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "ec2_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.ec2_logs_bucket.id

  rule {
    id     = "delete-logs-after-7-days"
    status = "Enabled"

    expiration {
      days = 7
    }

    filter {} # Apply this rule to all objects in the bucket
  }
}

# Add a 7-day lifecycle rule to the ELB logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "elb_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.elb_logs_bucket.id

  rule {
    id     = "delete-logs-after-7-days"
    status = "Enabled"

    expiration {
      days = 7
    }

    filter {} # Apply this rule to all objects in the bucket
  }
}

# This data source automatically finds the AWS Account ID for the ELB service in our region
data "aws_elb_service_account" "main" {}

# Attach the policy to the S3 bucket by rendering the external JSON file
resource "aws_s3_bucket_policy" "elb_logs_bucket_policy" {
  bucket = aws_s3_bucket.elb_logs_bucket.id
  policy = templatefile("${path.module}/../policy/s3_elb_logging_policy.json", {
    elb_service_account_arn = data.aws_elb_service_account.main.arn
    bucket_arn              = aws_s3_bucket.elb_logs_bucket.arn
  })
}