# Que deberia agregar para tener una instance aws_instance por defecto para ese servicio "example", pero en el autoscalado usar solo los spot

# Para tener una instancia EC2 On-Demand por defecto para un servicio "example" y usar solo instancias spot en el autoescalado, puedes seguir estos pasos:

# Crea una instancia EC2 On-Demand usando el recurso "aws_instance" y asígnale un nombre identificativo, como "example-ondemand-instance".
# Copy code
resource "aws_instance" "example_ondemand" {
  ami           = "ami-0e094855ce95c71c6"
  instance_type = "t3.micro"

  tags = {
    Name = "example-ondemand-instance"
  }
}
# Crea un grupo de autoescalado usando el recurso "aws_autoscaling_group" y asígnale un nombre identificativo, como "example-asg". En este recurso, especifica que utilice el recurso "aws_launch_template" previamente creado con el precio spot deseado.
# Copy code
resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = [aws_subnet.example_public.id]
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
}
# Crea un servicio ECS usando el recurso "aws_ecs_service" y asocia el grupo de autoescalado creado anteriormente.
# Copy code
resource "aws_ecs_service" "example" {
  name                   = "example"
  cluster                = aws_ecs_cluster.example.id
  task_definition        = aws_ecs_task_definition.example.arn
  desired_count          = 2
  launch_type            = "EC2"
  autoscaling_group_name = aws_autoscaling_group.example.name
}
# Con estos pasos, tendrás una instancia EC2 On-Demand "example-ondemand-instance" y un grupo de autoescalado "example-asg" que usa solo instancias spot para escalar automáticamente el servicio "example".
