locals {
  github_oidc_host = "token.actions.githubusercontent.com"
  github_main_subject = format(
    "repo:%s@%s/%s@%s:ref:refs/heads/main",
    var.github_owner,
    var.github_owner_id,
    var.github_repository,
    var.github_repository_id,
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.github_oidc_host}"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

data "aws_iam_policy_document" "github_terraform_plan_trust" {
  statement {
    sid     = "GitHubActionsMainBranch"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = [local.github_main_subject]
    }
  }
}

resource "aws_iam_role" "github_terraform_plan" {
  name                 = "${var.project_name}-github-terraform-plan"
  description          = "Read-only Terraform plans from the immutable Fiscora infrastructure repository on main."
  assume_role_policy   = data.aws_iam_policy_document.github_terraform_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_terraform_plan_read_only" {
  role       = aws_iam_role.github_terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "github_terraform_state_lock" {
  statement {
    sid    = "ListTerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid    = "ReadTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/staging/terraform.tfstate",
    ]
  }

  statement {
    sid    = "ManageTerraformStateLockOnly"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/staging/terraform.tfstate.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "github_terraform_state_lock" {
  name   = "${var.project_name}-terraform-state-plan"
  role   = aws_iam_role.github_terraform_plan.id
  policy = data.aws_iam_policy_document.github_terraform_state_lock.json
}
