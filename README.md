
# Secure Gitea application with Mutual TLS Using Infrastructure as Code (IaC)

The objective is to set up Gitea application on an AWS instance using mutual TLS (mTLS) for authentication and secure the entire infrastructure using Infrastructure as Code (IaC) tools like Terraform,Ansible.


## Create variables.tf in the infra folder for defining variables that we use in terraform configurations

variables.tf

```bash
variable "cidr_public_subnet" {
  type        = list(string)
  description = "Public subnets"
}

variable "eu_availability_zone" {
  type        = list(string)
  description = "Availability zones"
}
```
## Create the terraform.tfvars file in infra folder where we initialise the values to the variables defined in variables.tf file

terraform.tfvars

```bash
cidr_public_subnet   = ["10.0.1.0/24", "10.0.2.0/24"]
eu_availability_zone = ["eu-central-1a", "eu-central-1b"]
```
## Create provider.tf in the infra folder in which we provide provider,region and credential details for terraform to connect to aws

provider.tf

```bash
provider "aws" {
  region                   = "eu-central-1"
  shared_credentials_files = ["~/.aws/credentials"]
}
```

# Add shell script /infra/template folder with instrcution to install Gitea application and nginx as shown below:

ec2_gitea_nginx.sh

```bash
#! /bin/bash
sudo groupadd --system git
sudo adduser --system --shell /bin/bash --comment 'Git Version Control' --gid git --home-dir /home/git --create-home git
wget -O gitea https://dl.gitea.io/gitea/1.20.4/gitea-1.20.4-linux-amd64
sudo mv gitea /usr/local/bin/
sudo chmod +x /usr/local/bin/gitea
sudo mkdir -p /var/lib/gitea/{custom,data,log}
sudo chown -R git:git /var/lib/gitea/
sudo chmod -R 750 /var/lib/gitea/
sudo mkdir -p /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea
sudo touch /etc/systemd/system/gitea.service
sudo chmod -R 777 /etc/systemd/system/gitea.service
sudo cat <<EOF >/etc/systemd/system/gitea.service
[Unit]
Description=Gitea
After=syslog.target
After=network.target
After=mysqld.service
After=postgresql.service
After=memcached.service
After=redis.service

[Service]
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
RuntimeDirectory=gitea
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl start gitea
sudo systemctl enable gitea
#Install nginx
dnf search nginx
sudo dnf install nginx -y
```




## Create networking module in infra folder and create main.tf with instructions to create vpx, subnets, Internet gateway, route tables etc in the module as shown below

main.tf

```bash
variable "cidr_public_subnet" {}
variable "eu_availability_zone" {}

output "webAppVpcId" {
  value = aws_vpc.webAppVpc.id
}

output "publicSubnetCidrBlock" {
  value = aws_subnet.webAppVpcPublicSubnet.*.cidr_block
}

output "webAppPublicSubnetId" {
  value = aws_subnet.webAppVpcPublicSubnet.*.id
}

resource "aws_vpc" "webAppVpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "webAppVpc"
  }
}

resource "aws_subnet" "webAppVpcPublicSubnet" {
  vpc_id = aws_vpc.webAppVpc.id
  count = length(var.cidr_public_subnet)
  cidr_block = element(var.cidr_public_subnet, count.index)
  availability_zone = element(var.eu_availability_zone, count.index)

  tags = {
    Name = "webAppVpcPublicSubnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "webAppInternetGateway" {
  vpc_id = aws_vpc.webAppVpc.id

  tags = {
    Name = "webAppInternetGateway"
  }
}

resource "aws_route_table" "webAppPublicSubnetRouteTable" {
  vpc_id = aws_vpc.webAppVpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webAppInternetGateway.id
  }

  tags = {
    Name = "webAppPublicSubnetRouteTable"
  }
}

resource "aws_route_table_association" "webAppPublicSubnetRouteTableAssociation" {
  route_table_id = aws_route_table.webAppPublicSubnetRouteTable.id
  count = length(aws_subnet.webAppVpcPublicSubnet)
  subnet_id = aws_subnet.webAppVpcPublicSubnet[count.index].id
}
```
    
## Create securityGroups module in infra folder and create main.tf with instructions to create security group with necessary security group rules

main.tf

```bash
variable "vpc_id" {}
variable "publicSubnetCidrBlock" {}

output "webAppSecurityGroupId" {
  value = aws_security_group.webAppSecurityGroup.id
}

resource "aws_security_group" "webAppSecurityGroup" {
  vpc_id = var.vpc_id

  tags = {
    Name = "webAppSecurityGroup"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2SSH" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "ec2HTTP" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "ec2HTTPS" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "ec2WebApp" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  ip_protocol       = "tcp"
  to_port           = 3000
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.webAppSecurityGroup.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
```
## Create ec2 module in infra folder and create main.tf with instructions to create ec2 instance with user-data

main.tf

```bash
variable "user_data_install_gitea_nginx" {}
variable "webAppSgId" {}
variable "webAppSubnetId" {}

resource "aws_instance" "webAppEc2Instance" {
  ami           = "ami-00060fac2f8c42d30"
  instance_type = "t2.micro"
  key_name      = "terraform_ec2_key"
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
  key_name   = "terraform_ec2_key"
  public_key = "${file("terraform_ec2_key.pub")}"
}
```
## Create main main.tf in the infra folder to invoke the modules that we created in the previous steps

main.tf

```bash
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
  webAppSgId                    = module.security_group.webAppSecurityGroupId
  webAppSubnetId                = tolist(module.networking.webAppPublicSubnetId)[0]
  user_data_install_gitea_nginx = templatefile("./template/ec2_gitea_nginx.sh", {})
}
```
## Run Terraform configuration

We need initialise terraform to download the required dependencies and then we can alo validate if the configuration is correct and then we need to apply the terraform configuration which create terraform plan on all the resoouces it is going to create. We can validate it and if we are satisfied then we can type yes in the prompt and press enter to create the resources using the following commands.

```bash
terraform init
terraform validate
terraform apply
```

Now we have ec2 instance that is create in a vpc along with Gitea application and nginx installed.
## Configure Nginx

Now in the ec2 instance we need to configure nginx reverse proxy along with ssl for our Gitea application deplyed on ec2

## Create configuration folder in the project root directory and create shell script configure_nginx.sh in the same folder which contains instructions to configure nginx as shown below

configure_nginx.sh

```bash
#Create certs
sudo mkdir -p /etc/nginx/ssl/
cd /etc/nginx/ssl/
#Generate root ca certs
openssl genpkey -algorithm RSA -out ca.key
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt -subj "/C=US/ST=Example/L=City/O=Company/OU=IT/CN=RootCA"
# Generate client certificate
openssl genpkey -algorithm RSA -out client.key
openssl req -new -key client.key -out client.csr -subj "/C=US/ST=Example/L=City/O=Company/OU=IT/CN=Sais-MacBook-Air.local"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256
#Generate certs
openssl genpkey -algorithm RSA -out server.key
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=Example/L=City/O=Company/OU=IT/CN=ec2-18-194-15-21.eu-central-1.compute.amazonaws.com"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
#Copy nginx conf
sudo touch /etc/nginx/conf.d/gitea.conf
sudo chmod -R 777 /etc/nginx/conf.d/gitea.conf
sudo cat <<EOF >/etc/nginx/conf.d/gitea.conf
server {
  listen 443 ssl;
  server_name ec2-18-194-15-21.eu-central-1.compute.amazonaws.com;

  ssl_certificate /etc/nginx/ssl/server.crt;
  ssl_certificate_key /etc/nginx/ssl/server.key;
  ssl_client_certificate /etc/nginx/ssl/ca.crt;
  ssl_verify_client on;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF
#Enable and start nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

## Now using ansible we will be copying the configure_nginx.sh to the ec2 instance and execute it to configure niginx for which we should create a playbook in the configuration folder configure_nginx.yml as shown below:

configure_nginx.yml

```bash
---

- hosts: localhost
  remote_user: ec2-user
  vars:
    - ansible_ssh_private_key_file: "~/workspace/terraform/terraform-ansible-aws/infra/terraform_ec2_key"

  tasks:
    - name: Configure nginx server
      delegate_to: "ec2-18-194-15-21.eu-central-1.compute.amazonaws.com"
      become: true
      block:
        - name: Copy script
          copy:
            src: configure_nginx.sh
            dest: /tmp/configure_nginx.sh
            mode: 0755

        - name: Run shell script on remote server
          shell: sh /tmp/configure_nginx.sh
```

## Execute playbook
```bash
ansible-playbook configure_nginx.yml
```

Now we have everything configured. Now we have to verify it by following steps below:

## Verfication

First copy the client certs, keys, ca cert also to your local system in a directory.
Now use the command below to check the ssl connection to the applicatiom

```bash
curl --key client.key  --cert client.crt --cacert ca.crt https://ec2-18-194-15-21.eu-central-1.compute.amazonaws.com -v
```

Below is the screenshot of the same after the above command is executed we can see in the output that the tls handshake is successfull.

<img width="1469" alt="Screenshot 2024-08-15 at 5 19 23 PM" src="https://github.com/user-attachments/assets/bd7fe29d-c32b-4bb3-b80c-625f92a60461">

