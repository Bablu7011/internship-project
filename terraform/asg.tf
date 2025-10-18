# --------------------------
# Launch Template
# --------------------------
# This is the blueprint for every EC2 instance launched by the Auto Scaling Group.
resource "aws_launch_template" "main_lt" {
  name                   = "${var.stage}-main-launch-template"
  image_id               = "ami-0f5ee92e2d63afc18" # Ubuntu 22.04 LTS for ap-south-1
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # Solves the t3.micro CPU credit throttling issue for our test
  credit_specification {
    cpu_credits = "unlimited"
  }

  # Enable detailed monitoring for faster CloudWatch metrics (1-minute intervals)
  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/../scripts/user_data.sh.tpl", {
    JAR_BUCKET           = var.jar_bucket_name
    EC2_LOGS_BUCKET      = var.ec2_logs_bucket_name
  }))

  tags = {
    Name = "${var.stage}-launch-template"
  }
}

# --------------------------
# Target Group for the Load Balancer
# --------------------------
# We define this here to keep all ASG-related config together.
resource "aws_lb_target_group" "main_tg" {
  name     = "${var.stage}-main-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.devops_vpc.id

  health_check {
    # This points the health check to the dedicated /health endpoint.
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15 # Check every 15 seconds
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# --------------------------
# Auto Scaling Group (ASG)
# --------------------------
resource "aws_autoscaling_group" "main_asg" {
  name                      = "${var.stage}-main-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 4
  vpc_zone_identifier       = [aws_subnet.devops_subnet.id, aws_subnet.devops_subnet_2.id]
  health_check_type         = "ELB"
  # THIS IS A KEY FIX: Ignores ELB health checks for 300 seconds after launch.
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.main_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.stage}-asg-instance"
    propagate_at_launch = true
  }
}

# --------------------------
# Scaling Policies & Alarms (Fast for Demo)
# --------------------------
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.stage}-scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.main_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60 # Wait 1 minute before another scale-up
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.stage}-cpu-high-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1" # Trigger after 1 minute of high CPU
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "30" # Low threshold for easy testing
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main_asg.name
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.stage}-scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.main_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120 # Wait 2 minutes before another scale-down
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.stage}-cpu-low-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2" # Trigger after 2 minutes of low CPU
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main_asg.name
  }
}

# --------------------------
# SNS Notifications
# --------------------------
resource "aws_sns_topic" "asg_notifications" {
  name = "${var.stage}-asg-scaling-events"
}

resource "aws_sns_topic_policy" "asg_notifications_policy" {
  arn    = aws_sns_topic.asg_notifications.arn
  policy = templatefile("${path.module}/../policy/sns_asg_notification_policy.json", {
    sns_topic_arn = aws_sns_topic.asg_notifications.arn
  })
}

resource "aws_autoscaling_notification" "main_asg_notifications" {
  group_names = [aws_autoscaling_group.main_asg.name]
  
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.asg_notifications.arn
}

