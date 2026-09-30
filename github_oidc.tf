resource "aws_iam_openid_connect_provider" "github_actions" {
  count          = var.environment == "dev" ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_jobs_publisher_assume_role" {
  count = var.environment == "dev" ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:sk03167/data-platform-jobs:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "dev_jobs_artifact_publisher" {
  count              = var.environment == "dev" ? 1 : 0
  name               = "lead-de-dev-jobs-artifact-publisher"
  assume_role_policy = data.aws_iam_policy_document.github_jobs_publisher_assume_role[0].json
}

data "aws_iam_policy_document" "dev_jobs_artifact_publish" {
  count = var.environment == "dev" ? 1 : 0

  statement {
    sid       = "ListGlueArtifactPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.glue_artifacts.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["glue-artifacts/*"]
    }
  }

  statement {
    sid    = "WriteGlueArtifactsOnly"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${module.glue_artifacts.bucket_arn}/glue-artifacts/*"]
  }
}

resource "aws_iam_role_policy" "dev_jobs_artifact_publish" {
  count  = var.environment == "dev" ? 1 : 0
  name   = "write-glue-artifacts-only"
  role   = aws_iam_role.dev_jobs_artifact_publisher[0].id
  policy = data.aws_iam_policy_document.dev_jobs_artifact_publish[0].json
}

output "dev_jobs_artifact_publisher_role_arn" {
  description = "IAM role ARN assumed by data-platform-jobs CI to publish dev Glue artifacts."
  value       = try(aws_iam_role.dev_jobs_artifact_publisher[0].arn, null)
}