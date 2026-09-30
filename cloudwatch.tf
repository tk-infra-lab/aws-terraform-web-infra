resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name        = "portfolio-alb-unhealthy-hosts"
  alarm_description = "Alarm when ALB target group has unhealthy hosts"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic          = "Average"
  period             = 60
  evaluation_periods = 2

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  dimensions = {
    LoadBalancer = aws_lb.web.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }

  treat_missing_data = "notBreaching"
}