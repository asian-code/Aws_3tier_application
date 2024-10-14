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
resource "aws_lambda_layer_version" "layer" {
  layer_name          = "my-layer"
  description         = "Stores all the Nodejs Dependencies + Cloudfront private key"
  compatible_runtimes = ["nodejs20.x"]
  filename            = "./code/layers.zip"
  source_code_hash    = filebase64sha256("./code/layers.zip")
}

# need function to handle: endpoints + cronjob (fetch + git upload), generating signed URL,  
# default if nothing matches
resource "aws_lambda_function" "default" {
  function_name = "default-func"
  role          = aws_iam_role.role.arn
  handler       = "default.lambda_handler"
  runtime       = "python3.12"
  filename      = "./code/default.zip"
  source_code_hash = filebase64sha256("./code/default.zip")
  environment {
    variables = var.env_vars
  }
  tags = {
    Cost="Serverless"
  }
  layers = [ aws_lambda_layer_version.layer.arn ]
}

resource "aws_lambda_permission" "default_perm" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.default.function_name
  principal     = "apigateway.amazonaws.com"
}

# Login endpoint
resource "aws_lambda_function" "login" {
  function_name = "login-func"
  role          = aws_iam_role.role.arn
  handler       = "login.handler"
  runtime       = "nodejs20.x"
  filename      = "./code/login.zip"
  source_code_hash = filebase64sha256("./code/login.zip")
  environment {
    variables = var.env_vars
  }
  tags = {
    Cost="Serverless"
  }
  layers = [ aws_lambda_layer_version.layer.arn ]
}

resource "aws_lambda_permission" "login_perm" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"
}

# CF Signed URL function
resource "aws_lambda_function" "cf-url" {
  function_name = "CF-signedURL-func"
  role          = aws_iam_role.role.arn
  handler       = "CF-signedURL.handler"
  runtime       = "nodejs20.x"
  filename      = "./code/cfurl.zip"
  source_code_hash = filebase64sha256("./code/cfurl.zip")
  environment {
    variables = var.env_vars
  }
  tags = {
    Cost="Serverless"
  }
  layers = [ aws_lambda_layer_version.layer.arn ]
}

resource "aws_lambda_permission" "cfurl_perm" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cf-url.function_name
  principal     = "apigateway.amazonaws.com"
}