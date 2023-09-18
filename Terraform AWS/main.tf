provider "aws" {
  region = "sa-east-1" //SUA REGIÃO
  access_key = "" //SUA ACCESS KEY
  secret_key = "" //SUA SECRET KEY
}

//VPC
resource "aws_vpc" "tdc_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tdc_vpc"
  }
}

//SUBNETS
resource "aws_subnet" "tdc_public_subnet" {
  vpc_id     = aws_vpc.tdc_vpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "sa-east-1a"
  tags = {
    Name = "tdc_public_subnet"
  }
}

resource "aws_subnet" "tdc_private_subnet" {
  vpc_id     = aws_vpc.tdc_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "sa-east-1c" 
  tags = {
    Name = "tdc_private_subnet"
  }
}

//EIP
resource "aws_eip" "tdc_nat_eip" {
  vpc = true
  
  tags = {
    Name = "tdc_nat_eip"
  }
}


//INTERNET GATEWAY
resource "aws_internet_gateway" "tdc_igw" {
  vpc_id = aws_vpc.tdc_vpc.id

  tags = {
    Name = "tdc_igw"
  }
}

//NAT GATEWAY
resource "aws_nat_gateway" "tdc_nat_gw" {
  subnet_id     = aws_subnet.tdc_public_subnet.id
  allocation_id = aws_eip.tdc_nat_eip.id

  tags = {
    Name = "tdc_nat_gw"
  }
}


//ROUTE PUBLIC
resource "aws_route_table" "tdc_public_route_table" {
  vpc_id = aws_vpc.tdc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tdc_igw.id
  }

  tags = {
    Name = "tdc_public_route_table"
  }
}

resource "aws_route_table_association" "tdc_public_route_table_association" {
  subnet_id      = aws_subnet.tdc_public_subnet.id
  route_table_id = aws_route_table.tdc_public_route_table.id
}

//ROUTE PRIVATE
resource "aws_route_table" "tdc_private_route_table" {
  vpc_id = aws_vpc.tdc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tdc_nat_gw.id
  }

  tags = {
    Name = "tdc_private_route_table"
  }
}

resource "aws_route_table_association" "tdc_private_route_table_association" {
  subnet_id      = aws_subnet.tdc_private_subnet.id
  route_table_id = aws_route_table.tdc_private_route_table.id
}


//SECURITY GROUPS
resource "aws_security_group" "tdc_elb_sg" {
  name        = "tdc_elb_sg"
  description = "Allow inbound traffic for ELB"
  vpc_id      = aws_vpc.tdc_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tdc_ec2_sg" {
  name        = "tdc_ec2_sg"
  description = "Allow inbound traffic for EC2"
  vpc_id      = aws_vpc.tdc_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//S3
resource "aws_s3_bucket" "lab_tdc" {
  bucket = "tdc-rhangelc"  
  acl    = "private"
}

//IAM POLICY
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3AccessPolicy"
  description = "Permite operações de leitura e escrita no bucket S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.lab_tdc.arn}",
          "${aws_s3_bucket.lab_tdc.arn}/*"
        ]
      }
    ]
  })
}

//IAM ROLE
resource "aws_iam_role" "ec2_s3_role" {
  name = "EC2S3Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.ec2_s3_role.name
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "EC2S3Profile"
  role = aws_iam_role.ec2_s3_role.name
}


//EC2
resource "aws_instance" "tdc_web_app_1" {
  ami           = "ami-0af6e9042ea5a4e3e"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.tdc_private_subnet.id
  vpc_security_group_ids = [aws_security_group.tdc_ec2_sg.id]
  key_name      = "SUA_KEY"
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name 

  tags = {
    Name = "tdcWebAppInstance-1"
  }
}

resource "aws_instance" "tdc_web_app_2" {
  ami           = "ami-0af6e9042ea5a4e3e"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.tdc_private_subnet.id
  vpc_security_group_ids = [aws_security_group.tdc_ec2_sg.id]
  key_name      = "SUA_KEY"
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  tags = {
    Name = "tdcWebAppInstance-2"
  }
}

//ELB
resource "aws_elb" "tdc_web_elb" {
  name = "tdc-web-elb"

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances       = [aws_instance.tdc_web_app_1.id, aws_instance.tdc_web_app_2.id]
  subnets         = [aws_subnet.tdc_public_subnet.id, aws_subnet.tdc_private_subnet.id]
  security_groups = [aws_security_group.tdc_elb_sg.id]


  tags = {
    Name = "tdcWebELB"
  }
}