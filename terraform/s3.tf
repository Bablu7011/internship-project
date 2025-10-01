# Bucket to store the application JAR file
resource "aws_s3_bucket" "jar_bucket" {
  bucket = "jar-bucket-${random_pet.suffix.id}"
  tags = {
    Name = "${var.stage}-jar-bucket"
  }
}

# Bucket to store logs from the EC2 instances
resource "aws_s3_bucket" "ec2_logs_bucket" {
  bucket = "ec2-logs-bucket-${random_pet.suffix.id}"
  tags = {
    Name = "${var.stage}-ec2-logs-bucket"
  }
}

# Bucket to store logs from the Application Load Balancer
resource "aws_s3_bucket" "elb_logs_bucket" {
  bucket = "elb-logs-bucket-${random_pet.suffix.id}"
  tags = {
    Name = "${var.stage}-elb-logs-bucket"
  }
}

# This resource helps generate a unique suffix for our bucket names
resource "random_pet" "suffix" {
  length = 2
}

# Output the names of the buckets
output "jar_bucket_name" {
  value = aws_s3_bucket.jar_bucket.bucket
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