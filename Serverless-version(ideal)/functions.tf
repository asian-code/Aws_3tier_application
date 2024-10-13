resource "aws_iam_role" "role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# need function to handle: endpoints + cronjob (fetch + git upload), generating signed URL,  
# Login endpoint
resource "aws_lambda_function" "login" {
  function_name = "example_lambda"
  role          = aws_iam_role.role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "./code/login.zip"
  source_code_hash = filebase64sha256("./code/login.zip")
}

resource "aws_lambda_permission" "login_perm" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"
}

