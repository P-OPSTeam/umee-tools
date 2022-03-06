# Monitoring stack for Umee

## Description
This Monitoring stack is made of :
- grafana for the viewing of the graph
- node_exporter to monitor your host
- prometheus to capture the metrics and make it available for Grafana
- alertmanager 

## Prereq

For this to work, please do a one off install of docker

```bash
# install docker / docker-compose
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-compose docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER #you need to logout and login back after that
```

## Installing the stack

### Clone the repo

```bash
git clone https://github.com/P-OPSTeam/umee-tools
cd umee-tools/grafana
```

### Update start.sh

- update the admin/password of your grafana
- Next, If you wanna be alerted, you will need to create an account on pagerduty and get your integration key https://support.pagerduty.com/docs/services-and-integrations

> alertmanager will fail to start if the PD integration key is not filled up 

### Start the stack

```bash
bash start.sh
```
