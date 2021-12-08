provider "aws" {
}

data "aws_region" "current" {}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_appsync_graphql_api" "appsync_cognito_only_deny" {
  name                = "appsync_test_cognito_only_deny"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "DENY"
    user_pool_id   = aws_cognito_user_pool.pool.id
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

resource "aws_appsync_graphql_api" "appsync_cognito_only_allow" {
  name                = "appsync_test_cognito_only_allow"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "ALLOW"
    user_pool_id   = aws_cognito_user_pool.pool.id
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}
data "aws_iam_policy_document" "appsync_push_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}


resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_push_logs.json
}
resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_appsync_graphql_api" "appsync_with_iam_cognito_first" {
  name                = "appsync_test_with_iam_cognito_first"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "ALLOW"
    user_pool_id   = aws_cognito_user_pool.pool.id
  }
  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

resource "aws_appsync_graphql_api" "appsync_with_iam_iam_first" {
  name                = "appsync_test_with_iam_iam_first"
  schema              = file("schema.graphql")
  authentication_type = "AWS_IAM"
  additional_authentication_provider {
    authentication_type = "AMAZON_COGNITO_USER_POOLS"
    user_pool_config {
      user_pool_id = aws_cognito_user_pool.pool.id
    }
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

module "appsync_cognito_only_deny" {
  source  = "./modules/appsync_resources"
  appsync = aws_appsync_graphql_api.appsync_cognito_only_deny
}

module "appsync_cognito_only_allow" {
  source  = "./modules/appsync_resources"
  appsync = aws_appsync_graphql_api.appsync_cognito_only_allow
}

module "appsync_with_iam_cognito_first" {
  source  = "./modules/appsync_resources"
  appsync = aws_appsync_graphql_api.appsync_with_iam_cognito_first
}

module "appsync_with_iam_iam_first" {
  source  = "./modules/appsync_resources"
  appsync = aws_appsync_graphql_api.appsync_with_iam_iam_first
}

# cognito

resource "aws_cognito_user_pool" "pool" {
  name = "test-${random_id.id.hex}"
}

resource "aws_cognito_user_pool_client" "client" {
  name = "client"

  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.pool.id
}

# test user
resource "null_resource" "cognito_users" {
  depends_on = [aws_cognito_user_group.user]
  provisioner "local-exec" {
    command = <<EOF
aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-create-user \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username user \
	--user-attributes Name=email,Value=user@example.com
EOF
  }
  provisioner "local-exec" {
    command = <<EOF
aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-add-user-to-group \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username user \
	--group-name ${aws_cognito_user_group.user.name}
EOF
  }
  provisioner "local-exec" {
    command = <<EOF
aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-set-user-password \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username user \
	--password "Password.1" \
	--permanent
EOF
  }
}

