#-------------------------------------------------------

provider "aws" {
  access_key = ""
  secret_key = ""
  region     = "eu-central-1"
}
#доступні зони
data "aws_availability_zones" "available" {
  state = "available"
}
#знайти останню версію лінукс
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
}

#-------------------------------------------------------
#resource "aws_eip" "my_static_ip" {
#  instance = aws_instance.my_webserver.id
#  vpc      = true
#}

#resource "aws_instance" "my_webserver" {
#  ami                    = "ami-0e2031728ef69a466"
#  instance_type          = "t3.micro"
#  vpc_security_group_ids = [aws_security_group.my_webserver.id]
#  user_data              =
#}
#--------------------experiments----------------------
#-----------------------------------------------------

#------створення sec_group--------------------
resource "aws_security_group" "my_webserver" {
  name        = "WebServer Security Group"
  description = "My First SecurityGroup"
  vpc_id      = aws_vpc.web.id

  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = 80
      to_port     = 80
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
}

resource "aws_vpc" "web" {
  cidr_block = "10.0.0.0/16"
}

#----створення лаунч конфігурації----------------

resource "aws_launch_configuration" "web" {
  #name            = "WebServer_LC"
  name_prefix     = "WebServer_LC-"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.my_webserver.id]
  user_data       = file("user_data.sh")    #закинув невеличкий html код

  lifecycle {
    create_before_destroy = true
  }
}

#----------автомасштабування----------------------------

resource "aws_autoscaling_group" "webserver" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB" #ping
  vpc_zone_identifier  = [aws_default_subnet.default_amaz1.id, aws_default_subnet.default_amaz2.id]
  load_balancers       = [aws_elb.web.name]

  tag {
    key                 = "Name"
    value               = "WebServer-in-ASG"
    propagate_at_launch = true
  }
  tag {
    key                 = "Owner"
    value               = "Minmaxx"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------load balancer---------------------------
resource "aws_elb" "web" {
  name               = "web-lb"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.my_webserver.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  /*
#Так, я знаю що він все ж таки потрібен, але він в мене не запрацюавав із-за некорректного сертифікату((
  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }
  */
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }

}

#--------------------Сабнети, які потрібні для автомасштабування------------------------
resource "aws_default_subnet" "default_amaz1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "default_amaz2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}
#===================================================


#-------------дає посилання(тобто днс ім'я) на веб-сайт------------------------
output "web_loadbalancer_url" {
  value = aws_elb.web.dns_name
}
