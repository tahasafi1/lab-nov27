resource "aws_key_pair" "key" {
  key_name   = "${var.prefix}-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_vpc" "vpc-main" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

##

resource "aws_subnet" "subnet-main" {
  for_each = var.subnet
  vpc_id     = aws_vpc.vpc-main.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = "${var.prefix}-${each.key}"
  }
}

resource "aws_internet_gateway" "igw-main" {
  vpc_id = aws_vpc.vpc-main.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

resource "aws_route_table" "public-route-table-main" {
  vpc_id = aws_vpc.vpc-main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-main.id
  }

  tags = {
    Name = "${var.prefix}-public-route-table"
  }
}

#associate route table w/ each subnet created
resource "aws_route_table_association" "public-rta-association" {
  for_each = var.subnet
  subnet_id      = aws_subnet.subnet-main[each.key].id
  route_table_id = aws_route_table.public-route-table-main.id
}

resource "aws_security_group" "default" {
  for_each = var.security_groups

  name        = each.key
  description = each.value.description
  vpc_id      = aws_vpc.vpc-main.id

  dynamic "ingress" {
    for_each = each.value.ingress_rules #!= null ? each.value.ingress_rules : []

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = each.value.egress_rules #!= null ? each.value.egress_rules : []


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
  key_name      = aws_key_pair.key.key_name
#   availability_zone = [us-east-1a , us-east-1b, us-east-1c]
  
  subnet_id              = aws_subnet.subnet-main[each.value.subnet].id
  vpc_security_group_ids = [aws_security_group.default["app_sg"].id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd.service
              sudo systemctl enable httpd.service
              sudo echo "<h1> Hello world from $(each.value.server_name) </h1>" > /var/www/html/index.html                   
              EOF 

  tags = {
    Name = "${var.prefix}-${each.key}"
  }
}

resource "aws_eip" "eip" {
  for_each = var.ec2
  instance = aws_instance.web-instance[each.key].id
  domain   = "vpc"
}

output "my_eip" {
  #value = aws_eip.eip.public_ip
  value = { for k, v in aws_eip.eip : k => v.public_ip }
}
