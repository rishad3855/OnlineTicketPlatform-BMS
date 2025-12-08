#!/bin/bash
echo "--- Installing Grafana on EC2 ---"

# 1. Install necessary packages
sudo apt install -y software-properties-common apt-transport-https wget

# 2. Add Grafana GPG key
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/grafana.gpg > /dev/null

# 3. Add Grafana repository
echo "deb https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# 4. Update and install Grafana
sudo apt update
sudo apt install grafana -y

# 5. Start and enable the service
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

echo "Grafana is running on http://<EC2-IP>:3000"

# Run this on your Jenkins EC2 instance after the Ansible Playbook executes
kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring \
  -o jsonpath='{.spec.ports[0].nodePort}'; echo
# Output Example: 30909 (This will be a random port in the 30000-32767 range)
kubectl get nodes -o wide | grep -v 'master' | awk '{print $6}' | head -n 1
# Output Example: 10.0.1.15
