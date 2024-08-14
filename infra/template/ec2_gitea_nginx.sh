#! /bin/bash
sudo cd /home/ec2_user
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
git clone https://github.com/saiganeshsunkari/terraform-ansible-aws.git
sleep 20
sudo cd terraform-ansible-aws/configuration
sudo cp gitea.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start gitea
sudo systemctl enable gitea
#Install nginx
dnf search nginx
sudo dnf install nginx -y
#Generate root ca certs
openssl genpkey -algorithm RSA -out ca.key
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt -subj "/C=US/ST=Example/L=City/O=Company/OU=IT/CN=RootCA"
#Generate certs
openssl genpkey -algorithm RSA -out server.key
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=Example/L=City/O=Company/OU=IT/CN=server.local"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
#Copy certs
sudo mkdir -p /etc/nginx/ssl/
sudo cp server.crt /etc/nginx/ssl/server.crt
sudo cp server.key /etc/nginx/ssl/server.key
sudo cp ca.crt /etc/nginx/ssl/ca.crt
#Copy nginx conf
sudo cp gitea.conf /etc/nginx/conf.d/
#Enable and start nginx
sudo systemctl enable nginx
sudo systemctl start nginx