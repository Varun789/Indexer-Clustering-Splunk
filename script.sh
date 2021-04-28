#!/bin/bash
sudo apt-get update
wget -O splunk-8.1.1-08187535c166-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.1&product=splunk&filename=splunk-8.1.1-08187535c166-Linux-x86_64.tgz&wget=true'
tar -xvzf splunk-8.1.1-08187535c166-Linux-x86_64.tgz
cd /home/ubuntu/splunk/etc/system/local/
echo -e "\n[diskUsage]\nminFreeSpace = 500" >> server.conf
