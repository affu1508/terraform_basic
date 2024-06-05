# Creating VPC
resource "aws_vpc" "demovpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraform-task"
  }
}

resource "aws_internet_gateway" "demogateway" {
  vpc_id = "${aws_vpc.demovpc.id}"

 tags = {
    Name = "terraform-task"
 }
}


resource "aws_route_table" "route" {
    vpc_id = "${aws_vpc.demovpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.demogateway.id}"
    }

    tags = {
        Name = "terraform-task-RT"
    }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = "${aws_vpc.demovpc.id}"
  cidr_block             = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2a"

  tags = {
    Name = "terraform-task-subnet"
  }
}

resource "aws_route_table_association" "rt1" {
    subnet_id = "${aws_subnet.public-subnet-1.id}"
    route_table_id = "${aws_route_table.route.id}"
}

resource "aws_security_group" "demovpcsg" {
  vpc_id = aws_vpc.demovpc.id

  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-task-SG"
  }
}

resource "aws_instance" "demoinstance" {
  ami                         = "ami-09040d770ffe2224f"
  instance_type               = "t2.micro"
  //count                       = 1
  key_name                    = "terraform-server"
  vpc_security_group_ids      = ["${aws_security_group.demovpcsg.id}"]
  subnet_id                   = "${aws_subnet.public-subnet-1.id}"
  associate_public_ip_address = true
  user_data                   = <<-EOF
                          #!/bin/bash
                          apt update -y
                          apt install -y apache2
                          systemctl start apache2
                          systemctl enable apache2
                          EOF

  tags = {
    Name = "apache-terraform"
  }
}

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.public-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.demovpcsg.id]

  attachment {
    instance     = aws_instance.demoinstance.id
    device_index = 1
   }
tags = {
    Name = "terraform-ni"
} 
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.example.id
  network_interface_id = aws_network_interface.test.id
}
resource "aws_instance" "web" {
  ami               = "ami-09040d770ffe2224f"
  availability_zone = "us-east-2a"
  instance_type     = "t2.micro"
  tags = {
    Name = "EIp-NI"
  }
}
resource "aws_eip" "example" {
  domain = "vpc"
}

resource "aws_s3_bucket" "s3_bucket" {
  
  bucket = "s3backend-05"
  acl = "private"
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "terraform-state-lock-dynamo"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20
  attribute {
    name = "LockID"
    type = "S"
  }
}

terraform {
  backend "s3" {
    bucket = "s3backend-05"
    dynamodb_table = "terraform-state-lock-dynamo"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}




