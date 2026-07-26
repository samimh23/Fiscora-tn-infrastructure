data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "application" {
  statement {
    sid    = "GetEcrAuthorizationToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PullBackendImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "ListDocuments"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [var.documents_bucket_arn]
  }

  statement {
    sid    = "ManageDocuments"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${var.documents_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "application" {
  name   = "${var.name_prefix}-application"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.application.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-instance"
  role = aws_iam_role.instance.name
}

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web"
  description = "Public HTTP and HTTPS access to the Fiscora staging host"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-web"
  }
}

resource "aws_instance" "docker" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user

    install -d -m 0750 -o ec2-user -g ec2-user /opt/fiscora
    cat > /opt/fiscora/DEPLOYMENT_PENDING <<'EOF'
    The host is ready. The backend GitHub Actions deployment will install
    the runtime compose file and start Fiscora after OIDC is configured.
    EOF
    chown ec2-user:ec2-user /opt/fiscora/DEPLOYMENT_PENDING
  USER_DATA

  tags = {
    Name = "${var.name_prefix}-docker"
    Role = "application"
  }
}

