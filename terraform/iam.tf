# --- Policy for reading from the JAR S3 Bucket ---
resource "aws_iam_policy" "read_jar_bucket_policy" {
  name   = "${var.stage}-read-jar-bucket-policy"
  policy = templatefile("${path.module}/../policy/ec2_read_jar_bucket_policy.json", {
    jar_bucket_name = var.jar_bucket_name
  })
}

# --- Policy for writing to the EC2 Logs S3 Bucket ---
resource "aws_iam_policy" "write_logs_bucket_policy" {
  name   = "${var.stage}-write-logs-bucket-policy"
  policy = templatefile("${path.module}/../policy/ec2_write_logs_bucket_policy.json", {
    ec2_logs_bucket_name = var.ec2_logs_bucket_name
  })
}

# --- The IAM Role that our EC2 instance will use ---
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "${var.stage}-ec2-s3-access-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# --- Attach the first policy (Read JAR) to the Role ---
resource "aws_iam_role_policy_attachment" "attach_read_jar_policy" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.read_jar_bucket_policy.arn
}

# --- Attach the second policy (Write Logs) to the Role ---
resource "aws_iam_role_policy_attachment" "attach_write_logs_policy" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.write_logs_bucket_policy.arn
}

# --- The instance profile that we attach to the EC2 instance ---
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.stage}-ec2-profile"
  role = aws_iam_role.ec2_s3_access_role.name
}

# --- Data Source to get current AWS Account ID ---
data "aws_caller_identity" "current" {}

# --- Policy for the Auditor to read all S3 Buckets ---
resource "aws_iam_policy" "auditor_read_buckets_policy" {
  name   = "${var.stage}-auditor-read-buckets-policy"
  policy = templatefile("${path.module}/../policy/auditor_read_buckets_policy.json", {
    jar_bucket_name      = var.jar_bucket_name
    ec2_logs_bucket_name = var.ec2_logs_bucket_name
    elb_logs_bucket_name = var.elb_logs_bucket_name
  })
}

# --- IAM Role for the Auditor (for a human user to assume) ---
resource "aws_iam_role" "s3_auditor_role" {
  name = "${var.stage}-s3-auditor-role"

  # This policy trusts your AWS account, allowing you to assume the role
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

# --- Attach the Auditor Policy to the Auditor Role ---
resource "aws_iam_role_policy_attachment" "attach_auditor_policy" {
  role       = aws_iam_role.s3_auditor_role.name
  policy_arn = aws_iam_policy.auditor_read_buckets_policy.arn
}