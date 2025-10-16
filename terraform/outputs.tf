output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main_alb.dns_name
}

output "jar_bucket_name" {
  description = "The name of the S3 bucket for storing the JAR file"
  value       = aws_s3_bucket.jar_bucket.bucket
}
