s3_bucket="upgrad-prabakar"
myname="prabakar"

#updating the packages
echo "Updating the packages"
sudo apt update -y
sudo apt upgrade -y

#Checking whether apache is installed and installing if not instlled

package_check_apache=`apt -qq list apache2 --installed |wc -l`

  if [ $package_check_apache == 0 ]
  then
        apt-get install apache2 -y
  fi

package_check_awscli=`apt -qq list awscli --installed |wc -l`

  if [ $package_check_awscli == 0 ]
  then
        apt-get install awscli -y
  fi

#Checking whether apache is running or not 
apache_check=`systemctl status apache2.service  | grep Active | awk '{ print $3 }'`

if [ $apache_check == "(dead)" ]
then
        systemctl enable apache2.service
fi

if pgrep -x "apache2" >/dev/null
then
    echo "apache2 is running"
else
    sudo systemctl start apache2
fi

#Creating tarfile and uploading to s3

timestamp="$(date '+%d%m%Y-%H%M%S')"
filename="/tmp/${myname}-httpd-logs-${timestamp}.tar"


echo "Creating Tar file "

tar -cf ${filename} $( find /var/log/apache2/ -name "*.log")


filesize=$(wc -c $filename | awk '{print $1}')

echo "uploading to S3"
aws s3 cp ${filename} s3://${s3_bucket}/${filename}

echo "uploading to S3 done"

inventory_file="/var/www/html/inventory.html"

echo "checking inventory file"

if [[ ! -f $inventory_file ]]; then
    echo "Invetory file not found creating one" 
    sudo touch $inventory_file
    sudo chmod 777 $inventory_file
    sudo echo "Log Type&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Time Created&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Type&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Size<br>" >> $inventory_file
fi

sudo echo "httpd-logs&nbsp;&nbsp;&nbsp;&nbsp;$timestamp&nbsp;&nbsp;&nbsp;&nbsp;tar&nbsp;&nbsp;&nbsp;&nbsp;$filesize Bytes<br>" >> $inventory_file

echo "inventory file updated"

cron_file="/etc/cron.d/automation"
automation_file="/root/Automation_Project/automation.sh"

echo "checking cron job"

cron_job_exists=$(sudo crontab -l | grep 'automation')

echo "cron job found : $cron_job_exists"

if [[ ! $cron_job_exists ]]; then
	if [[ ! -f  $cron_file ]]; then
		echo "cron_file file not found creating one"
		sudo touch $cron_file
		sudo chmod 777 $cron_file
		sudo echo "00 11 * * * $automation_file" >> $cron_file
	fi

	echo "registering cronjob"
	sudo crontab $cron_file
fi

