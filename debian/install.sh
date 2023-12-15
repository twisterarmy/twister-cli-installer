#!/bin/bash
# shellcheck disable=SC1091,SC2164,SC2034,SC1072,SC1073,SC1009

# Twister Command-line Intallation Manager
# Supported OS: Debian, Ubuntu
# https://github.com/twisterarmy/twister-cli-installer
# Based on the openvpn-install codebase (https://github.com/angristan/openvpn-install)

function install() {

  echo "Welcome to the Twister installer!"
  echo "The git repository is available at: https://github.com/twisterarmy/twister-cli-installer"
  echo ""

  echo "I need to ask you a few questions before starting the setup."
  echo "You can leave the default options and just press enter if you are ok with them."
  echo ""
  echo "To compile twister from the source, we need to check and install following dependencies:"
  echo ""
  echo "git"
  echo "autoconf"
  echo "libtool"
  echo "build-essential"
  echo "libboost-all-dev"
  echo "libssl-dev"
  echo "libdb++-dev"
  echo "libminiupnpc-dev"
  echo "automake"
  echo "openssl"
  echo "ufw"

  echo ""

  until [[ $CONTINUE =~ (y|n) ]]; do
    read -rp "Continue? [y/n]: " -e CONTINUE
  done
  if [[ $CONTINUE == "n" ]]; then
    exit 1
  fi

  sudo apt-get update
  sudo apt-get install git autoconf libtool build-essential libboost-all-dev libssl-dev libdb++-dev libminiupnpc-dev automake openssl ufw

  echo ""

  until [[ $EDITION =~ (twisterarmy|miguelfreitas) ]]; do
    read -rp "Chose twister edition [twisterarmy/miguelfreitas]: " -e EDITION
  done

  until [[ $ARM =~ (y|n) ]]; do
    read -rp "Configure for ARM? [y/n]: " -e ARM
  done

  until [[ $SDS =~ (y|n) ]]; do
    read -rp "Create systemd service? [y/n]: " -e SDS
  done

  mkdir $HOME/.twister
  touch $HOME/.twister/twister.conf
  chmod 600 $HOME/.twister/twister.conf
  git clone https://github.com/$EDITION/twister-html.git $HOME/.twister/html

  if [[ $EDITION == "twisterarmy" ]]; then
    cd $HOME/.twister/html
    git checkout twisterarmy
  fi

  git clone https://github.com/$EDITION/twister-core.git $HOME/twister-core
  cd $HOME/twister-core

  if [[ $EDITION == "twisterarmy" ]]; then
    git checkout twisterarmy
  fi

  until [[ $USER_NAME != "" ]]; do
    read -rp "Enter RPC username: " -e USER_NAME
  done

  until [[ $PASSWORD != "" ]]; do
    read -rp "Enter RPC password: " -e PASSWORD
  done

  echo -e "rpcuser=$USER_NAME\nrpcpassword=$PASSWORD" > $HOME/.twister/twister.conf

  until [[ $SSL =~ (y|n) ]]; do
    read -rp "Enable SSL connection? [y/n]: " -e SSL
  done
  if [[ $SSL == "y" ]]; then
    openssl req -x509 -newkey rsa:4096 -keyout $HOME/.twister/key.pem -out $HOME/.twister/cert.pem -days 365 -nodes
    echo -e "rpcallowip=*\nrpcuser=$USER_NAME\nrpcpassword=$PASSWORD\nrpcsslcertificatechainfile=$HOME/.twister/cert.pem\nrpcsslprivatekeyfile=$HOME/.twister/key.pem" > $HOME/.twister/twister.conf
  fi

  echo "Check firewall rules..."
  sudo ufw status

  until [[ $REMOTE =~ (y|n) ]]; do
    read -rp "Is this remote node (28332, 28333, 29333 and 22 ports will be allowed in the iptables rules)? [y/n]: " -e REMOTE
  done
  if [[ $REMOTE == "y" ]]; then
    sudo ufw allow 28332
    sudo ufw allow 28333
    sudo ufw allow 29333
    sudo ufw allow 22
  fi

  until [[ $UFW =~ (y|n) ]]; do

    if [[ $REMOTE == "y" ]]; then
      read -rp "Enable firewall (make sure 22 port was added to the iptable rules)? [y/n]: " -e UFW
    fi

    if [[ $REMOTE == "n" ]]; then
      read -rp "Enable firewall? [y/n]: " -e UFW
    fi

  done
  if [[ $UFW == "y" ]]; then
    sudo ufw enable
    sudo ufw status
  fi

  make clean
  ./autotool.sh

  if [[ $ARM == "y" ]]; then
    ./configure --with-boost-libdir=/usr/lib/arm-linux-gnueabihf --disable-sse2
  else
    ./configure
  fi

  make

  echo "Installation process completed!"

  if [[ $SDS == "y" ]]; then

    echo "Generate systemd service..."

    sudo echo -e "[Unit]" >> /etc/systemd/system/twisterd.service
    sudo echo -e "Description=twister" >> /etc/systemd/system/twisterd.service
    sudo echo -e "After=network.target" >> /etc/systemd/system/twisterd.service
    sudo echo -e "" >> /etc/systemd/system/twisterd.service

    sudo echo -e "[Service]" >> /etc/systemd/system/twisterd.service
    sudo echo -e "Type=simple\nUser=$USER" >> /etc/systemd/system/twisterd.service

    if [[ $SSL == "y" ]]; then
      if [[ $REMOTE == "y" ]]; then
        sudo echo -e "ExecStart=$HOME/twister-core/twister-core/twisterd -rpcssl -port=28333" >> /etc/systemd/system/twisterd.service
      else
        sudo echo -e "ExecStart=$HOME/twister-core/twister-core/twisterd -rpcssl" >> /etc/systemd/system/twisterd.service
      fi
    else
      if [[ $REMOTE == "y" ]]; then
        sudo echo -e "ExecStart=$HOME/twister-core/twister-core/twisterd -port=28333" >> /etc/systemd/system/twisterd.service
      else
        sudo echo -e "ExecStart=$HOME/twister-core/twister-core/twisterd" >> /etc/systemd/system/twisterd.service
      fi
    fi

    sudo echo -e "StandardOutput=file:$HOME/.twisterd/debug.log" >> /etc/systemd/system/twisterd.service
    sudo echo -e "StandardError=file:$HOME/.twisterd/error.log" >> /etc/systemd/system/twisterd.service
    sudo echo -e "Restart=on-failure" >> /etc/systemd/system/twisterd.service
    sudo echo -e "" >> /etc/systemd/system/twisterd.service

    sudo echo -e "[Install]" >> /etc/systemd/system/twisterd.service
    sudo echo -e "WantedBy=multi-user.target" >> /etc/systemd/system/twisterd.service

    sudo systemctl daemon-reload
  fi

  if [[ $SSL == "y" ]]; then
    if [[ $REMOTE == "y" ]]; then
      echo "Run SSL node by using following command: ./twisterd -rpcssl -port=28333"
    else
      echo "Run SSL node by using following command: ./twisterd -rpcssl"
    fi
  else
    echo "Run SSL node by using following command: ./twisterd"
  fi

  if [[ $SDS == "y" ]]; then
    echo "With systemd: service twisterd start"
  fi
}

install
