sudo chmod +x /root/openvpn/openvpn-install.sh
sudo chmod +x /root/openvpn/requirement.sh
sudo chmod +x /root/openvpn/status.sh
sudo chmod +x /root/openvpn/run_app.sh
sudo chmod +x /root/openvpn/app.py
sudo /root/openvpn/requirement.sh
cd /root/openvpn && ./openvpn-install.sh
sudo /root/openvpn/run_app.sh
ls
