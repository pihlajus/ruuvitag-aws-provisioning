terraform {
  backend "s3" {
    bucket     = "ruuvitag.aws.slack.state"
    key        = "ruuvitag-aws-slack"
    region     = "eu-north-1"
  }
}
