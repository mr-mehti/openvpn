sudo chmod +x /root/openvpn/openvpn-install.sh
sudo chmod +x /root/openvpn/requirement.sh
sudo chmod +x /root/openvpn/status.sh
sudo /root/openvpn/requirement.sh
cd /root/openvpn && ./openvpn-install.sh && nohup python3 -u /root/openvpn/app.py &> /root/openvpn/app.out & && ls
