# Variables

variable "name" {}

variable "vpc_id" {}

variable "ports" {
  type = "list"
}

variable "protocols" {
  type = "list"
}

variable "health_checks" {
  type = "list"
}

variable "subnet_ids" {
  type = "list"
}

variable "internal" {
  default = false
}

variable "enable" {
  default = true
}

variable "route53_zone_id_private" {}

variable "dns_name_private" {}

variable "route53_zone_id_public" {
  default = ""
}

variable "dns_names_public" {
  type    = "list"
  default = []
}

# Resources

resource "aws_alb" "alb" {
  count    = "${var.enable ? 1 : 0}"
  name     = "${var.name}-alb"
  internal = "${var.internal}"

  subnets = [
    "${var.subnet_ids}",
  ]

  security_groups = [
    "${aws_security_group.sg.id}",
  ]
}

resource "aws_alb_listener" "listener" {
  count             = "${var.enable ? length(var.ports) : 0}"
  load_balancer_arn = "${aws_alb.alb.id}"
  port              = "${element(var.ports, count.index)}"
  protocol          = "${element(var.protocols, count.index)}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.atg.*.id, count.index)}"
    type             = "forward"
  }
}

resource "aws_alb_target_group" "atg" {
  count    = "${var.enable ? length(var.ports) : 0}"
  name     = "${var.name}-${element(var.ports, count.index)}-atg"
  vpc_id   = "${var.vpc_id}"
  port     = "${element(var.ports, count.index)}"
  protocol = "${element(var.protocols, count.index)}"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 3600        //1 hour
  }

  health_check {
    path                = "${element(var.health_checks, count.index)}"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_security_group" "sg" {
  count  = "${var.enable ? 1 : 0}"
  name   = "${var.name}-alb-sg"
  vpc_id = "${var.vpc_id}"

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags {
    Name = "${var.name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rules" {
  count             = "${var.enable ? length(var.ports) : 0}"
  security_group_id = "${aws_security_group.sg.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${element(var.ports, count.index)}"
  to_port           = "${element(var.ports, count.index)}"

  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

resource "aws_route53_record" "private" {
  count   = "${var.enable ? 1 : 0}"
  zone_id = "${var.route53_zone_id_private}"
  name    = "${var.dns_name_private}"
  type    = "A"

  alias {
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "public" {
  count   = "${var.enable ? length(var.dns_names_public) : 0}"
  name    = "${element(var.dns_names_public, count.index)}"
  zone_id = "${var.route53_zone_id_public}"
  type    = "A"

  alias {
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
    evaluate_target_health = true
  }
}

# Output

output "target_group_arns" {
  value = [
    "${aws_alb_target_group.atg.*.arn}",
  ]
}

output "alb_arn" {
  value = "${aws_alb.alb.arn}"
}
