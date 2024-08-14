variable "user_data_install_gitea_nginx" {}
variable "webAppSgId" {}
variable "webAppSubnetId" {}
variable "public_key" {}

resource "aws_instance" "webAppEc2Instance" {
  ami           = "ami-00060fac2f8c42d30"
  instance_type = "t2.micro"
  key_name      = "terraform_key"
  associate_public_ip_address = true
  user_data     = var.user_data_install_gitea_nginx
  vpc_security_group_ids = [var.webAppSgId]
  subnet_id = var.webAppSubnetId
  metadata_options {
    http_endpoint = "enabled"  # Enable the IMDSv2 endpoint
    http_tokens   = "required" # Require the use of IMDSv2 tokens
  }

  tags = {
    Name = "webAppEc2Instance"
  }
}

resource "aws_key_pair" "dev_proj_1_public_key" {
  key_name   = "terraform_key"
  public_key = var.public_key
}