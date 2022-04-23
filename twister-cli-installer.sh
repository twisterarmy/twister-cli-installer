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

  mkdir ~/.twister
  touch ~/.twister/twister.conf
  chmod 600 ~/.twister/twister.conf
  git clone https://github.com/$EDITION/twister-html.git ~/.twister/html

  if [[ $EDITION == "twisterarmy" ]]; then
    cd ~/.twister/html
    git checkout twisterarmy
  fi

  git clone https://github.com/$EDITION/twister-core.git ~/twister-core
  cd ~/twister-core

  if [[ $EDITION == "twisterarmy" ]]; then
    git checkout twisterarmy
  fi

  until [[ $USER_NAME != "" ]]; do
    read -rp "Enter RPC username: " -e USER_NAME
  done

  until [[ $PASSWORD != "" ]]; do
    read -rp "Enter RPC password: " -e PASSWORD
  done

  echo -e "rpcuser=$USER_NAME\nrpcpassword=$PASSWORD" > ~/.twister/twister.conf

  until [[ $SSL =~ (y|n) ]]; do
    read -rp "Enable SSL connection? [y/n]: " -e SSL
  done
  if [[ $SSL == "y" ]]; then
    openssl req -x509 -newkey rsa:4096 -keyout ~/.twister/key.pem -out ~/.twister/cert.pem -days 365 -nodes
    echo -e "rpcuser=$USER_NAME\nrpcpassword=$PASSWORD\nrpcsslcertificatechainfile=~/.twister/cert.pem\nrpcsslprivatekeyfile=~/.twister/key.pem" > ~/.twister/twister.conf
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

  if [[ $SSL == "y" ]]; then
    if [[ $REMOTE == "y" ]]; then
      echo "You can run SSL node by using following command: ./twisterd -rpcssl -port=28333"
    else
      echo "You can run SSL node by using following command: ./twisterd -rpcssl"
    fi
  fi
}

install
