# Create the Application Load Balancer
resource "aws_lb" "main_alb" {
  name               = "${var.stage}-main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.devops_sg.id]
  subnets            = [aws_subnet.devops_subnet.id, aws_subnet.devops_subnet_2.id]

  # Enable access logging and point it to our ELB logs bucket
  access_logs {
    bucket  = var.elb_logs_bucket_name
    prefix  = "elb-logs"
    enabled = true
  }

  tags = {
    Name = "${var.stage}-main-alb"
  }
}

# Create the Listener to forward traffic from the LB to the Target Group
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    # This now correctly references the Target Group defined in asg.tf
    target_group_arn = aws_lb_target_group.main_tg.arn
  }
}

