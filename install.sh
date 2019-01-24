#!/bin/bash

PROJECT_NAME="guacamole-docker"
export DB_NAME="guacamole"
export DB_PASS="guac_passwd"

# User info
if [ "$1" != "-y" ]; then
  read -p "Name of the guacamole user [guacuser]: " user
fi
user="${user:-guacuser}"
if [ "$1" != "-y" ]; then
  read -p "Name of the shared folder [/home/${user}]: " path
fi
path="${path:-/home/$user}"

# Create user and get id
uid=0
if [ "${user}" != "root" ]; then
  sudo useradd ${user}
  uid=$(id -u ${user})
fi

# Create samba share
sudo apt install -y samba
sudo sh -c 'echo "[shared]
    path = ${path}
    writeable = yes
    guest ok = yes
    guest only = yes
    guest account = ${user}" >> /etc/samba/smb.conf'

# Install Docker CE
if ! command -v docker > /dev/null; then
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo apt install -y docker-ce
fi

# Install Docker Compose
if ! command -v docker-compose > /dev/null; then
  sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

  # - Bash completion (optional)
  sudo curl -L https://raw.githubusercontent.com/docker/compose/1.23.2/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
fi

# Clone repo
sudo apt install -y git
git clone --recurse-submodules -j2 https://github.com/GTE-UVIGO/guacamole-docker
cd guacamole-docker

# Build, setup DB and run
export USER_NAME="${user}" USER_ID="${uid}" FILES_EXT_PATH="${path}"
sudo -E docker-compose build
sudo docker run --rm "${PROJECT_NAME}_guacd" /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
cmd_mysql="mysql -u root -p'${DB_PASS}' ${DB_NAME}"
cmd1="echo \"CREATE DATABASE ${DB_NAME}\" | ${cmd_mysq}"
cmd2="cat /tmp/scripts/initdb.sql | ${cmd_mysql}"
sudo docker run --rm -v ".:/tmp/scripts" "${PROJECT_NAME}_mysql" "${cmd1} && ${cmd2}"
sudo -E docker-compose up -d

# Clean
cd ..
rm -rf guacamole-docker
