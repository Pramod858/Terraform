variable "vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "public_sb1_cidr" {
    default = "10.0.0.0/24"
}

variable "private_sb1_cidr" {
    default = "10.0.1.0/24"
}

variable "public_sb2_cidr" {
    default = "10.0.2.0/24"
}

variable "private_sb2_cidr" {
    default = "10.0.3.0/24"
}

variable "ami_id" {
    default = "ami-07d9b9ddc6cd8dd30"
}

variable "instance_type" {
    default = "t2.micro"
}