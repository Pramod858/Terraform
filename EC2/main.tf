provider "aws" {
    region = "us-east-1"  # Set your desired AWS region
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

# Launch an EC2 instance using the created key pair
resource "aws_instance" "web" {
    ami           =  var.ami_id  # Specify an appropriate AMI ID
    instance_type = var.instance_type
    security_groups = [aws_security_group.TF_SG.name]
    # key_name      = aws_key_pair.TF_key.key_name  # Reference the key_name from aws_key_pair resource
    key_name = aws_key_pair.TF_key.key_name
}

resource "aws_security_group" "TF_SG" {
    name        = "security_group_using_terraform"
    description = "security group using terraform"
    vpc_id      = "vpc-0d302a54a6ebd6d97"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "allow SSH"
        }
}
