# Monitoring node

To have automatic monitoring of your Node & Validator enabled one can follow this guide.

## Script nodemonitor.sh

To monitor the status of the Node & Validator it's possible to run the script **nodemonitor_umee.sh** available in this repository.
This script is based/build on the <https://github.com/stakezone/nodemonitorgaiad> version already available.
When the script is started it will create a file with log entries that monitors the most important stuff of the node.

Since the script creates it's own logfile, it's advised to run it in a separate directory, e.g. **_monitoring_**.

## What is monitored by the script

The script creates a log entry in the following format

```bash
2021-10-06 01:33:56+00:00 status=synced blockheight=1557207 node_stuck=NO tfromnow=7 npeers=12 npersistentpeersoff=1 isvalidator=yes pctprecommits=1.00 pcttotcommits=1.0  mpc_eligibility=OK
```

The log line entries are:

* **status** can be {scriptstarted | error | catchingup | synced} 'error' can have various causes
* **blockheight** blockheight from lcd call
* **node_stuck** YES when last block read is the same as the last iteration, if not then NO
* **tfromnow** time in seconds since blockheight
* **npeers** number of connected peers
* **npersistentpeersoff** number of disconnected persistent peers
* **isvalidator** if validator metrics are enabled, can be {yes | no}
* **pctprecommits** if validator metrics are enabled, percentage of last n precommits from blockheight as configured in nodemonitor.sh
* **pcttotcommits** if validator metrics are enabled, percentage of total commits of the validator set at blockheight
* **UMEED proces** OK if it runs, else NOK
* **PEGGO process** OK if it runs, else NOK
* **ERR in peggo** OK if it runs, else NOK, sends ERR message to discord or telegram if it's setup
* **missed blocks** Will check on missed blocks
* **jailed status** checks if the validator is not jailed

## Telegram Alerting

for telegram alerts, update :

```text
enable_telegram="false"
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"
```

you can create your telegram bot following this : <https://core.telegram.org/bots#6-botfather> and obtain the chat_id <https://stackoverflow.com/a/32572159>

## Discord Alerting

for Discord alerts, update :

# DISCORD
enable_discord="false"
DISCORD_URL="<ENTER YOUR DISCORD WEBHOOK>"

you can create a discord webhook on the channel at settings page --> integrations --> new webhook

## Running the script as a service

To have the script monitor the node constantly and have active alerting available it's possible to run it as a service.
The following example shows how the service file will look like when running in Ubuntu 20.04.

The service assumes:

* you have the script placed in your **_$HOME/umee-tools/monitoring_** directory
* run chmod +x $HOME/umee-tools/monitoring/nodemonitor_umee.sh
* you have added your keyring-password in the script at line 24

Create a file called **umee-nodemonitor.service** in the **/etc/systemd/system** by following the commands:

```bash
cat<<-EOF > /etc/systemd/system/umee-nodemonitor.service
[Unit]
Description=umee NodeMonitor
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$USER
Restart=always
RestartSec=5
ExecStart=$HOME/umee-tools/monitoring-cli/nodemonitor_umee.sh

[Install]
WantedBy=multi-user.target
EOF
```

Now the service file is created it can be started by the following command:

```bash
sudo systemctl start umee-nodemonitor
```

To make sure the service will be active even when a reboot takes place, use:

```bash
sudo systemctl enable umee-nodemonitor
```

Check the status of the service with:

```bash
sudo systemctl status umee-nodemonitor
```

If doing any changes to the files after it was first started do:

```bash
sudo systemctl daemon-reload
```

check the nodemonitor log

```bash
sudo journalctl -fu umee-nodemonitor
```

Update the nodemonitor.sh

```bash
cd umee-tools
git stash
git pull
git stash pop
sudo systemctl stop umee-nodemonitor
sudo systemctl start umee-nodemonitor
```