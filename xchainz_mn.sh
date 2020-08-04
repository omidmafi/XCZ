#!/bin/bash
#
# Forked from: https://github.com/axanthics/XCZ-Masternode
# Usage:
# bash xchainz.autoinstall.sh NUM_DUPS
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#TCP port
PORT=14815
RPC=14814

genkey=''
numdups=$1
if [ -z $numdups ]; then
    numdups=9
fi

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -d "/var/lib/fail2ban/" ]; 
then
    echo -e "${GREEN}Packages already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    sudo apt-get -y upgrade
    sudo apt-get -y dist-upgrade
    sudo apt-get -y autoremove
    sudo apt-get -y install wget nano htop jq
    sudo apt-get -y install libzmq3-dev
    sudo apt-get -y install libevent-dev -y
    sudo apt-get install unzip
    sudo apt install unzip
    sudo apt -y install software-properties-common
    sudo add-apt-repository ppa:bitcoin/bitcoin -y
    sudo apt-get -y update
    sudo apt-get -y install libdb4.8-dev libdb4.8++-dev -y
    sudo apt-get -y install libminiupnpc-dev
    sudo apt-get install -y unzip libzmq3-dev build-essential libssl-dev libboost-all-dev libqrencode-dev libminiupnpc-dev libboost-system1.58.0 libboost1.58-all-dev libdb4.8++ libdb4.8 libdb4.8-dev libdb4.8++-dev libevent-pthreads-2.0-5 -y
fi

#Network Settings
echo -e "${GREEN}Installing Network Settings...${NC}"
{
sudo apt-get install ufw -y
} &> /dev/null
echo -ne '[##                 ]  (10%)\r'
{
sudo apt-get update -y
} &> /dev/null
echo -ne '[######             ] (30%)\r'
{
sudo ufw default deny incoming
} &> /dev/null
echo -ne '[#########          ] (50%)\r'
{
sudo ufw default allow outgoing
sudo ufw allow ssh
} &> /dev/null
echo -ne '[###########        ] (60%)\r'
{
sudo ufw allow $PORT/tcp
sudo ufw allow $RPC/tcp
} &> /dev/null
echo -ne '[###############    ] (80%)\r'
{
sudo ufw allow 22/tcp
sudo ufw limit 22/tcp
} &> /dev/null
echo -ne '[#################  ] (90%)\r'
{
echo -e "${YELLOW}"
sudo ufw --force enable
echo -e "${NC}"
} &> /dev/null
echo -ne '[###################] (100%)\n'

#Generating Random Password for  JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Installing Daemon
cd ~
rm -rf /usr/local/bin/xchainz*
wget https://github.com/axanthics/xcz/releases/download/v1.0.0/XChainZd-Ubuntu-16.04.tar.gz
tar -xzvf XChainZd-Ubuntu-16.04.tar.gz
sudo chmod -R 755 xchainz-cli
sudo chmod -R 755 xchainzd
cp -p -r xchainzd /usr/local/bin
cp -p -r xchainz-cli /usr/local/bin
rm XChainZd-Ubuntu-16.04.tar.gz

xchainz-cli stop
sleep 5
#Create datadir
if [ ! -f ~/.xchainz/xchainz.conf ]; then 
    sudo mkdir ~/.xchainz
fi

cd ~
echo -e "${YELLOW}Creating xchainz.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.xchainz/xchainz.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
EOF

    sudo chmod 755 -R ~/.xchainz/xchainz.conf

    #Starting daemon first time just to generate masternode private key
    xchainzd -daemon
    sleep 7
    while true;do
        echo -e "${YELLOW}Generating masternode private key...${NC}"
        genkey=$(xchainz-cli createmasternodekey)
        if [ "$genkey" ]; then
            break
        fi
        sleep 7
    done
fi
    
#Stopping daemon to create xchainz.conf
xchainz-cli stop
sleep 5
cd ~/.xchainz/ && rm -rf blocks chainstate sporks zerocoin
cd ~/.xchainz/ && wget -q https://www.dropbox.com/s/3gk9ttui4cguh5x/bootstrap.zip?dl=1 -O bootstrap.zip
cd ~/.xchainz/ && unzip -o bootstrap.zip
rm ~/.xchainz/bootstrap.zip

# Create xchainz.conf
cat <<EOF > ~/.xchainz/xchainz.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
rpcport=$RPC
port=$PORT
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
masternode=1
externalip=$publicip
bind=127.0.0.1
masternodeaddr=$publicip
masternodeprivkey=$genkey
addnode=45.32.200.81
addnode=155.138.216.95
addnode=207.246.121.229
addnode=144.202.58.202
addnode=144.202.121.189
addnode=104.207.158.86
addnode=144.202.108.44
addnode=199.247.14.127
 
EOF

xchainzd -daemon
#Finally, starting daemon with new xchainz.conf
printf '#!/bin/bash\nif [ ! -f "~/.xchainz/xchainz.pid" ]; then /usr/local/bin/xchainzd -daemon ; fi' > /root/xchainzauto.sh
chmod -R 755 ../xchainzauto.sh
#Setting auto start cron job for xchainz
if ! crontab -l | grep "xchainzauto.sh"; then
    (crontab -l ; echo "*/5 * * * * /root/xchainzauto.sh")| crontab -
fi


curl -sL https://raw.githubusercontent.com/omidmafi/dupmn/master/dupmn_install.sh | sudo -E bash -
cd ~
mkdir mnprofiles
cat <<EOF > ~/mnprofiles/xchainz.dmn
COIN_NAME="xchainz"
COIN_PATH="/usr/local/bin/"
COIN_DAEMON="xchainzd"
COIN_CLI="xchainz-cli"
COIN_FOLDER="/root/.xchainz"
COIN_CONFIG="xchainz.conf"
COIN_SERVICE="xchainz.service"
EOF

dupmn profadd ~/mnprofiles/xchainz.dmn xcz
xchainz-cli stop
sleep 5

for run in {1..$numdups}; do dupmn install xcz -b; done

