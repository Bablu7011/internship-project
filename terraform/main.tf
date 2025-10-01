provider "aws" {
  region = var.region
}

# Networking setup (VPC, Subnet, IGW, Route Table)
resource "aws_vpc" "devops_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "${var.stage}-vpc" }
}

resource "aws_subnet" "devops_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "${var.stage}-subnet" }
}

resource "aws_internet_gateway" "devops_igw" {
  vpc_id = aws_vpc.devops_vpc.id
  tags = { Name = "${var.stage}-igw" }
}

resource "aws_route_table" "devops_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devops_igw.id
  }
  tags = { Name = "${var.stage}-rt" }
}

resource "aws_route_table_association" "devops_rta" {
  subnet_id      = aws_subnet.devops_subnet.id
  route_table_id = aws_route_table.devops_rt.id
}

# Security Group to allow HTTP and SSH
resource "aws_security_group" "devops_sg" {
  name   = "${var.stage}-devops-sg"
  vpc_id = aws_vpc.devops_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the EC2 instances and attach them to the Target Group
resource "aws_instance" "devops_ec2" {
  count         = var.instance_count + 1
  ami           = "ami-0f5ee92e2d63afc18" # Ubuntu 22.04 LTS for ap-south-1
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.devops_subnet.id
  security_groups = [aws_security_group.devops_sg.id]
  # We will update the user_data and iam_instance_profile later
  
  tags = {
    Name  = "${var.stage}-devops-ec2-${count.index}"
    Stage = var.stage
  }
}

# Attach each created instance to the Load Balancer's Target Group
resource "aws_lb_target_group_attachment" "tga" {
  count            = length(aws_instance.devops_ec2)
  target_group_arn = aws_lb_target_group.main_tg.arn
  target_id        = aws_instance.devops_ec2[count.index].id
  port             = 80
}