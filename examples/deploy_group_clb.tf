provider "aws" {
  version = "~> 1.2"
  region  = "us-east-1"
}

data "aws_ami" "amz_linux_2" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.0.4"

  vpc_name = "Test1VPC"
}

module "security_groups" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//?ref=v0.0.5"

  resource_name = "Test-SG"
  vpc_id        = "${module.vpc.vpc_id}"
  environment   = "Production"
}

module "clb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-clb//?ref=v0.0.2"

  clb_name                    = "CodeDeployExample-CLB"
  instances                   = []
  security_groups             = ["${module.security_groups.public_web_security_group_id}"]
  subnets                     = "${module.vpc.public_subnets}"
  connection_draining_timeout = 300

  listeners = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]
}

module "asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg//?ref=v0.0.6"

  ec2_os                   = "amazon"
  image_id                 = "${data.aws_ami.amz_linux_2.image_id}"
  install_codedeploy_agent = "True"
  instance_type            = "t2.micro"
  load_balancer_names      = ["${module.clb.clb_name}"]
  resource_name            = "CodeDeployExample"
  security_group_list      = ["${module.security_groups.private_web_security_group_id}"]
  scaling_max              = "2"
  scaling_min              = "1"
  subnets                  = ["${element(module.vpc.public_subnets, 0)}", "${element(module.vpc.public_subnets, 1)}"]
}

module "codedeploy" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-codedeploy//?ref=v0.0.1"

  application_name      = "MyCodeDeployApp"
  autoscaling_groups    = ["${module.asg.asg_name_list}"]
  clb_name              = "${module.clb.clb_name}"
  deployment_group_name = "MyCodeDeployDeploymentGroup"
}
