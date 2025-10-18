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

  # THIS IS THE FIX: Enable unlimited mode for T-series instances.
  # This allows the CPU to sustain high performance for our test.
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
# Auto Scaling Group (ASG)
# --------------------------
resource "aws_autoscaling_group" "main_asg" {
  name                = "${var.stage}-main-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = [aws_subnet.devops_subnet.id, aws_subnet.devops_subnet_2.id]

  launch_template {
    id      = aws_launch_template.main_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main_tg.arn]
  health_check_type = "ELB"
}

# --------------------------
# Scaling Policies & Alarms (Fast for Demo)
# --------------------------
# --- Scale-Up Policy ---
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.stage}-scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.main_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.stage}-cpu-high-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "30"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main_asg.name
  }
}

# --- Scale-Down Policy ---
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.stage}-scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.main_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.stage}-cpu-low-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  # THIS IS THE CHANGE: The threshold is now 20%
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

