variable "appsync" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${var.appsync.id}"
  retention_in_days = 14
}

resource "aws_appsync_datasource" "none" {
  api_id           = var.appsync.id
  name             = "none"
  type             = "NONE"
}

# resolvers

locals {
	fields = ["test_aws_cognito_user_pools_admin", "test_aws_cognito_user_pools_user", "test_aws_auth_admin", "test_aws_auth_user", "test_nothing",
"test_both_admin", "test_both_user"]
}

resource "aws_appsync_resolver" "Query" {
	for_each = toset(local.fields)
  api_id      = var.appsync.id
  data_source = aws_appsync_datasource.none.name
  type        = "Query"
  field       = each.key
  request_template = <<EOF
{
	"version": "2018-05-29",
	"payload": $util.toJson($ctx.identity)
}
EOF

	response_template = <<EOF
$util.toJson($ctx.result)
EOF
}

