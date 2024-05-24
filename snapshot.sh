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
printWhite "Installing" && sleep 1
sudo systemctl stop initiad
cp $HOME/.initia/data/priv_validator_state.json $HOME/.initia/priv_validator_state.json.backup
rm -rf $HOME/.initia/data 
curl https://storage.crouton.digital/testnet/initia/snapshots/initia_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.initia
mv $HOME/.initia/priv_validator_state.json.backup $HOME/.initia/data/priv_validator_state.json
sudo systemctl daemon-reload
sudo systemctl enable initiad
printWhite "Installing" && sleep 3
sudo systemctl restart initiad && sudo journalctl -u initiad -f