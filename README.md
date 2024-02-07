<p align="left">
  <a href="https://github.com/vdarkobar/Home-Cloud#self-hosted-cloud">Home</a>
</p>  
  
# BIND9
## DNS software system including an authoritative server, a recursive resolver and related utilities  

  
Clone <a href="https://github.com/vdarkobar/DebianTemplate/blob/main/README.md#debian-template">Template</a>, SSH in using <a href="https://github.com/vdarkobar/Home-Cloud/blob/main/shared/Bastion.md#bastion">Bastion Server</a>  

  
### *Run this command*:
```
clear
sudo apt -y install git && \
RED='\033[0;31m'; NC='\033[0m'; echo -ne "${RED}Enter directory name: ${NC}"; read NAME; mkdir -p "$NAME"; \
cd "$NAME" && git clone https://github.com/vdarkobar/BIND9.git . && \
chmod +x setup.sh && \
rm README.md && \
./setup.sh
```


<br><br>
*(steps used to configure <a href="https://github.com/vdarkobar/How-To/blob/master/BIND9-M%26S.md">BIND9</a>)*
