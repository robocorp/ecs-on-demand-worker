# Replace this with your state backend of choice.
terraform {
  backend "s3" {
    # This bucket has been created manually.
    # To use S3 backend, create a bucket on your account and
    # change the bucket name below.
    bucket = "ecs-on-demand-worker-example-state-backend"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
