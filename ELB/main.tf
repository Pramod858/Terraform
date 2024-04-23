resource "aws_vpc" "project_vpc" {
    cidr_block       = var.vpc_cidr
    instance_tenancy = "default"
    enable_dns_hostnames = true

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

# Application Load Balancer
resource "aws_lb" "test_alb" {
    name               = "test-alb"
    load_balancer_type = "application"
    security_groups    = [aws_security_group.TF_SG.id]
    subnets            = [aws_subnet.public-subnet-1.id,aws_subnet.public-subnet-2.id]
    ip_address_type    = "ipv4" 

    # access_logs {
    #     bucket  = aws_s3_bucket.lb_logs.id
    #     prefix  = "test-alb"
    #     enabled = true
    # }

    tags = {
        Name = "ALB"
    }
}

# Target Group
resource "aws_lb_target_group" "test_tg" {
    name     = "alb-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.project_vpc.id
}

resource "aws_lb_listener" "front_end" {
    load_balancer_arn = aws_lb.test_alb.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.test_tg.arn
    }
}


# Launch template
resource "aws_launch_template" "test_lt" {
    name = "test-lt"
    image_id = var.ami_id
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.TF_SG.id]
    tags = {
    Name = "test_lt"
    }

    user_data = filebase64("./example.sh")
}

# Auto-scaling group
resource "aws_autoscaling_group" "test_asg" {
    desired_capacity    = 2
    max_size            = 4
    min_size            = 2
    vpc_zone_identifier = [aws_subnet.private-subnet-1.id, aws_subnet.private-subnet-2.id]
    health_check_type   = "ELB" 

    launch_template {
        id      = aws_launch_template.test_lt.id
        version = "$Latest"
    }
}

# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "test_asg_attach" {
    autoscaling_group_name = aws_autoscaling_group.test_asg.id
    lb_target_group_arn    = aws_lb_target_group.test_tg.arn
}