# --------------------------
# Launch Template
# --------------------------
# This is the blueprint for every EC2 instance launched by the Auto Scaling Group.
# It defines the AMI, instance type, key pair, security groups, IAM role, and startup script.
resource "aws_launch_template" "main_lt" {
  name                   = "${var.stage}-main-launch-template"
  image_id               = "ami-0f5ee92e2d63afc18" # Ubuntu 22.04 LTS for ap-south-1
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  # Attach the IAM role so instances can access S3
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # Provide the startup script
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
# This resource manages the lifecycle of our EC2 instances.
resource "aws_autoscaling_group" "main_asg" {
  name                = "${var.stage}-main-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = [aws_subnet.devops_subnet.id, aws_subnet.devops_subnet_2.id]

  # Connect the ASG to the Launch Template
  launch_template {
    id      = aws_launch_template.main_lt.id
    version = "$Latest"
  }

  # Connect the ASG to the Load Balancer's Target Group
  target_group_arns = [aws_lb_target_group.main_tg.arn]

  # This ensures that if an instance is terminated, the ASG waits for the
  # connection to drain from the load balancer before shutting it down.
  health_check_grace_period = 300
  health_check_type         = "ELB"

  # A tag to identify instances launched by this ASG
  tag {
    key                 = "Name"
    value               = "${var.stage}-asg-instance"
    propagate_at_launch = true
  }
}

# --------------------------
# Scaling Policies & Alarms
# --------------------------
# --- Scale-Up Policy ---
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.stage}-scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.main_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.stage}-cpu-high-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# --- Scale-Down Policy ---
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.stage}-scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.main_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.stage}-cpu-low-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 600
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}





#######################################
# --- SNS Topic for ASG Notifications ---
# This topic will receive a message every time a scaling event occurs.
resource "aws_sns_topic" "asg_notifications" {
  name = "${var.stage}-asg-notifications"
}

# --- ASG Notification Configuration ---
# This tells the ASG to send notifications to our SNS topic
# for all major lifecycle events.
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