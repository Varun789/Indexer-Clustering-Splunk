access_key = ""
secret_key = ""
region = "us-east-1"
admin_password="admin123"
vpc_cidr_block="11.0.0.0/16"
subnet_cidr_block="11.0.1.0/24"
ingress_rules = [{
		port        = 443
		description = "Port 443"
	},
  {
		port        = 9997
		description = "forwarderingestion"
	},
	{
		port        = 8000
		description = "splunkd"
	},
  {
		port        = 8089
		description = "Peering"
	},
  {
		port        = 22
		description = "SSH"
	},
	  {
		port        = 8080
		description = "tcp"
	}]
instance_type = "t3.micro"
    