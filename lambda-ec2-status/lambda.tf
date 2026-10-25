data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ec2_status.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "ec2_status" {
  function_name = "ec2-status-check"
  role          = aws_iam_role.lambda_role.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler = "ec2_status.lambda_handler"
  runtime = "python3.12"

  timeout = 10
}