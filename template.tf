#
# VARIABLES
#
variable "aws_region" {
  description = "AWS region to launch sample"
  default = "us-west-2"
}

variable "oip_vpc_id" {
  default = "vpc-00000000000000000"
}

variable "oip_vpc_private_subnetids" {
  default = [ "subnet-00000000000000000", "subnet-00000000000000000", "subnet-00000000000000000"]
}

#
# PROVIDER
#
provider "aws" {
  region = "${var.aws_region}"
}


#
# DATA
#

# helper to package the lambda function for deployment
data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "lambda/index.js"
  output_path = "lambda_function.zip"
}


#
# RESOURCES
#

resource "aws_iam_role" "instance-role" {
  name = "aws-batch-prescient-role"
  path = "/BatchSample/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement":
    [
      {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          }
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "instance-role" {
  role = "${aws_iam_role.instance-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance-role" {
  name = "aws-batch-prescient-role"
  role = "${aws_iam_role.instance-role.name}"
}

resource "aws_iam_role" "aws-batch-service-role" {
  name = "aws-batch-service-role"
  path = "/BatchSample/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement":
    [
      {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "batch.amazonaws.com"
          }
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws-batch-service-role" {
  role = "${aws_iam_role.aws-batch-service-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_security_group" "prescient-batch" {
  name = "aws-batch-prescient-security-group"
  description = "AWS Batch Sample Security Group"
  vpc_id = "${var.oip_vpc_id}"

  egress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    cidr_blocks     = [ "0.0.0.0/0" ]
  }
}

resource "aws_batch_compute_environment" "prescient" {
  compute_environment_name = "prescient-sample"
  compute_resources {
    instance_role = "${aws_iam_instance_profile.instance-role.arn}"
    instance_type = [
      "optimal"
    ]
    max_vcpus = 6
    min_vcpus = 0
    security_group_ids = [
      "${aws_security_group.prescient-batch.id}"
    ]
    subnets = "${var.oip_vpc_private_subnetids}"

    type = "EC2"
  }
  service_role = "${aws_iam_role.aws-batch-service-role.arn}"
  type = "MANAGED"
  depends_on = [ "aws_iam_role_policy_attachment.aws-batch-service-role" ]
}

resource "aws_batch_job_queue" "prescient" {
  name = "prescient-queue"
  state = "ENABLED"
  priority = 1
  compute_environments = [ 
    "${aws_batch_compute_environment.prescient.arn}"
  ]
}

resource "aws_ecr_repository" "prescient-job-repo" {
  name = "aws-batch-prescient-sample"
}

resource "aws_dynamodb_table" "predict-table" {
  name = "aws-batch-prescient"
  read_capacity = 5
  write_capacity = 5
  hash_key = "ID"

  attribute {
    name = "ID"
    type = "S"
  }
}

resource "aws_iam_role" "job-role" {
  name = "aws-batch-prescient-job-role"
  path = "/BatchSample/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement":
    [
      {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs-tasks.amazonaws.com"
          }
      }
    ]
}
EOF
}

resource "aws_iam_policy" "job-policy" {
  name = "aws-batch-prescient-job-policy"
  path = "/BatchSample/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "${aws_dynamodb_table.predict-table.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "job-role" {
  role = "${aws_iam_role.job-role.name}"
  policy_arn = "${aws_iam_policy.job-policy.arn}"
}

resource "aws_batch_job_definition" "prescient-job" {
  name = "prescient-job"
  type = "container"
  depends_on = [
    "aws_ecr_repository.prescient-job-repo",
    "aws_dynamodb_table.predict-table"
  ]
  parameters = {
    dynamoTable = "${aws_dynamodb_table.predict-table.id}"
  }
  container_properties = <<CONTAINER_PROPERTIES
{
  "image": "${aws_ecr_repository.prescient-job-repo.repository_url}",
  "jobRoleArn": "${aws_iam_role.job-role.arn}",
  "vcpus": 2,
  "memory": 2000,
  "environment": [
    { "name": "AWS_REGION", "value": "${var.aws_region}" }
  ],
  "command": [
    "python3",
    "main.py"
  ]
}
CONTAINER_PROPERTIES
}

## lambda resource + iam
resource "aws_iam_role" "lambda-role" {
  name = "aws-batch-prescient-function-role"
  path = "/BatchSample/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement":
    [
      {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          }
      }
    ]
}
EOF
}

resource "aws_iam_policy" "lambda-policy" {
  name = "aws-batch-prescient-function-policy"
  path = "/BatchSample/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "batch:SubmitJob"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda-service" {
  role = "${aws_iam_role.lambda-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda-policy" {
  role = "${aws_iam_role.lambda-role.name}"
  policy_arn = "${aws_iam_policy.lambda-policy.arn}"
}

resource "aws_lambda_function" "submit-job-function" {
  function_name = "aws-batch-prescient-function"
  filename = "lambda_function.zip"
  role = "${aws_iam_role.lambda-role.arn}"
  handler = "index.handler"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime = "nodejs8.10"
  depends_on = [ "aws_iam_role_policy_attachment.lambda-policy" ]
  environment {
    variables = {
      JOB_DEFINITION = "${aws_batch_job_definition.prescient-job.arn}"
      JOB_QUEUE = "${aws_batch_job_queue.prescient.arn}"
      PREDICT_TABLE = "${aws_dynamodb_table.predict-table.id}"
    }
  }
}


#
# OUTPUTS
#

output "ecr_repository" {
  value = "${aws_ecr_repository.prescient-job-repo.repository_url}"
}
