variable "project-tag" {
  description = "Project Tag"
  type = string
  default = "CloudRig"
}

variable "s3_backend_bucket" {
  description = "S3 Bucket name to store state"
  type = string
}

variable "region" {
  description = "The aws region."
  type = string
}

variable "aws_access_key" {
  description = "The aws access key."
  type = string
}

variable "aws_secret_key" {
  description = "The aws secret key."
  type = string
}

variable "allowed_availability_zone_identifier" {
  description = "The allowed availability zone identify (the letter suffixing the region)."
  type = list(string)
  default = ["a"]
}

variable "instance_type" {
  description = "The aws instance type"
  type = string
  default = "g4dn.xlarge"
}

variable "root_block_device_size_gb" {
  description = "The size of the root block device (C:\\ drive) attached to the instance"
  type = number
  default = 120
}

variable "game_ebs_volume_id" {
  description = "The Persistent EBS Volume ID for the game drive"
  type = string
  default = ""
}

variable "custom_ami" {
  description = "Custom AMI (For Post First Run)"
  type = string
  default = ""
}
