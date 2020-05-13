#!/bin/bash
# logging
LOG_FILE=/var/log/startup-script.log
if [ ! -e $LOG_FILE ]
then
     touch $LOG_FILE
     exec &>>$LOG_FILE
else
    #if file exists, exit as only want to run once
    exit
fi

exec 1>$LOG_FILE 2>&1

# variables# repos"
repositories="${repositories}"
user="${user}"
nodeVersion='12.x'
# dependecies
sudo apt-get update -y
sudo apt-get install -y libsecret-1-dev
## install NodeJs
echo "install nodejs"
# set node repo
curl -sL https://deb.nodesource.com/setup_$nodeVersion | sudo bash -
# install node
sudo apt-get install nodejs -y
## install docker
echo "install docker"
set -ex \
&& curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
&& curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
&& echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
&& sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
&& sudo apt-get update -y \
&& sudo apt-get install -y apt-transport-https wget unzip jq git software-properties-common python3-pip ca-certificates gnupg-agent docker-ce docker-ce-cli containerd.io google-cloud-sdk \
&& echo "docker" \
&& sudo usermod -aG docker $user \
&& sudo chown -R $user: /var/run/docker.sock
echo "test tools"
echo '# test tools' >>/home/$user/.bashrc
echo '/bin/bash /testTools.sh' >>/home/$user/.bashrc
cat > /testTools.sh <<EOF 
#!/bin/bash
echo "=====Installed Versions====="
echo "docker:"
docker --version
echo "node:"
node --version
echo "npm:"
npm --version
echo "=====Installed Versions====="
EOF

echo "clone repositories"
cwd=$(pwd)
ifsDefault=$IFS
IFS=','
cd /home/$user
for repo in $repositories
do
    git clone $repo
done
IFS=$ifsDefault
cd $cwd
sudo chown -R $user:$user /home/$user/
echo "=====done====="
exit