provider "aws" {
  region  = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# VPC
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  
  tags = {
    Name = "Terraform"
  }
}

#IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

#route-table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform route table"
  }
}

#subnet
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr_block
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true 
  tags = {
    Name = "terraformsubnet"
  }
}

#associate route table to subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route-table.id
}

#security group 
resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
 
dynamic "ingress" {
		for_each = var.ingress_rules
		content {
			description = ingress.value["description"]
			from_port   = ingress.value["port"]
			to_port     = ingress.value["port"]
			protocol    = "tcp"
			cidr_blocks = ["0.0.0.0/0"]
		}
	}
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Network interface for idx1
resource "aws_network_interface" "idx1-nic" {
  depends_on=[aws_subnet.subnet1,aws_security_group.web]
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["11.0.1.50"]
  security_groups = [aws_security_group.web.id]
  
}

#Network interface for idx2
resource "aws_network_interface" "idx2-nic" {
  depends_on=[aws_subnet.subnet1,aws_security_group.web]
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["11.0.1.51"]
  security_groups = [aws_security_group.web.id]
}

#Network interface for idx3
resource "aws_network_interface" "idx3-nic" {
  depends_on=[aws_subnet.subnet1,aws_security_group.web]
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["11.0.1.52"]
  security_groups = [aws_security_group.web.id]
}

#Network interface for forwarder
resource "aws_network_interface" "forwarder-nic" {
  depends_on=[aws_subnet.subnet1,aws_security_group.web]
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["11.0.1.53"]
  security_groups = [aws_security_group.web.id]
}

#Network interface for Cluster Master
resource "aws_network_interface" "cm-nic" {
  depends_on=[aws_subnet.subnet1,aws_security_group.web]
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["11.0.1.54"]
  security_groups = [aws_security_group.web.id]
}

resource "aws_network_interface" "sh-nic" {
  depends_on=[aws_subnet.subnet1,aws_security_group.web]
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["11.0.1.55"]
  security_groups = [aws_security_group.web.id]
}

resource "aws_instance" "sh" {

    ami =  "${lookup(var.ec2-ami,var.region)}"
    instance_type = var.instance_type
    key_name = "Crest"
    depends_on = [aws_instance.cm]
    network_interface{
      device_index=0
      network_interface_id= aws_network_interface.sh-nic.id
    }
    provisioner "file" {
      source      = "C:/Users/Varun Ladha/terraform-output-practise/script.sh"
      destination = "/tmp/script.sh"
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
    }
    provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sh /tmp/script.sh",      
       "cd /home/ubuntu/splunk/bin",
        "sudo ./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${var.admin_password}",
        "sudo ./splunk edit cluster-config -mode searchhead -master_uri https://${aws_instance.cm.public_ip}:8089  -auth admin:${var.admin_password}", 
        "sudo ./splunk restart",
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
  }
    tags = {
    Name = "sh-1"
    }
    
}

output "sh_ip_addr" {
  value = aws_instance.sh.public_ip
}


resource "aws_instance" "cm" {

     ami =  "${lookup(var.ec2-ami,var.region)}"
    instance_type = var.instance_type
    key_name = "Crest"
    network_interface{
      device_index=0
      network_interface_id= aws_network_interface.cm-nic.id
    }
    provisioner "file" {
      source      = "C:/Users/Varun Ladha/terraform-output-practise/script.sh"
      destination = "/tmp/script.sh"
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
    }
    provisioner "remote-exec" {
    on_failure = "continue"
    inline = [

    "chmod +x /tmp/script.sh",
    "sh /tmp/script.sh",
    "cd /home/ubuntu/splunk/bin/",
    "sudo ./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${var.admin_password}",
    "sudo ./splunk edit cluster-config -mode manager -replication_factor 3 -search_factor 2 -cluster_label cluster_master -auth admin:${var.admin_password}",
    "sudo ./splunk restart",
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
  }
    tags = {
    Name = "cm"
    }
    
    
}

output "cm_ip_addr" {
  value = aws_instance.cm.public_ip
}

resource "aws_instance" "idx1" {

     ami =  "${lookup(var.ec2-ami,var.region)}"
    instance_type = var.instance_type
    key_name = "Crest"
    depends_on = [aws_instance.cm]
    network_interface{
      device_index=0
      network_interface_id= aws_network_interface.idx1-nic.id
    }
    provisioner "file" {
      source      = "C:/Users/Varun Ladha/terraform-output-practise/script.sh"
      destination = "/tmp/script.sh"
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
    }
    provisioner "remote-exec" {
    on_failure = "continue"
    inline = [
              "chmod +x /tmp/script.sh",
              "sh /tmp/script.sh",
              "cd /home/ubuntu/splunk/bin/",
              "sudo ./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${var.admin_password}",
              "sudo ./splunk enable listen 9997 -auth admin:${var.admin_password}",
              "sudo ./splunk edit cluster-config -mode peer -master_uri https://${aws_instance.cm.public_ip}:8089 -replication_port 8080 -auth admin:${var.admin_password}",
              "sudo ./splunk restart",
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
  }
     tags = {
    Name = "idx-1"
  }
   
}

output "idx1_ip_addr" {
  value = aws_instance.idx1.public_ip
}


resource "aws_instance" "idx2" {

     ami =  "${lookup(var.ec2-ami,var.region)}"
    instance_type = var.instance_type
    key_name = "Crest"
    depends_on = [aws_instance.cm]
    network_interface{
      device_index=0
      network_interface_id= aws_network_interface.idx2-nic.id
    }
     tags = {
    Name = "idx-2"
  }
  provisioner "file" {
      source      = "C:/Users/Varun Ladha/terraform-output-practise/script.sh"
      destination = "/tmp/script.sh"
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
    }
  provisioner "remote-exec" {
    on_failure = "continue"
    inline = [
      "chmod +x /tmp/script.sh",
              "sh /tmp/script.sh",
              "cd /home/ubuntu/splunk/bin/",
              "sudo ./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${var.admin_password}",
              "sudo ./splunk enable listen 9997 -auth admin:${var.admin_password}",
              "sudo ./splunk edit cluster-config -mode peer -master_uri https://${aws_instance.cm.public_ip}:8089 -replication_port 8080 -auth admin:${var.admin_password}",
              "sudo ./splunk restart",
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
  }
  
    
}
output "idx2_ip_addr" {
  value = aws_instance.idx2.public_ip
}

resource "aws_instance" "idx3" {

    ami =  "${lookup(var.ec2-ami,var.region)}"
    instance_type = var.instance_type
    key_name = "Crest"
    depends_on = [aws_instance.cm]
    network_interface{
      device_index=0
      network_interface_id= aws_network_interface.idx3-nic.id
    }
    provisioner "file" {
      source      = "C:/Users/Varun Ladha/terraform-output-practise/script.sh"
      destination = "/tmp/script.sh"
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
    }
    provisioner "remote-exec" {
    on_failure = "continue"
    inline = [
              "chmod +x /tmp/script.sh",
              "sh /tmp/script.sh",
              "cd /home/ubuntu/splunk/bin/",
              "sudo ./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${var.admin_password}",
              "sudo ./splunk enable listen 9997 -auth admin:${var.admin_password}",
              "sudo ./splunk edit cluster-config -mode peer -master_uri https://${aws_instance.cm.public_ip}:8089 -replication_port 8080 -auth admin:${var.admin_password}",
               "sudo ./splunk restart",
    ]
    connection {

      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/Downloads/Crest.pem")}"
      host        = "${self.public_ip}"
      }
  }
     tags = {
    Name = "idx-3"
  } 
}

output "idx3_ip_addr" {
  value = aws_instance.idx3.public_ip
}

resource "aws_instance" "forwarder" {
 
    ami =  "${lookup(var.ec2-ami,var.region)}"
    instance_type = var.instance_type
    key_name = "Crest"
    depends_on = [aws_instance.cm,aws_instance.idx1,aws_instance.idx2,aws_instance.idx3]
    network_interface{
      device_index=0
      network_interface_id= aws_network_interface.forwarder-nic.id
    }
     tags = {
    Name = "forwarder"
  }
   user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo su
    wget -O splunkforwarder-8.1.1-08187535c166-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.1&product=universalforwarder&filename=splunkforwarder-8.1.1-08187535c166-Linux-x86_64.tgz&wget=true'
    tar -xvzf splunkforwarder-8.1.1-08187535c166-Linux-x86_64.tgz
    cd /splunkforwarder/bin
    ./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${var.admin_password}
    ./splunk enable boot-start
    ./splunk add forward-server ${aws_instance.idx1.public_ip}:9997 -auth admin:${var.admin_password}
    ./splunk add forward-server ${aws_instance.idx2.public_ip}:9997 -auth admin:${var.admin_password}
    ./splunk add forward-server ${aws_instance.idx3.public_ip}:9997 -auth admin:${var.admin_password}
    ./splunk add monitor /var/log/syslog -auth admin:admin123
    ./splunk restart
    EOF
    
}

output "forwarder_ip_addr" {
  value = aws_instance.forwarder.public_ip
}



