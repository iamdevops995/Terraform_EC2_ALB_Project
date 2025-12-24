#VPC Creation
resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr
}
# Subnet creation
resource "aws_subnet" "sub1" {

  vpc_id = aws_vpc.myvpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {

  vpc_id = aws_vpc.myvpc.id
  availability_zone = "us-east-1b"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}
#Internet gateway creation
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
}
# Route table creation
resource "aws_route_table" "rt-01" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
# Route table association
resource "aws_route_table_association" "rta-1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.rt-01.id
}

resource "aws_route_table_association" "rta-2" {
  subnet_id = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt-01.id
}
# Security group creation
resource "aws_security_group" "websg" {
  name        = "web-sg"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "Allow HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "Allow SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}
# EC2 Instance creation for webserver1
resource "aws_instance" "webserver1" {
  ami = "ami-0ecb62995f68bb549"
  instance_type = "t2.micro"
  vpc_security_group_ids= [ aws_security_group.websg.id ]
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("userdata.sh"))
}

# EC2 Instance creation for webserver2
resource "aws_instance" "webserver2" {
  ami = "ami-0ecb62995f68bb549"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.websg.id ]
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("userdata1.sh"))
}

#ALB creation
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.websg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web"
  }
}
# Target group for loadbalancer
resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}
# Attact ec2 instance to target group
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}
# Listener for loadbalancer
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}
# print loadbalancer DNS as output.
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}
