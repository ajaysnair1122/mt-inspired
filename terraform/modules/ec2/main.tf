# -------------------
# SECURITY GROUPS
# -------------------

# Bastion SG
resource "aws_security_group" "bastion_sg" {
  name   = "${var.environment}-bastion-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# App SG
resource "aws_security_group" "app_sg" {
  name   = "${var.environment}-app-sg"
  vpc_id = var.vpc_id

  # SSH only from bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # App port from monitoring
  ingress {
    description     = "App metrics"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }

  # Node exporter
  ingress {
    description     = "Node exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Monitoring SG
resource "aws_security_group" "monitoring_sg" {
  name   = "${var.environment}-monitoring-sg"
  vpc_id = var.vpc_id

  # Access from your laptop via bastion tunnel later
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # SSH from bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------
# AMI
# -------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# -------------------
# EC2 INSTANCES
# -------------------

# Bastion
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = var.public_subnets[0]
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "${var.environment}-bastion"
  }
}

# Stage App
resource "aws_instance" "app" {
  count = 2

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnets[count.index]
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
    user_data = <<-EOF
#!/bin/bash
apt update -y
apt install -y docker.io git

systemctl enable docker
systemctl start docker

cd /home/ubuntu

# Clone repo
git clone https://github.com/ajaysnair1122/mt-inspired.git

cd mt-inspired/app

# Build image
docker build -t metrics-app .

# Run container
docker run -d -p 3000:3000 metrics-app
EOF
  tags = {
    Name = "${var.environment}-app-${count.index}"
  }
}

# Monitoring
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnets[0]
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  user_data = <<-EOF
#!/bin/bash
apt update -y
apt install -y docker.io

systemctl enable docker
systemctl start docker

# Create Prometheus config
cat <<EOT > /home/ubuntu/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['10.10.3.233:3000','10.10.4.126:3000']
EOT

# Run Prometheus
docker run -d -p 9090:9090 \
  -v /home/ubuntu/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Run Grafana
docker run -d -p 3000:3000 grafana/grafana
EOF

  tags = {
    Name = "${var.environment}-monitoring"
  }
}
