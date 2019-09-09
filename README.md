# aws-batch-prescient

The sample code contains the following:

* *template.tf* - [Terraform](https://www.terraform.io/) plan containing the AWS resources required (e.g. AWS Batch Job Queue and Job Definition).
* */job* - assets to execute the batch job.
* */lambda* - [AWS Lambda](https://aws.amazon.com/lambda/) function used to submit / start the batch job.

## Create AWS Resources with Terraform

For this project, we will use Terraform to deploy our AWS Resources. These includes various Batch components (Compute Environnment, Job Queue, and Job Definition) as well as a Lambda function and related IAM Roles.

```
# initialize the terraform environment
$ terraform init

# review the plan
$ terraform plan

# deploy...
$ terraform apply
```

## Build and Push Docker Image

Once finished, Terraform will output the name of your newly created ECR Repository, e.g. `123456789098.dkr.ecr.us-east-1.amazonaws.com/aws-batch-prescient-sample`. Note this value as we will use it in subsequent steps (referred to as `MY_REPO_NAME`):

```
$ cd job

# build the docker image
$ docker build -t aws-batch-prescient-sample .

# tag the image
$ docker tag aws-batch-prescient-sample:latest <MY_REPO_NAME>:latest

# push the image to the repository
docker push <MY_REPO_NAME>:latest
```

Pushing the image may take several minutes.

## Invoke Lambda to Submit Batch Job

Finally, let's invoke our Lambda function to submit a new batch job.

```
$ aws lambda invoke --function-name aws-batch-prescient-function out
```

## Authors
* **Redfive410** - *derivative work*
* **Josh Kahn** - *initial work*