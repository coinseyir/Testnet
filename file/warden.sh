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

# install go
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

# download binary
cd $HOME
rm -rf wardenprotocol
git clone --depth 1 --branch v0.3.0 https://github.com/warden-protocol/wardenprotocol/
cd wardenprotocol
make install

# config and init app
wardend init $MONIKER
sed -i -e "s|^node *=.*|node = \"tcp://localhost:${WARDEN_PORT}657\"|" $HOME/.warden/config/client.toml

# download genesis and addrbook
wget -O $HOME/.warden/config/genesis.json https://testnet-files.itrocket.net/warden/genesis.json
wget -O $HOME/.warden/config/addrbook.json https://testnet-files.itrocket.net/warden/addrbook.json

# set seeds and peers
SEEDS="8288657cb2ba075f600911685670517d18f54f3b@warden-testnet-seed.itrocket.net:18656"
PEERS="b14f35c07c1b2e58c4a1c1727c89a5933739eeea@warden-testnet-peer.itrocket.net:18656,7e9adbd0a34fcab219c3a818a022248c575f622b@65.108.227.207:16656,dc0122e37c203dec43306430a1f1879650653479@37.27.97.16:26656,6a4f5b991c321efb12188c126f115d73f4ebf885@95.217.116.103:36656,eee54c85c14748f7793738fadbc747ed1511efac@176.9.58.5:46656,8902e6a170e08225023a7fdd8b875c0349fef703@135.181.129.164:26656,a2cd7cb252c667f0e0cc9ce712e39b245c3f3732@173.212.218.21:11256,19f5b2fb5b7bfb053285a9587fd255efdf7ad4ed@212.90.121.137:26656,7f6c095219b0ae2025b6ede827723477d467f0ee@109.199.123.151:46656,59eaf4ca9491e70fa82d3ecf0b2ed737994f7d12@188.166.101.52:21256,567d9b1351c41236bb061034f843b820a90d4740@89.117.55.113:11256"
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

# create service file
sudo tee /etc/systemd/system/wardend.service > /dev/null <<EOF
[Unit]
Description=Warden node
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
sleep 5

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

echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1

if [[ `service wardend status | grep active` =~ "running" ]]; then
  echo -e "Your Warden node \e[32minstalled and works\e[39m!"
else
  echo -e "Your Warden node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
sleep 7
sudo journalctl -u wardend -f