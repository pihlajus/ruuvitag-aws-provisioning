provider "aws" {
  version = "~> 2.9"
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "home_monitor_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = var.project_name
  }
}

resource "aws_internet_gateway" "home_monitor_gw" {
  vpc_id = aws_vpc.home_monitor_vpc.id

  tags = {
    Name = var.project_name
  }
}

resource "aws_route" "home_monitor_route" {
  route_table_id         = aws_vpc.home_monitor_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.home_monitor_gw.id
}

resource "aws_subnet" "home_monitor_subnet" {
  vpc_id            = aws_vpc.home_monitor_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availibility_zone
  map_public_ip_on_launch = true

  tags = {
    Name = var.project_name
  }
}

resource "aws_security_group" "default" {
  name        = "home_monitor_default_secgroup"
  vpc_id      = aws_vpc.home_monitor_vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nginx
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nginx
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # InfluxDb
  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "home_monitor_access_key" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)
}

# The EC2 instance
resource "aws_instance" "home_monitor_instance" {
  # Ubuntu Server 18.04 LTS (HVM), SSD Volume Type
  ami           = "ami-1dab2163"
  instance_type = var.instance_type
  key_name      = aws_key_pair.home_monitor_access_key.id

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = [aws_security_group.default.id]

  subnet_id = aws_subnet.home_monitor_subnet.id

  tags = {
    Name = var.project_name
  }
}

resource "aws_ebs_volume" "home_monitor_volume" {
  availability_zone = var.availibility_zone
  size              = 30

  tags = {
    Name = var.project_name
  }
}

resource "aws_volume_attachment" "home_monitor_vol_att" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.home_monitor_volume.id
  instance_id  = aws_instance.home_monitor_instance.id
  skip_destroy = true
}

resource "aws_route53_record" "www" {
  zone_id = var.route53_hosted_zone_id
  name    = var.route53_hosted_zone_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.home_monitor_instance.public_ip]
}

resource "null_resource" "ansible-host" {

  depends_on = ["aws_instance.home_monitor_instance"]

  # Put E2 instance's ip to inventory file
  provisioner "local-exec" {
    command =  "sed -ri 's/(\\b[0-9]{1,3}\\.){3}[0-9]{1,3}\\b'/${aws_instance.home_monitor_instance.public_ip}/ hosts"
  }
}

resource "null_resource" "ansible-provision" {

  depends_on = ["null_resource.ansible-host"]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.home_monitor_instance.public_ip
      private_key = file(var.private_key_path)
      user        = "ubuntu"
      timeout = "30"
    }
    script = "scripts/wait_for_instance.sh"
  }

  # Run Ansibble playbook
  provisioner "local-exec" {
    command =  "ansible-playbook provision.yml"
  }
}
