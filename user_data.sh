#!/bin/bash
yum -y update
yum -y install httpd

myip=`hostname -I | awk '{print $1}'

cat <<EOF > /var/www/html/index.html
<html>
<body bgcolor="white">
<h2><font color="red">WebServer with IP: $myip</h2><br>Terraform"
</body>
</html>
EOF

sudo service httpd start
chkconfig httpd on
