#!/bin/sh

set -e

keys="
  GCS_BUCKET
  SSH_PRIVATE_KEY
  SSH_PUBLIC_KEY
  PRIVATE_KEY
  PUBLIC_KEY
"

for k in ${keys}; do
  export ${k}="$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.${k})"
done

STORE_PATH="gs://$GCS_BUCKET/"
HOME=/home/builder
ABUILD=$HOME/.abuild

sudo -u builder ash << EOF
git config --global user.name "Artello Builder"
git config --global user.email "builder@artello.network"

cd $HOME

echo "--- Setup Terraform"

mkdir -p $HOME/.terraform.d/plugins/linux_amd64
go get -v -u github.com/sl1pm4t/terraform-provider-lxd
mv $HOME/go/bin/terraform-provider-lxd ~/.terraform.d/plugins/linux_amd64/terraform-provider-lxd

echo "--- Setup Builder"

mkdir -p $ABUILD
mkdir -p $HOME/.ssh

chsh -s /bin/bash

echo "$SSH_PRIVATE_KEY" > $HOME/.ssh/id_rsa
echo "$SSH_PUBLIC_KEY" > $HOME/.ssh/id_rsa.pub
echo "$PRIVATE_KEY" > $ABUILD/artello-builder.rsa
echo "$PUBLIC_KEY" > $ABUILD/artello-builder.rsa.pub
echo 'PACKAGER_PRIVKEY=$ABUILD/artello-builder.rsa' > $ABUILD/abuild.conf

echo "export PAGER='more'" > $HOME/.profile
echo "export PATH=/var/lib/google-cloud-sdk/bin:$PATH" > $HOME/.profile

source $HOME/.profile

ssh-keyscan gitlab.com > $HOME/.ssh/known_hosts

chmod 600 $HOME/.ssh/id_rsa

cd $HOME/.apk/artello/gitlab-runner-openrc && abuild snapshot && abuild -r

gsutil cp $ABUILD/artello-builder.rsa.pub $STORE_PATH
EOF

echo "$PUBLIC_KEY" > /etc/apk/keys/artello-builder.rsa.pub

apk update
apk add gitlab-runner-openrc
rm -rf $HOME/packages/artello