#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

if dpkg -s pufferpanel &> /dev/null; then
    echo -e "[\e[31m×\e[0m]  PufferPanel is already installed, skipping this step."
else
    echo -e "[\e[32m✓\e[0m]  Installing PufferPanel, please wait..."
    apt-get update
    curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | sudo bash
    sudo apt-get install pufferpanel
    sudo systemctl enable pufferpanel
    sudo systemctl start pufferpanel
    
fi
    echo -e "[\e[32m✓\e[0m]  Adding default user (skip with Ctrl+c)"
    sudo pufferpanel user add
    echo -e "[\e[32m✓\e[0m]  PufferPanel installation complete."

echo -e "[\e[32m✓\e[0m]  Setting up firewall"
if dpkg -s ufw &> /dev/null; then
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw allow 5657
  sudo ufw allow 8080
  sudo ufw enable
else
    sudo apt-get install ufw
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw allow 5657
    sudo ufw allow 8080
    sudo ufw enable
    
fi
echo -e "[\e[32m✓\e[0m]  Firewall setup complete."

echo -e "[\e[32m✓\e[0m]  Configuring Nginx + SSL for PufferPanel"

read -p "Enter the domain name for PufferPanel (e.g., panel.example.com): " domain

# Create or update pufferpanel.conf file
sudo rm -f  /etc/nginx/sites-available/pufferpanel.conf
sudo tee /etc/nginx/sites-available/pufferpanel.conf > /dev/null <<EOF
server {
    listen 80;
    root /var/www/pufferpanel;

    server_name $domain;

    location ~ ^/\.well-known {
        root /var/www/html;
        allow all;
    }

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Nginx-Proxy true;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
    } 
}
EOF

sudo systemctl restart nginx
sudo ln -sf /etc/nginx/sites-available/pufferpanel.conf /etc/nginx/sites-enabled/


apt-get update > /dev/null
apt-get install certbot python3-certbot-nginx -y
certbot --nginx -n -d $domain

echo -e "[\e[32m✓\e[0m]  Nginx + SSL configuration for PufferPanel complete."
