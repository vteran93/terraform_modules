

resource "aws_db_instance" "db_instance" {
  identifier_prefix = "growthguard-rds-instance"
  db_name                 = data.aws_ssm_parameter.db_name.value
  allocated_storage       = 20
  engine                  = "postgres"
  storage_type            = "gp3"
  instance_class          = "db.t3.micro"
  username                = data.aws_ssm_parameter.db_username.value
  password                = data.aws_ssm_parameter.db_password.value
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  skip_final_snapshot     = true
  apply_immediately       = true
  backup_retention_period = 0
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "main_subnet_group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags = {
    Name = "${var.project}-MainDBSubnetGroup"
  }
}
