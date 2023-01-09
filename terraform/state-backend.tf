# Replace this with your state backend of choice.
# This example uses Hashicorp Cloud.
terraform {
  cloud {
    organization = "robocorp"
    workspaces {
      # To run terraform locally, set Execution Mode to "Local" in the workspace
      # settings
      name = "ecs-on-demand-worker"
    }
  }
}
