# 3-Tier Application

## Overview
This project is a 3-tier application consisting of a web front-end, an application server, and a database server. The infrastructure is managed using Terraform and deployed on AWS.

## Architecture
- **Presentation Tier**: The front-end is built with React.js and served by an Nginx server.
- **Application Tier**: The back-end is developed using Node.js and Express.js.
- **Data Tier**: The database is managed by Amazon RDS running MySQL.

## Prerequisites
- AWS Account
- Terraform installed
- AWS CLI configured

## Setup Instructions

### 1. Clone the Repository
```sh
git clone https://github.com/yourusername/3-tier-application.git
cd 3-tier-application
```

### 2. Configure Terraform Variables
Create a terraform.tfvars file and add your configuration:
```
db_username = "your_db_username"
db_password = "your_db_password"
main_az     = "us-west-2"
email_addresses = ["your_email@example.com", "another_email@example.com"]
```
### 3. Initialize and Apply Terraform Configuration
```sh
terraform init
terraform apply
```
