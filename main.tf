# providers.tf
provider "aws" {
  region = "us-east-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  default = "10.0.2.0/24"
}

variable "db_subnet_cidr" {
  default = "10.0.3.0/24"
}

variable "db_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}
variable "main_az" {
  description = "The main az"
  type        = string
  default = "us-east-2"
}
variable "other_az" {
  description = "The secondary az"
  type        = string
  default = "us-west-1"
}
#outputs

output "web_instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "app_instance_private_ip" {
  value = aws_instance.app.private_ip
}

output "db_instance_endpoint" {
  value = aws_db_instance.default.endpoint
}
