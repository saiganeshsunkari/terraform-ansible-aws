module "networking" {
  source               = "./networking"
  cidr_public_subnet   = var.cidr_public_subnet
  eu_availability_zone = var.eu_availability_zone
}

module "security_group" {
  source                = "./securityGroups"
  publicSubnetCidrBlock = tolist(module.networking.publicSubnetCidrBlock)
  vpc_id                = module.networking.webAppVpcId
}

module "ec2" {
  source                        = "./ec2"
  public_key                    = var.public_key
  webAppSgId                    = module.security_group.webAppSecurityGroupId
  webAppSubnetId                = tolist(module.networking.webAppPublicSubnetId)[0]
  user_data_install_gitea_nginx = templatefile("./template/ec2_gitea_nginx.sh", {})
}