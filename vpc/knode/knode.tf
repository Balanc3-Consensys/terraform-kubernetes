# Variables

variable "name" {}

variable "vpc_id" {}

variable "vpc_cidr" {}

variable "key_name" {}

variable "azs" {
  type = "list"
}

variable "subnet_ids" {
  type = "list"
}

variable "zone" {}

variable "size" {}

variable "instance_type" {
  default = "t2.micro"
}

variable "alb_enable" {
  default = false
}

variable "alb_internal" {
  default = true
}

variable "alb_dns_name" {
  default = ""
}

variable "alb_route53_zone_id" {
  default = ""
}

variable "alb_subnet_ids" {
  type    = "list"
  default = []
}

# Resources

module "alb" {
  source = "../network/alb"
  enable = "${var.alb_enable}"

  name            = "${var.name}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = ["${var.alb_subnet_ids}"]
  ports           = ["80"]
  protocols       = ["HTTP"]                     //todo need cert for HTTPS
  health_checks   = ["/lbstatus"]
  internal        = "${var.alb_internal}"
  dns_name        = "${var.alb_dns_name}"
  route53_zone_id = "${var.alb_route53_zone_id}"
}

data "aws_ami" "kubernetes" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["kubernetes"]
  }
}

data "template_file" "start" {
  template = "${file("${path.module}/start.sh")}"

  vars {
    zone = "${var.zone}"
  }
}

resource "aws_launch_configuration" "lc" {
  name                        = "${var.name}"
  instance_type               = "${var.instance_type}"
  image_id                    = "${data.aws_ami.kubernetes.id}"
  key_name                    = "${var.key_name}"
  security_groups             = ["${aws_security_group.sg.id}"]
  associate_public_ip_address = false

  user_data = "${data.template_file.start.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "${var.name}-asg"
  desired_capacity     = "${var.size}"
  min_size             = "${var.size}"
  max_size             = "${var.size}"
  launch_configuration = "${aws_launch_configuration.lc.name}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  target_group_arns    = ["${module.alb.target_group_arns}"]

  tag {
    key                 = "Name"
    value               = "${var.name}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "sg" {
  name   = "${var.name}-sg"
  vpc_id = "${var.vpc_id}"

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    #todo
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
