# Create the Application Load Balancer
resource "aws_lb" "main_alb" {
  name               = "${var.stage}-main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.devops_sg.id]
  subnets            = [aws_subnet.devops_subnet.id, aws_subnet.devops_subnet_2.id]

  # Enable access logging and point it to our ELB logs bucket
  access_logs {
    bucket  = aws_s3_bucket.elb_logs_bucket.bucket
    prefix  = "elb-logs"
    enabled = true
  }

  tags = {
    Name = "${var.stage}-main-alb"
  }
}

# Create the Target Group for our EC2 instances
resource "aws_lb_target_group" "main_tg" {
  name     = "${var.stage}-main-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.devops_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    # UPDATED: Give the instance more time to start
    interval            = 60
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5 # Allow 5 failures before marking as unhealthy
  }
}

# Create the Listener to forward traffic from the LB to the Target Group
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_tg.arn
  }
}