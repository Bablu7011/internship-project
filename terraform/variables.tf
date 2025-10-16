variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "stage" {
  description = "Deployment stage (e.g., Dev)"
  type        = string
  default     = "Dev"
}


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair in AWS"
  type        = string
}

variable "jar_bucket_name" {
  description = "A unique name for the S3 bucket that will store the JAR file."
  type        = string
}

variable "ec2_logs_bucket_name" {
  description = "A unique name for the S3 bucket that will store EC2 logs."
  type        = string
}

variable "elb_logs_bucket_name" {
  description = "A unique name for the S3 bucket that will store ELB logs."
  type        = string
}