resource "aws_key_pair" "cloud_2021" {
  key_name   = "cloud_2021"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_vpc" "cloud_2021_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "cloud_2021_vpc"
  }
}

resource "aws_subnet" "cloud_2021_subnet" {
  for_each = var.subnets
  vpc_id                  = aws_vpc.cloud_2021_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloud_2021_subnet"
  }
}

resource "aws_internet_gateway" "cloud_2021_igw" {
  vpc_id = aws_vpc.cloud_2021_vpc.id

  tags = {
    Name = "cloud_2021_igw"
  }
}

resource "aws_route_table" "cloud_2021_rt" {
  vpc_id = aws_vpc.cloud_2021_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_2021_igw.id
  }

  tags = {
    Name = "cloud_2021_rt"
  }
}

resource "aws_route_table_association" "cloud_2021_rta" {
  for_each = var.subnets
  subnet_id      = aws_subnet.cloud_2021_subnet.id
  route_table_id = aws_route_table.cloud_2021_rt.id
}

resource "aws_security_group" "default" {
  for_each = var.security_groups

  name        = each.key
  description = each.value.description
  vpc_id      = aws_vpc.cloud_2021_vpc.id

  dynamic "ingress" {
    for_each = each.value.ingress_rules != null ? each.value.ingress_rules : []

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = each.value.egress_rules != null ? each.value.egress_rules : []


    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}

output "security_group_id" {
  value = { for k, v in aws_security_group.default : k => v.id }
}


resource "aws_instance" "web-instance" {
  for_each = var.ec2
  ami           = "ami-0230bd60aa48260c6"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.cloud_2021.key_name
  availability_zone = [us-east-1a , us-east-1b, us-east-1c]
  
  subnet_id              = aws_subnet.cloud_2021_subnet[each.value.subnet].id
  vpc_security_group_ids = [aws_security_group.default["cloud_2021"].id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd.service
              sudo systemctl enable httpd.service
              sudo echo "<h1> Hello World from $(each.value.server_name) </h1>" > /var/www/html/index.html                   
              EOF 

  tags = {
    Name = var.name
  }
}

resource "aws_eip" "cloud_2021_eip" {
  for_each = var.ec2
  instance = aws_instance.my_cloud_2021_instance.id
  domain   = "vpc"
}

output "my_eip" {
  value = aws_eip.cloud_2021_eip.public_ip
  #value = { for k, v in aws_eip.eip : k => v.public_ip }
}
