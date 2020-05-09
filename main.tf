provider "aws" {
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_ami" "windows_ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

data "external" "local_ip" {
  # curl should (hopefully) be available everywhere
  program = ["curl","https://v4.ident.me/.json"]
}

locals {
  availability_zone = "${var.region}${element(var.allowed_availability_zone_identifier, random_integer.az_id.result)}"
}

resource "random_integer" "az_id" {
  min = 0
  max = length(var.allowed_availability_zone_identifier)
}

resource "random_password" "password" {
  length = 32
  special = false
}

resource "aws_ssm_parameter" "password" {
  name = "cloud-gaming-administrator-password"
  type = "SecureString"
  value = random_password.password.result

  tags = {
    App = var.project-tag
  }
}

resource "aws_security_group" "default" {
  name = "${var.project-tag}-sg"

  tags = {
    App = var.project-tag
  }
}

# Allow rdp connections from the local ip
resource "aws_security_group_rule" "rdp_ingress" {
  type = "ingress"
  description = "Allow rdp connections (port 3389)"
  from_port = 3389
  to_port = 3389
  protocol = "tcp"
  cidr_blocks = ["${data.external.local_ip.result.address}/32"]
  security_group_id = aws_security_group.default.id
}

# Allow vnc connections from the local ip
resource "aws_security_group_rule" "vnc_ingress" {
  type = "ingress"
  description = "Allow vnc connections (port 5900)"
  from_port = 5900
  to_port = 5900
  protocol = "tcp"
  cidr_blocks = ["${data.external.local_ip.result.address}/32"]
  security_group_id = aws_security_group.default.id
}

# Allow rdp connections from the local ip
resource "aws_security_group_rule" "parsec_ingress" {
  type = "ingress"
  description = "Allow Parsec connections (port 8000-8040)"
  from_port = 8000
  to_port = 8040
  protocol = "udp"
  cidr_blocks = ["${data.external.local_ip.result.address}/32"]
  security_group_id = aws_security_group.default.id
}

# Allow outbound connection to everywhere
resource "aws_security_group_rule" "default" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

# Allow steam stream
resource "aws_security_group_rule" "steam_stream_udp_ingress" {
  type = "ingress"
  description = "Allow Steam Streaming connections (port UDP 27031-270036)"
  from_port = 27031
  to_port = 27036
  protocol = "udp"
  cidr_blocks = ["${data.external.local_ip.result.address}/32"]
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "steam_stream_tcp_ingress" {
  type = "ingress"
  description = "Allow Steam Streaming connections (port TCP 27036-270037)"
  from_port = 27036
  to_port = 27037
  protocol = "tcp"
  cidr_blocks = ["${data.external.local_ip.result.address}/32"]
  security_group_id = aws_security_group.default.id
}

# VR Desktop
resource "aws_security_group_rule" "virtual_desktop_tcp_ingress" {
  type = "ingress"
  description = "Allow Virtual Desktop Streaming connections (port TCP 38810-38840)"
  from_port = 38810
  to_port = 38840
  protocol = "tcp"
  cidr_blocks = ["${data.external.local_ip.result.address}/32"]
  security_group_id = aws_security_group.default.id
}

resource "aws_iam_role" "windows_instance_role" {
  name = "${var.project-tag}-instance-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    App = var.project-tag
  }
}

resource "aws_iam_policy" "password_get_parameter_policy" {
  name = "password-get-parameter-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "${aws_ssm_parameter.password.arn}"
    }
  ]
}
EOF
}
resource "aws_iam_policy" "driver_get_object_policy" {
  name = "driver-get-object-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "password_get_parameter_policy_attachment" {
  role = aws_iam_role.windows_instance_role.name
  policy_arn = aws_iam_policy.password_get_parameter_policy.arn
}

resource "aws_iam_role_policy_attachment" "driver_get_object_policy_attachment" {
  role = aws_iam_role.windows_instance_role.name
  policy_arn = aws_iam_policy.driver_get_object_policy.arn
}

resource "aws_iam_instance_profile" "windows_instance_profile" {
  name = "${var.project-tag}-instance-profile"
  role = aws_iam_role.windows_instance_role.name
}

resource "aws_spot_instance_request" "windows_instance" {
  instance_type = var.instance_type
  availability_zone = local.availability_zone
  ami = (length(var.custom_ami) > 0) ? var.custom_ami : data.aws_ami.windows_ami.image_id
  security_groups = [aws_security_group.default.name]
  user_data = templatefile("${path.module}/templates/user_data.tpl", {
    password_ssm_parameter = aws_ssm_parameter.password.name
  })
  iam_instance_profile = aws_iam_instance_profile.windows_instance_profile.id

  # Spot configuration
  spot_type = "one-time"
  wait_for_fulfillment = true

  # EBS configuration
  ebs_optimized = true
  root_block_device {
    volume_size = var.root_block_device_size_gb
  }

  tags = {
    Name = "cloud-gaming-instance"
    App = var.project-tag
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "xvdf"
  volume_id = var.game_ebs_volume_id
  instance_id = aws_spot_instance_request.windows_instance.spot_instance_id
}

output "instance_id" {
  value = aws_spot_instance_request.windows_instance.id
}

output "spot_instance_id" {
  value = aws_spot_instance_request.windows_instance.spot_instance_id
}

output "instance_ip" {
  value = aws_spot_instance_request.windows_instance.public_ip
}

output "instance_password" {
  value = random_password.password.result
  sensitive = true
}
