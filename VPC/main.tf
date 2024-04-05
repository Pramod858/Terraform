resource "aws_vpc" "project_vpc" {
    cidr_block       = var.vpc_cidr
    instance_tenancy = "default"

    tags = {
        Name = "Project"
    }
}

resource "aws_subnet" "public-subnet-1" {
    vpc_id = aws_vpc.project_vpc.id
    cidr_block = var.public_sb1_cidr
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "public-subnet-1"
    }
}

resource "aws_subnet" "private-subnet-1" {
    vpc_id = aws_vpc.project_vpc.id
    cidr_block = var.private_sb1_cidr
    availability_zone = "us-east-1a"
    tags = {
        Name = "private-subnet-1"
    }
}

resource "aws_subnet" "public-subnet-2" {
    vpc_id = aws_vpc.project_vpc.id
    cidr_block = var.public_sb2_cidr
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    tags = {
        Name = "public-subnet-2"
    }
}

resource "aws_subnet" "private-subnet-2" {
    vpc_id = aws_vpc.project_vpc.id
    cidr_block = var.private_sb2_cidr
    availability_zone = "us-east-1b"
    tags = {
        Name = "private-subnet-2"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.project_vpc.id
    tags = {
        Name = "iqw"
    }
} 

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.project_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "public-route-table"
    }
}

resource "aws_route_table_association" "rta_to_public1" {
    subnet_id      = aws_subnet.public-subnet-1.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "rta_to_public2" {
    subnet_id      = aws_subnet.public-subnet-2.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "eip" {
    network_border_group = "us-east-1"
    tags = {
        Name = "eip"
    }
}  

resource "aws_nat_gateway" "nat_gw" {
    allocation_id = aws_eip.eip.id
    subnet_id = aws_subnet.private-subnet-1.id
    tags = {
        Name = "nat-gw"
    }
}

resource "aws_route_table" "private_route_table" {
    vpc_id = aws_vpc.project_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.nat_gw.id
    }

    tags = {
        Name = "private-route-table"
    }
}

resource "aws_route_table_association" "rta_to_private1" {
    subnet_id = aws_subnet.private-subnet-1.id
    route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "rta_to_private2" {
    subnet_id = aws_subnet.private-subnet-2.id
    route_table_id = aws_route_table.private_route_table.id
}

# RSA key of size 4096 bits
resource "tls_private_key" "rsa" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
# Create the AWS key pair
resource "aws_key_pair" "TF_key" {
    key_name   = "TF-key"
    public_key = tls_private_key.rsa.public_key_openssh
}

# https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
# Save the private key to a local file
resource "local_file" "TF_key" {
    content  = tls_private_key.rsa.private_key_pem
    filename = "tfkey"
}

# Security Group
resource "aws_security_group" "TF_SG" {
    name        = "security_group_using_terraform"
    description = "security group using terraform"
    vpc_id      = aws_vpc.project_vpc.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "allow SSH"
        }

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "allow HTTP"
        }

    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    }
}

# Launch an EC2 instance using the created key pair
resource "aws_instance" "web" {
    ami                    = var.ami_id  # Specify an appropriate AMI ID
    instance_type          = var.instance_type
    key_name               = aws_key_pair.TF_key.key_name  # Reference the key_name from aws_key_pair resource
    vpc_security_group_ids = [aws_security_group.TF_SG.id]
    subnet_id              = aws_subnet.public-subnet-1.id  # Use subnet ID instead of subnet name
    user_data              = filebase64("./example.sh")
}
