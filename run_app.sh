#python3 /root/openvpn/app.py &
#nohup python3 /root/openvpn/app.py &
sudo bash -c '"$@" </dev/null >/dev/null 2>&1 & disown -h $!' _ \
  python3 /root/openvpn/app.py
