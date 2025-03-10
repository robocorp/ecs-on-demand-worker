
resource "aws_cloudwatch_event_bus" "bus" {
  name = "${var.id}-control-room-events-in"
}

resource "aws_ssm_parameter" "eventbus_arn" {
  name  = "${aws_cloudwatch_event_bus.bus.name}-eventbus-arn"
  type  = "String"
  value = aws_cloudwatch_event_bus.bus.arn
}

data "aws_iam_policy_document" "bus_policy" {
  statement {
    sid    = "AllowOtherAccountsToPutEvents"
    effect = "Allow"
    actions = [
      "events:PutEvents",
    ]
    resources = [
      aws_cloudwatch_event_bus.bus.arn
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      // https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-use-conditions.html
      test     = "ForAnyValue:StringLike"
      variable = "aws:SourceArn"
      values   = var.eventbridge_external_in_allowed_source_rule_arns
    }
  }
}

resource "aws_cloudwatch_event_bus_policy" "bus" {
  policy         = data.aws_iam_policy_document.bus_policy.json
  event_bus_name = aws_cloudwatch_event_bus.bus.name
}
