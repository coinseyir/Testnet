#!/bin/bash
echo "
   _____      _        _____            _      
  / ____|    (_)      / ____|          (_)     
 | |     ___  _ _ __ | (___   ___ _   _ _ _ __ 
 | |    / _ \| | '_ \ \___ \ / _ \ | | | | '__|
 | |___| (_) | | | | |____) |  __/ |_| | | |   
  \_____\___/|_|_| |_|_____/ \___|\__, |_|_|   
                                   __/ |       
                                  |___/    
                        
                        https://coinseyir.com/
"

read -p "Enter WALLET name:" WALLET
echo 'export WALLET='$WALLET
read -p "Enter your MONIKER :" MONIKER
echo 'export MONIKER='$MONIKER
read -p "Enter your PORT (for example 17, default port=26):" PORT
echo 'export PORT='$PORT

# set vars
echo "export WALLET="$WALLET"" >> $HOME/.bash_profile
echo "export MONIKER="$MONIKER"" >> $HOME/.bash_profile
echo "export WARDEN_CHAIN_ID="buenavista-1"" >> $HOME/.bash_profile
echo "export WARDEN_PORT="$PORT"" >> $HOME/.bash_profile
source $HOME/.bash_profile

printLine() {
    echo "-----------------------------------------------------"
}

printWhite() {
    echo -e "\e[1m\e[37m$1\e[0m"
}

printLine
echo -e "Moniker:        \e[1m\e[37m$MONIKER\e[0m"
echo -e "Wallet:         \e[1m\e[37m$WALLET\e[0m"
echo -e "Chain id:       \e[1m\e[32m$WARDEN_CHAIN_ID\e[0m"
echo -e "Node custom port:  \e[1m\e[32m$WARDEN_PORT\e[0m"
printLine
sleep 1

printWhite "1. Installing go..." && sleep 1
# install go, if needed
cd $HOME
VER="1.21.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1

sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y
p
printWhite "4. Installing binary..." && sleep 1
# download binary
cd $HOME
rm -rf wardenprotocol
git clone --depth 1 --branch v0.3.0 https://github.com/warden-protocol/wardenprotocol/
cd wardenprotocol
make install

printWhite "5. Configuring and init app..." && sleep 1
# config and init app
wardend init $MONIKER
sed -i -e "s|^node *=.*|node = \"tcp://localhost:${WARDEN_PORT}657\"|" $HOME/.warden/config/client.toml
sleep 1
sleep 1
echo done

printWhite "6. Downloading genesis and addrbook..." && sleep 1
# download genesis and addrbook
wget -O $HOME/.warden/config/genesis.json https://testnet-files.itrocket.net/warden/genesis.json
wget -O $HOME/.warden/config/addrbook.json https://testnet-files.itrocket.net/warden/addrbook.json
sleep 1
echo done

printWhite "7. Adding seeds, peers, configuring custom ports, pruning, minimum gas price..." && sleep 1
# set seeds and peers
SEEDS="8288657cb2ba075f600911685670517d18f54f3b@warden-testnet-seed.itrocket.net:18656"
PEERS="b14f35c07c1b2e58c4a1c1727c89a5933739eeea@warden-testnet-peer.itrocket.net:18656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.warden/config/config.toml

# set custom ports in app.toml
sed -i.bak -e "s%:1317%:${WARDEN_PORT}317%g;
s%:8080%:${WARDEN_PORT}080%g;
s%:9090%:${WARDEN_PORT}090%g;
s%:9091%:${WARDEN_PORT}091%g;
s%:8545%:${WARDEN_PORT}545%g;
s%:8546%:${WARDEN_PORT}546%g;
s%:6065%:${WARDEN_PORT}065%g" $HOME/.warden/config/app.toml

# set custom ports in config.toml file
sed -i.bak -e "s%:26658%:${MANTRA_PORT}658%g;
sed -i.bak -e "s%:26658%:${WARDEN_PORT}658%g;
s%:26657%:${WARDEN_PORT}657%g;
s%:6060%:${WARDEN_PORT}060%g;
s%:26656%:${WARDEN_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${WARDEN_PORT}656\"%;
s%:26660%:${WARDEN_PORT}660%g" $HOME/.warden/config/config.toml

# config pruning
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.warden/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.warden/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.warden/config/app.toml

# set minimum gas price, enable prometheus and disable indexing
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0025uward"|g' $HOME/.warden/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.warden/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.warden/config/config.toml
sleep 1
echo done

# create service file
sudo tee /etc/systemd/system/wardend.service > /dev/null <<EOF
[Unit]
Description=warden node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.warden
ExecStart=$(which wardend) start --home $HOME/.warden
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

printWhite "8. Downloading snapshot and starting node..." && sleep 1
# reset and download snapshot
wardend tendermint unsafe-reset-all --home $HOME/.warden
if curl -s --head curl https://testnet-files.itrocket.net/warden/snap_warden.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://testnet-files.itrocket.net/warden/snap_warden.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.warden
    else
  echo no have snap
fi

# enable and start service
sudo systemctl daemon-reload
sudo systemctl enable wardend
sudo systemctl restart wardend
sleep 8

echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1

if [[ `service wardend status | grep active` =~ "running" ]]; then
  echo -e "Your Warden node \e[32minstalled and works\e[39m!"
  echo -e "Check logs : sudo journalctl -u wardend -f"
else
  echo -e "Your Warden node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
