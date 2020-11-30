terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=3.15.0"
    }
  }
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

# AMI Data Source
data "aws_ami" "amisource" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Creating the VPC
resource "aws_vpc" "Demo-VPC" {
  cidr_block        = "10.0.0.0/16"
  enable_dns_support  = true
  enable_dns_hostnames = true
  instance_tenancy    = "default"
}

# Creating the Subnet 
resource "aws_subnet" "Subnet" {
  vpc_id                  = aws_vpc.Demo-VPC.id
  cidr_block             = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    name = "Zone Subnet"
  }
}

# Creating the Internet Gateway

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.Demo-VPC.id

  tags = {
    name = "Internet Gateway"
  }
}

# Creating the Route table

resource "aws_route_table" "Route-table" {
  vpc_id = aws_vpc.Demo-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    name = "Route-table"
  }
}

# Create a route table association

resource "aws_route_table_association" "Route-association" {
  subnet_id      = aws_subnet.Subnet.id
  route_table_id = aws_route_table.Route-table.id

}

# Create a security group

resource "aws_security_group" "TestSG" {
  vpc_id = aws_vpc.Demo-VPC.id  

  name = "SSH-and-HTTP-Traffic-Group"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
      cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a Key_pair

resource "aws_key_pair" "Key_in" {
  key_name   = "Terra-test"
  public_key = file(var.pub_key)
}
# Create EC2 instance

resource "aws_instance" "nginx" {
  vpc_security_group_ids = [aws_security_group.TestSG.id]
  ami                    = data.aws_ami.amisource.id
  subnet_id              = aws_subnet.Subnet.id
  instance_type          = "t2.micro"
  key_name               = "Terra-test"

  connection {
      type = "ssh"
      host = self.public_ip
      user = "ec2-user"
      private_key = file(var.privatekey)
      port = 22
      timeout = "2m"
    }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install nginx",
      "sudo service nginx start",
    ]

  }
}

output "fqdn" {
    value = aws_instance.nginx.public_dns
}