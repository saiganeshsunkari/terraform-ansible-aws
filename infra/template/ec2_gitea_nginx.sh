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