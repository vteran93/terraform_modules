provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_subnet" "example_public" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "example-public-subnet"
  }
}

resource "aws_subnet" "example_private" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "example-private-subnet"
  }
}

resource "aws_security_group" "example" {
  vpc_id = aws_vpc.example.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "example" {
  name = "example"
}

resource "aws_ecs_task_definition" "example" {
  family                = "example"
  container_definitions = <<EOF
[
  {
    "name": "example",
    "image": "httpd:latest",
    "memory": 128,
    "essential": true
  }
]
EOF
}

resource "aws_ecs_service" "example" {
  name            = "example"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 2

  launch_type = "EC2"

  load_balancer {
    target_group_arn = aws_alb_target_group.example.arn
    container_name   = "example"
    container_port   = 80
  }

  scaling_configuration {
    desired_capacity          = 2
    minimum_scaling_step_size = 1
    maximum_scaling_step_size = 2
  }

  network_configuration {
    subnets         = [aws_subnet.example_public.id]
    security_groups = [aws_security_group.example.id]
  }
}

resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = [aws_subnet.example_public.id]
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
  min_size         = 2
  max_size         = "4"
  desired_capacity = 2
}

resource "aws_launch_template" "example" {
  name_prefix   = "example"
  image_id      = "ami-0e094855ce95c71c6"
  instance_type = "t3.micro"
  spot_price    = "0.01"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }
}

resource "aws_rds_instance" "example" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  name                   = "example"
  username               = "example"
  password               = "example"
  vpc_security_group_ids = [aws_security_group.example.id]
  subnet_ids             = [aws_subnet.example_private.id]
}
