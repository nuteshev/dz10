cd ~
mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd wget  -y

cat > /etc/sysconfig/watchlog << EOF
# Configuration file for my watchdog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF
cat > /opt/watchlog.sh << EOF
#!/bin/bash
WORD=\$1
LOG=\$2
DATE=\`date\`
if grep \$WORD \$LOG &> /dev/null
then
logger "\$DATE: I found word, Master!"
else
exit 0
fi
EOF

{
for i in {1..10}; do 
tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''
done
echo ALERT
} >> /var/log/watchlog.log

cat > /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF

cat > /etc/systemd/system/watchlog.timer <<EOF
[Unit]
Description=Run watchlog script every 30 second
[Timer]
# Run every 30 second
OnUnitActiveSec=30s
OnBootSec=30s
Unit=watchlog.service
[Install]
WantedBy=multi-user.target
EOF

chmod +x /opt/watchlog.sh

systemctl start watchlog.timer
systemctl enable watchlog.timer


cat > /etc/sysconfig/spawn-fcgi << EOF
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s \$SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
EOF

cat > /etc/systemd/system/spawn-fcgi.service << EOF
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target
[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

systemctl start spawn-fcgi
systemctl enable spawn-fcgi

for number in first second; do
cat > /etc/sysconfig/httpd-$number << EOF
OPTIONS=-f conf/$number.conf
EOF
done

sed -i 's/\/etc\/sysconfig\/httpd/\/etc\/sysconfig\/httpd-%I/' /lib/systemd/system/httpd.service
mv /lib/systemd/system/httpd.service /lib/systemd/system/httpd@.service
cd /etc/httpd/conf
mv httpd.conf first.conf
cp first.conf second.conf
sed -i 's/Listen 80/Listen 8080/' second.conf
echo "PidFile /var/run/httpd-second.pid" >> second.conf
systemctl start httpd@first
systemctl start httpd@second
systemctl enable httpd@first
systemctl enable httpd@second
cd
wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-8.13.2-x64.bin
chmod +x atlassian-jira-software-8.13.2-x64.bin
{
echo y; echo o; echo 1; echo 2; echo 8081; echo 8005; echo i; echo n
} | ./atlassian-jira-software-8.13.2-x64.bin
mv /etc/init.d/jira /etc/init.d/jira.backup
cat > /lib/systemd/system/jira.service <<EOF
[Unit] 
Description=Atlassian Jira
After=network.target

[Service] 
Type=forking
User=jira
PIDFile=/opt/atlassian/jira/work/catalina.pid
ExecStart=/opt/atlassian/jira/bin/start-jira.sh
ExecStop=/opt/atlassian/jira/bin/stop-jira.sh

[Install] 
WantedBy=multi-user.target 
EOF

systemctl daemon-reload
systemctl enable jira.service
systemctl start jira.service
