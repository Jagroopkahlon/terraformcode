terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "jagroop-singh-1993"
    key    = "terraformstate_file"
    region = "us-east-2"
  }
}


# Configure the AWS Provider
provider "aws" {
  region = var.region
}

# creating ec2 machine
resource "aws_instance" "Hellojagroop" {
  ami           = "ami-09a93c79e10520e27"
  instance_type = "t2.micro"
  key_name = aws_key_pair.terraform-demo-key.id
  vpc_security_group_ids = [ aws_security_group.allow_port_22.id]
  subnet_id = aws_subnet.us-east-2a.id
  user_data = filebase64("userdata.sh")
  
  tags = {
    Name = "Hellojagroop"
  }
}

resource "aws_instance" "Hellojagroop2" {
  ami           = "ami-09a93c79e10520e27"
  instance_type = "t2.micro"
  key_name = aws_key_pair.terraform-demo-key.id
  vpc_security_group_ids = [ aws_security_group.allow_port_22.id]
  subnet_id = aws_subnet.us-east-2b.id
  user_data = filebase64("userdata.sh")
  
  tags = {
    Name = "Hellojagroop2"
  }
}

#create key pair
resource "aws_key_pair" "terraform-demo-key" {
  key_name   = "terraform-demo-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILPf9GDlzWNFoxyfY3kmtZnkZajc0n4uNkGkKzUXhu8H 13065@Jagroop-laptop"
}

#creating vpc
resource "aws_vpc" "amanpreet" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "amanpreet"
  }
}

#creating subnet from amanpreet vpc
resource "aws_subnet" "us-east-2a" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.0.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2a"

  tags = {
    Name = "demo-subnet-2a"
  }
}

resource "aws_subnet" "us-east-2b" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2b"

  tags = {
    Name = "demo-subnet-2b"
  }
}

resource "aws_subnet" "us-east-2c" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.2.0/24"

  tags = {
    Name = "demo-subnet-2c"
  }
}

#create security group
resource "aws_security_group" "allow_port_22" {
  name        = "allow_port_22"
  description = "Allow ssh inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.amanpreet.id

  tags = {
    Name = "allowport22"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_port_22" {
  security_group_id = aws_security_group.allow_port_22.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_port_80" {
  security_group_id = aws_security_group.allow_port_22.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.allow_port_22.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# attach internet gateway to VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.amanpreet.id

  tags = {
    Name = "terraform IG"
  }
}

# attach route table to public IG
resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.amanpreet.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PUBLIC ROUTETABLE"
  }
}

resource "aws_route_table_association" "RT_asscociation" {
  subnet_id      = aws_subnet.us-east-2a.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table_association" "RT_asscociation2" {
  subnet_id      = aws_subnet.us-east-2b.id
  route_table_id = aws_route_table.public_RT.id
}

#attach RT to private subnet
resource "aws_route_table" "private_RT" {
  vpc_id = aws_vpc.amanpreet.id

  tags = {
    Name = "private ROUTETABLE"
  }
}
resource "aws_route_table_association" "RT_asscociation3" {
  subnet_id      = aws_subnet.us-east-2c.id
  route_table_id = aws_route_table.private_RT.id
}

#create target group
resource "aws_lb_target_group" "targetgroup1" {
  name     = "target1a"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.amanpreet.id
}

resource "aws_lb_target_group_attachment" "apachetragetgroup" {
  target_group_arn = aws_lb_target_group.targetgroup1.arn
  target_id        = aws_instance.Hellojagroop.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "apachetragetgroup2" {
  target_group_arn = aws_lb_target_group.targetgroup1.arn
  target_id        = aws_instance.Hellojagroop2.id
  port             = 80
}

#create listener
resource "aws_lb_listener" "demolblistener" {
  load_balancer_arn = aws_lb.terraformLB.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targetgroup1.arn
  }
}

#create loadbalancer
resource "aws_lb" "terraformLB" {
  name               = "terraformLB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_port_22.id]
  subnets            = [aws_subnet.us-east-2a.id,aws_subnet.us-east-2b.id]

  tags = {
    Environment = "production"
  }
}

#launch template for ASG
resource "aws_launch_template" "apacheLT" {
name = "apacheLT"
image_id = "ami-09a93c79e10520e27"
 instance_type = "t2.micro"
 key_name = aws_key_pair.terraform-demo-key.id
vpc_security_group_ids = [aws_security_group.allow_port_22.id]
 tag_specifications {
    resource_type = "instance"
tags = {
      Name = "LT"
    }
  }
 user_data = filebase64("userdata.sh")
}
 
#create ASG
resource "aws_autoscaling_group" "ASGNEW" {
  vpc_zone_identifier = [ aws_subnet.us-east-2a.id, aws_subnet.us-east-2b.id ]
  desired_capacity   = 2
  max_size           = 4
  min_size           = 2
  target_group_arns = [ aws_lb_target_group.targetgroup_2.arn ]

  launch_template {
    id      = aws_launch_template.apacheLT.id
    version = "$Latest"
  }
}

# create ALB with ASG

resource "aws_lb" "terraformLB_2" {
  name               = "terraformLB-2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_port_22.id]
  subnets            = [aws_subnet.us-east-2a.id,aws_subnet.us-east-2b.id]

  tags = {
    Environment = "production"
  }
}

# create listener with ASG
resource "aws_lb_listener" "demolblistener_2" {
  load_balancer_arn = aws_lb.terraformLB_2.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targetgroup_2.arn
  }
}

#CREATE target group with ASG
resource "aws_lb_target_group" "targetgroup_2" {
  name     = "target-2a"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.amanpreet.id
}


