output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer. Use this URL to access the application."
  value       = aws_lb.main_alb.dns_name
}

output "ec2_public_ips" {
  description = "List of public IPs of the individual EC2 instances."
  value       = aws_instance.devops_ec2[*].public_ip
}

output "jar_bucket_name" {
  description = "The name of the S3 bucket where the application JAR file is stored."
  value       = aws_s3_bucket.jar_bucket.bucket
}

output "ec2_logs_bucket_name" {
  description = "The name of the S3 bucket for storing EC2 instance logs."
  value       = aws_s3_bucket.ec2_logs_bucket.bucket
}

output "elb_logs_bucket_name" {
  description = "The name of the S3 bucket for storing Load Balancer access logs."
  value       = aws_s3_bucket.elb_logs_bucket.bucket
}