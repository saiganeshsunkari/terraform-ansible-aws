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