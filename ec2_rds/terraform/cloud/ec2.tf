data "template_file" "user_data" {
  template = file("setup/userdata.sh")

  vars = {
    ssh_private_key         = data.aws_ssm_parameter.ssh_private_key.value
    django_secret_key       = data.aws_ssm_parameter.django_secret_key.value
    database_address        = aws_db_instance.db_instance.address
    database_db_name        = data.aws_ssm_parameter.db_name.value
    database_db_user        = data.aws_ssm_parameter.db_username.value
    database_db_password    = data.aws_ssm_parameter.db_password.value
    aws_storage_bucket_name = aws_s3_bucket.django_static_bucket.id
    database_port           = aws_db_instance.db_instance.port
    project                 = var.project
  }
}


resource "aws_instance" "web_server" {
  ami                         = "ami-04b70fa74e45c3917" # Ubuntu Server 24.04 LTS (HVM), SSD Volume Type
  instance_type               = var.environment == "prod" ? var.ec2_instance_type : "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  security_groups             = [aws_security_group.web_sg.id]
  associate_public_ip_address = true



  user_data            = data.template_file.user_data.rendered
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name


  tags = {
    Name = "${var.project}-WebServer"
  }

  depends_on = [aws_iam_instance_profile.ec2_instance_profile]
}



resource "aws_s3_bucket" "django_static_bucket" {
  bucket = "${var.project}-django-static"
}


resource "aws_s3_bucket_ownership_controls" "django_owner_control" {
  bucket = aws_s3_bucket.django_static_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket = aws_s3_bucket.django_static_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "allow_public" {
  depends_on = [
    aws_s3_bucket_ownership_controls.django_owner_control,
    aws_s3_bucket_public_access_block.allow_public,
  ]

  bucket = aws_s3_bucket.django_static_bucket.id
  acl    = "public-read"
}
