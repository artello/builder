#!/bin/sh

set -e

keys="
  GCS_BUCKET \
  GCS_CREDENTIALS \
  LXD_REMOTE_URL \
  LXD_REMOTE_NAME \
  LXD_PASSWORD \
  SSH_PRIVATE_KEY \
  SSH_PUBLIC_KEY \
  PRIVATE_KEY \
  PUBLIC_KEY \
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

echo "--- Setup LXD"

lxc remote add $LXD_REMOTE_NAME $LXD_REMOTE_URL --password $LXD_PASSWORD --accept-certificate
lxc remote set-default $LXD_REMOTE_NAME

echo "--- Setup Builder"

mkdir -p $ABUILD
mkdir -p $HOME/.ssh
mkdir -p $HOME/.aws

echo "$SSH_PRIVATE_KEY" > $HOME/.ssh/id_rsa
echo "$SSH_PUBLIC_KEY" > $HOME/.ssh/id_rsa.pub
echo "$AWS_CREDENTIALS" > $HOME/.aws/credentials
echo "$PRIVATE_KEY" > $ABUILD/artello-builder.rsa
echo "$PUBLIC_KEY" > $ABUILD/artello-builder.rsa.pub
echo 'PACKAGER_PRIVKEY=$ABUILD/artello-builder.rsa' > $ABUILD/abuild.conf

ssh-keyscan gitlab.com > $HOME/.ssh/known_hosts

chmod 600 $HOME/.ssh/id_rsa

git clone https://gitlab.com/artello/gitlab-runner ~/gitlab-runner

cd $HOME/gitlab-runner/.apk/artello/gitlab-runner && abuild snapshot && abuild -r

s3cmd put $ABUILD/artello-builder.rsa.pub $STORE_PATH
EOF

echo "$PUBLIC_KEY" > /etc/apk/keys/artello-builder.rsa.pub

apk update
apk add gitlab-runner
rm -rf $HOME/packages/artello