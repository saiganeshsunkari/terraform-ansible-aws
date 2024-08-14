variable "vpc_id" {}
variable "publicSubnetCidrBlock" {}

output "webAppSecurityGroupId" {
  value = aws_security_group.webAppSecurityGroup.id
}

resource "aws_security_group" "webAppSecurityGroup" {
  vpc_id = var.vpc_id

  tags = {
    Name = "webAppSecurityGroup"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2SSH" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "ec2HTTP" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "ec2HTTPS" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# resource "aws_vpc_security_group_ingress_rule" "ec2WebApp" {
#   security_group_id = aws_security_group.webAppSecurityGroup.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 3000
#   ip_protocol       = "tcp"
#   to_port           = 3000
# }

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
