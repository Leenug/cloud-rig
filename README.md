# Cloud Rig Terraform
A Terraform playbook to create a cloud gaming rig on AWS, using Parsec.

## Requirements
- Terraform
- Parsec
- RDP Client

## Initial Set up
1. Install Terraform
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and populate your AWS credentials
3. In AWS console create an EBS volume to serve as your "GameDrive" recommended: 100gb (HDD works fine here, no need to pay extra for SSD)
4. populate the `game_ebs_volume_id` variable
5. Run `terraform apply` - this will set up the initial infrastructure

## Configure your base machine
1. When the instance is provisioned in the AWS console right click the instance and press connect, download the RDP config file
2. Using an RDP client dial into your new instance, the username is "Administrator" you can get the password by running `terraform output instance_password`
3. Once connected, [Parsec-Cloud-Preparation-Tool](https://github.com/jamesstringerparsec/Parsec-Cloud-Preparation-Tool) will automatically start. Follow the steps until completion. You can skip installing the Nvidia driver and the auto-login, it should already have been done for you by the user data script.
4. Open the Parsec Client and log in, once this is done you can quit RDP and connect to your machine via Parsec
5. Install and log into your game launchers
6. Using "Disk Manager" in Windows, mount and format your game-drive
7. In steam change the install location for games to the newly mounted game drive
8. Once you're happy with your base machine create an AMI from it in the AWS console, paste the AMI ID into the terraform variables, this will ensure that every subsequent launch will not require any setup.

## Tips
- You can always make tweaks to your base machine, just remember to create a new AMI each time you've made a change, otherwise everything other than items stored on the Game Drive will be reset between launches

## Usage
- Everytime you want to play simply run `terraform apply` wait a few mins and your machine will show up in Parsec
- When you're finished run `terraform destroy`
