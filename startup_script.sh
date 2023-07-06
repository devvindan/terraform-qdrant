#!/bin/bash
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
export QDRANT__CLUSTER__ENABLED=true
export QDRANT_BOOTSTRAP="http://$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip):6335"

if [[ "$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/qdrant_bootstrap_uri)" != "" ]]; then
    sudo docker run -p 6333:6333 -p 6335:6335 -d qdrant/qdrant ./qdrant --bootstrap ${QDRANT_BOOTSTRAP}
else
    sudo docker run -p 6333:6333 -p 6335:6335 -d qdrant/qdrant ./qdrant --uri ${QDRANT_BOOTSTRAP}
fi
