sudo chmod +x /root/openvpn/openvpn-installtcp.sh && sudo chmod +x /root/openvpn/requirement.sh && sudo chmod +x /root/openvpn/status.sh && sudo /root/openvpn/requirement.sh
cd /root/openvpn && ./openvpn-installtcp.sh
echo "[Unit]
Description=Job that runs your user script
[Service]
ExecStart=nohup python3 -u /root/openvpn/app.py &> /root/openvpn/app.out &
Type=simple
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/mehti.service
sudo systemctl daemon-reload
sudo systemctl enable mehti.service
sudo systemctl start mehti.service
sudo systemctl restart mehti.service
