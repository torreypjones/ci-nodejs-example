terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-west-2"
  default_tags {
    tags = {
      Environment = "Demo"
      managed_by = "terraform"
    }
  }
}

variable GITHUB_PAT {
  type = string
  description = "Github Personal Access token to use when access GH from codebuild projects"
  default = null
}

# for CI/CD of terraform itself; see https://github.com/webmagicinformatica/aws-codepipeline-terraform-cicd-sample
# fargate deployment: https://engineering.sada.com/gke-autopilot-vs-eks-fargate-a695fe687a7d

resource "aws_ecr_repository" "demo_ecr" {
    image_tag_mutability = "MUTABLE"
    force_delete = true #delete repo even if it contains images
    name                 = "ci-nodejs-example"
    encryption_configuration {
        encryption_type = "AES256"
    }
    image_scanning_configuration {
        scan_on_push = false
    }
}

# credentials to use for the codebuild projejct to access GH
# only 1 cred per AWS environment.
# see: https://github.com/hashicorp/terraform-provider-aws/issues/9613

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.GITHUB_PAT
}

variable codebuild_params {
  description = "the biggest config param's for the codebuild project"
  type = object({
    NAME = string
    GIT_REPO = string
    IMAGE = string
    TYPE = string
    COMPUTE_TYPE = string
    CRED_TYPE = string
  })
  default = {
  "NAME" = "ci-nodejs-example"
  "GIT_REPO" = "https://github.com/torreypjones/ci-nodejs-example.git"
  "IMAGE" = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  "TYPE" = "LINUX_CONTAINER"
  "COMPUTE_TYPE" = "BUILD_GENERAL1_SMALL"
  "CRED_TYPE" = "CODEBUILD"
  }
} 

locals {
  environment_variables = {
    "AWS_DEFAULT_REGION" = "us-west-2"
    "AWS_ACCOUNT_ID" = data.aws_caller_identity.current.account_id
    "IMAGE_REPO_NAME" = aws_ecr_repository.demo_ecr.name
    "IMAGE_TAG" = "latest"
    "IMAGE_NAME" = "ci-nodejs-example"
  }
}

##### Iam config
#iam config's are stored in json files so we dont clutter up the TF
data "local_file" "assumeRole_policy" {
  filename = "iam-policy/assumeRole.json"
}

data "local_file" "policy" {
  filename = "iam-policy/policy.json"
}

resource "aws_iam_role" "role" {
  name               = "custom-cloudbuild-${var.codebuild_params.NAME}"
  assume_role_policy = data.local_file.assumeRole_policy.content
}

# for reference to account ID
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "example" {
  role = aws_iam_role.role.name
  policy = replace(
    replace(data.local_file.policy.content, "ACCOUNT_ID", data.aws_caller_identity.current.account_id),
    "CODEBUILD_NAME", var.codebuild_params.NAME
  ) 
}
##### END Iam config



# simple codebuild project
resource "aws_codebuild_project" "codebuild_project" {
  name        = var.codebuild_params.NAME
  description   = "Codebuild demo with Terraform"
  build_timeout = "120"
  service_role = aws_iam_role.role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  project_visibility     = "PRIVATE"
  source {
    type            = "GITHUB"
    location        = lookup(var.codebuild_params, "GIT_REPO")
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  environment {
    image                       = lookup(var.codebuild_params, "IMAGE")
    type                        = lookup(var.codebuild_params, "TYPE")
    compute_type                = lookup(var.codebuild_params, "COMPUTE_TYPE")
    image_pull_credentials_type = lookup(var.codebuild_params, "CRED_TYPE")
    privileged_mode             = true

    dynamic "environment_variable" {
      for_each = local.environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    s3_logs {
      status = "DISABLED"
    }
  }
}