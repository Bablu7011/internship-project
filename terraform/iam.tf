# Read and render the policy from our external JSON file
data "aws_iam_policy_document" "s3_access" {
  template = file("${path.module}/../policy/ec2_s3_policy.json")

  vars = {
    jar_bucket_name = aws_s3_bucket.jar_bucket.id
  }
}

# Create the IAM policy resource using the document above
resource "aws_iam_policy" "s3_access_policy" {
  name   = "${var.stage}-s3-access-policy"
  policy = data.aws_iam_policy_document.s3_access.json
}

# This is the IAM Role that our EC2 instance will use
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

# This connects our Policy to our Role
resource "aws_iam_role_policy_attachment" "attach_s3_access_policy" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# This is the instance profile that we attach to the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.stage}-ec2-profile"
  role = aws_iam_role.ec2_s3_access_role.name
}