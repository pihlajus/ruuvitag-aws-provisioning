# AWS EC2 provisioning for Ruuvitag data
Project creates AWS infra using Terraform and provisions and configurates
EC2 instance with Nginx, Letsencrypt, Influxdb and Grafana using Ansible. This setup
is meant to be used for Ruuvitag data storage and visualization.

![alt text](documents/ruuvi-aws.png "This is how it works")

## Prerequisites

### Data collector
Data from Ruuvitags has to be collected and sent to Influxdb somehow. I use 
Raspberry Pi and Java client from [RuuviCollector](https://github.com/Scrin/RuuviCollector)
project which I run as a systemd service.
```
[Unit]
Description=Ruuvi Collector service
[Service]
User=pi
WorkingDirectory=/home/pi/ruuvi_collector/
ExecStart=/usr/bin/java -jar ruuvi-collector-0.2.jar
SuccessExitStatus=143
TimeoutStopSec=10
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
```
If you are using RuuviCollector you have to modify Influxdb address in
`ruuvi-collector.properties` file. Uncomment line starting with `influxUrl` and
enter you Influxdb address e.g. `https://your.domain:8086`.

### AWS account
You have to have AWS account and IAM user which can be used with Terraform. 

### SSH key pair
Create ssh key pair using `ssh-keygen` so that Ansible can connect to EC2 instance.

## Configuration
There are a few variables that you have to fill before Terraform file can be run:
* Variable in `user.tfvars.example` file (remove .example part after modification)
* Passwords and domain name (if you are using one) in Ansible role folders. Check
`main.yml` files in `vars` folders.

## Running
Use basic  [Terraform commands](https://www.terraform.io/docs/commands/index.html):
* `terraform init` 
* `terraform plan` 
* `terraform apply`

Ansible provisioning is started automatically after AWS infra is created. If you want
to run just Ansible part, use `ansible-playbook provision.yml`. 

## Security
Security in this solution is pretty poor and this setup should not be used
to store any sensitive data. For example database is exposed to internet which
should never be done in any "real" application. Ansible sets up Influxdb with user name
and password but it's not that much... If you have or are planning to 
implement more secure solution for sending Ruuvitag data to Influxdb through
internet please let me know.
