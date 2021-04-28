variable "access_key"{
type = string
}
variable "secret_key"{
type = string
}
variable "admin_password"{
  type=string
}
variable "region" {
    default="us-east-1"
}
variable "vpc_cidr_block" {
  description= "CIDR BLOCK FOR VPC."
  type = string
}

variable "subnet_cidr_block" {
  description= "CIDR BLOCK FOR SUBNET."
  type = string
}
variable "instance_type"{
  type=string
  default="t2.micro"
}

variable "ec2-ami"{
    type= map
    default={
     us-east-1 = "ami-03d315ad33b9d49c4"
     us-east-2 = "ami-0996d3051b72b5b2c"
    }
}

#dynamically get the availability_zone
data "aws_availability_zones" "available" {
  state = "available"
}

variable "ingress_rules" {
  type = list(object({
    port = number
    description = string
  }))
  default = [
    {
     port = 22
     description = "SSH" 
    }
  ]
}
