resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project}_vpc_public_main"
  }
}

resource "aws_eip" "site_io_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.project}_igw_main"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "${var.project}_subnet_public_main_1"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "${var.project}_subnet_private_main_1"
  }
}


resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "${var.project}_subnet_public_main_2"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "${var.project}_subnet_private_main_2"
  }
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route.id
}


# You need a route table to allow traffic to the vpc
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main_vpc.id

  # since this is exactly the route AWS will create, the route will be adopted
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project}_aws_route_table_public_route"
  }
}

# You need to associate your subnets to the route
resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_security_group" "web_sg" {
  vpc_id      = aws_vpc.main_vpc.id
  name        = "web_allow_http_https"
  description = "Allow Http/Https inbound traffic and all outbound traffic"
}


resource "aws_vpc_security_group_ingress_rule" "allow_http_traffic" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}


resource "aws_vpc_security_group_ingress_rule" "allow_https_traffic" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 433
  to_port           = 433
  ip_protocol       = "tcp"
}


resource "aws_vpc_security_group_egress_rule" "allow_all_outcomming_traffic" {
  security_group_id = aws_security_group.web_sg.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "rds_allow_postgres_traffic"
}


resource "aws_vpc_security_group_ingress_rule" "allow_postgres_traffic" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv4         = aws_subnet.public_subnet_1.cidr_block
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}


resource "aws_vpc_security_group_egress_rule" "allow_all_db_outcomming_traffic" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}
# If want an extra security layer, we should use network acls as firewalls. By defect, Network acl allows everything, and blocks nothing
# but security groups blocks everything and allows nothing
