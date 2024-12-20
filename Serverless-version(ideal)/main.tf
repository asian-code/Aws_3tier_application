provider "aws" {
  region = "us-east-2"
}
terraform {
  backend "s3" {
    bucket         = "hashstudio-tf"
    key            = "env/prod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tf-backend-hashstudio"
    encrypt        = true
  }
}
variable "env_vars" {
  type = map(string)
}

# Create API Gateway
resource "aws_apigatewayv2_api" "gw" {
  name          = "myapi"
  protocol_type = "HTTP"
  description   = "API Gateway for Serverless Lambda integration"
  tags = {
    Cost : "Serverless"
  }
}
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.gw.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.default.id}"
}
resource "aws_apigatewayv2_integration" "default" {
  api_id           = aws_apigatewayv2_api.gw.id
  integration_type = "AWS_PROXY"

  integration_method = "POST" # must be POST for AWS_PROXY
  integration_uri    = aws_lambda_function.default.invoke_arn
}
#region routes and intergrations
resource "aws_apigatewayv2_route" "bypass" {
  api_id    = aws_apigatewayv2_api.gw.id
  route_key = "ANY /bypass"
  target    = "integrations/${aws_apigatewayv2_integration.bypass.id}"
}

resource "aws_apigatewayv2_integration" "bypass" {
  api_id           = aws_apigatewayv2_api.gw.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.cf-url.invoke_arn
}
resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.gw.id
  route_key = "ANY /login"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_apigatewayv2_integration" "login" {
  api_id           = aws_apigatewayv2_api.gw.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.login.invoke_arn
}
resource "aws_apigatewayv2_route" "callback" {
  api_id    = aws_apigatewayv2_api.gw.id
  route_key = "ANY /callback"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_apigatewayv2_integration" "callback" {
  api_id           = aws_apigatewayv2_api.gw.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.login.invoke_arn
}
resource "aws_apigatewayv2_route" "submit" {
  api_id    = aws_apigatewayv2_api.gw.id
  route_key = "ANY /submit"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_apigatewayv2_integration" "submit" {
  api_id           = aws_apigatewayv2_api.gw.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.login.invoke_arn
}

#endregion

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.gw.id
  name        = "dev"
  auto_deploy = true
}

# Output
output "api_endpoint" {
  description = "HTTP API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.stage.invoke_url
}