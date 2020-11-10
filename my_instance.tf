#12786236984374093

provider "aws"{
    access_key=""
    secret_key=""
    region="us-east-2"
}

variable "public_key_path" {
	  description = "path to public key to inject into the instances to allow ssh"
	  default     = "~/.ssh/id_rsa.pub"
	}
	
variable "name" {
	  description = "A name to be applied to make everything unique and personal"
	  default     = "lab"
	}

resource "aws_key_pair" "lab_keypair" {
  #enter key_pair
	  key_name   = format("%s%s", var.name, "_keypair")
	  public_key = file(var.public_key_path)
	}

variable "subnets_cidr" {
	  default = ["10.0.0.0/24", "10.0.1.0/24"]
	}


variable "azs" {
	default = ["us-east-2a", "us-east-2b","us-east-2c"]
}

#security groups
resource "aws_security_group" "first-ssh-http" {
  name        = "first-ssh-http"
  description = "allow ssh and http traffic"
  vpc_id = aws_vpc.terra_vpc.id
 
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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
#elastic load balancer
resource "aws_elb" "elb" {
  name               = "terraform-elb"
  security_groups   = [aws_security_group.first-ssh-http.id]
  subnets=["subnet-0ea5c2e75b66c0d56"]
  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }
  instances                   = [aws_instance.Instance-with-volume.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "terraform-elb"
  }
}
#elb attachment
resource "aws_elb_attachment" "first-elb" {
  elb      = aws_elb.elb.id
  instance = aws_instance.Instance-with-volume.id
}
#aws instance with volume
resource "aws_instance" "Instance-with-volume"{
    ami="ami-0b59bfac6be064b78"
    instance_type="t2.micro"
    subnet_id=aws_subnet.public[0].id
    availability_zone = "us-east-2a"
    key_name = aws_key_pair.lab_keypair.id
    vpc_security_group_ids= [aws_security_group.first-ssh-http.id]
    tags = {
        Name = "Instance-with-volume"
  }
}
#subnets
resource "aws_subnet" "public" {
	  count = length(var.subnets_cidr)
	  vpc_id = aws_vpc.terra_vpc.id
    cidr_block=element(var.subnets_cidr,count.index)
    availability_zone=element(var.azs,count.index)
	}

resource "aws_ebs_volume" "data-vol" {
 availability_zone = "us-east-2a"
 size = 1
 tags = {
        Name = "data-volume"
 }
 
}
#volume attachment
 resource "aws_volume_attachment" "first-vol" {
 device_name = "/dev/sdc"
 volume_id = aws_ebs_volume.data-vol.id
 instance_id = aws_instance.Instance-with-volume.id
}
#elastic ips
resource "aws_eip" "default" {
 instance = aws_instance.Instance-with-volume.id
 vpc= true
}

#custom vpc
resource "aws_vpc" "terra_vpc" {
  cidr_block  = "10.0.0.0/16"
  
}
resource "aws_internet_gateway" "terra_igw" {
  vpc_id = aws_vpc.terra_vpc.id
  
}



