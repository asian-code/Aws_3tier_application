#region RDS Database
/*
* Important db features to have:
* Backups 
* delete protection
* updates
* data at rest- encryption
* db monitoring - metrics: cpu, memeory, storage
*/
resource "aws_db_instance" "default" {
  allocated_storage       = 15
  db_name                 = "mydb"
  engine                  = "mysql"
  engine_version          = "8.0.35"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true # snapshot store changes made, depends on original db.
  availability_zone       = "${var.main_az}a"
  identifier              = "hash-db"
  db_subnet_group_name    = aws_db_subnet_group.default.name
  backup_window           = "01:00-02:00" #stores backups in abstracted s3 bucks. can access in aws console
  backup_retention_period = 7
  deletion_protection  = var.env == "test" ? false:true
  auto_minor_version_upgrade = true                  # Enable automatic minor version upgrades
  maintenance_window         = "Sun:04:00-Sun:06:00" # Set maintenance window
  vpc_security_group_ids     = [aws_security_group.db_sg.id]
  multi_az                    = var.env =="test"? false : true # single az for testing only

  tags = {
    Name = "mydb"
  }
}
/* 
A DB subnet group allows you to specify a set of subnets in different Availability Zones (AZs). 
This ensures that your RDS instance can be deployed across multiple AZs, 
enhancing availability and fault tolerance1.
*/
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.db.id,aws_subnet.db2.id]

  tags = {
    Name = "My DB subnet group"
  }
}
#endregion
#region SNS
# resource "aws_sns_topic" "rds_events" {
#   name = "rds-events-topic"
# }
variable "email_addresses" {
  description = "List of email addresses to subscribe to the SNS topic"
  type        = list(string)
  default     = ["ericnguyencode@gmail.com", "hashstudiosllc@gmail.com"]
}
# resource "aws_sns_topic_subscription" "rds_events_email" {
#   for_each  = toset(var.email_addresses)
#   topic_arn = aws_sns_topic.rds_events.arn
#   protocol  = "email"
#   endpoint  = each.value
# }

# resource "aws_db_event_subscription" "default" {
#   name        = "mydb-events"
#   sns_topic   = aws_sns_topic.rds_events.arn
#   source_type = "db-instance"

#   event_categories = [
#     "availability",
#     "deletion",
#     "failover",
#     "failure",
#     "low storage",
#     "maintenance",
#     "notification",
#     "read replica",
#     "recovery",
#     "restoration",
#   ]

#   source_ids = [aws_db_instance.default.id]
#   depends_on = [aws_db_instance.default]
#   enabled = true
# }
#endregion
