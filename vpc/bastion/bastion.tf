# Variables

variable "name" {}

variable "vpc_id" {}

variable "vpc_cidr" {}

variable "key_name" {}

variable "subnet_id" {}

variable "instance_type" {
  default = "t2.micro"
}

variable "image_id" {}

variable "alb_route53_zone_id_private" {
  default = ""
}

variable "alb_route53_zone_id_public" {
  default = ""
}

# Resources

data "template_file" "start" {
  template = "${file("${path.module}/start.sh")}"
}

resource "aws_security_group" "bastion" {
  name   = "${var.name}-sg"
  vpc_id = "${var.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  tags {
    Name = "${var.name}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "bastion" {
  ami                         = "${var.image_id}"
  instance_type               = "${var.instance_type}"
  subnet_id                   = "${var.subnet_id}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  associate_public_ip_address = true

  tags {
    Name = "${var.name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Outputs

