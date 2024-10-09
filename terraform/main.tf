data "aws_availability_zones" "available" {}

locals {
  db_endpoint_without_port = replace(aws_db_instance.postgres.endpoint, ":5432", "")
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
  name        = "ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public[0].id

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx golang git postgresql-client

              add-apt-repository ppa:longsleep/golang-backports -y
              apt-get update
              apt-get install -y golang-go

              echo 'export GOROOT=/usr/lib/go' >> /etc/profile
              echo 'export PATH=$PATH:$GOROOT/bin' >> /etc/profile
              source /etc/profile

              git clone https://github.com/justmiroslav/golang-demo.git /home/ubuntu/golang-demo
              chown -R ubuntu:ubuntu /home/ubuntu/golang-demo

              cd /home/ubuntu/golang-demo
              sudo -u ubuntu bash -c 'GOOS=linux GOARCH=amd64 go build -o golang-demo'
              chmod +x golang-demo

              cat <<EOT > /etc/systemd/system/golang-demo.service
              [Unit]
              Description=Golang Demo App
              After=network.target

              [Service]
              Environment="DB_ENDPOINT=${local.db_endpoint_without_port}"
              Environment="DB_PORT=5432"
              Environment="DB_USER=${var.db_username}"
              Environment="DB_PASS=${var.db_password}"
              Environment="DB_NAME=${var.db_name}"
              ExecStart=/home/ubuntu/golang-demo/golang-demo
              WorkingDirectory=/home/ubuntu/golang-demo
              User=ubuntu
              Restart=always

              [Install]
              WantedBy=multi-user.target
              EOT
              
              PGPASSWORD="${var.db_password}" psql -h ${local.db_endpoint_without_port} -U ${var.db_username} -d ${var.db_name} -f /home/ubuntu/golang-demo/db_schema.sql

              systemctl enable golang-demo
              systemctl start golang-demo

              cat <<EOT > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;

                  location / {
                      proxy_pass http://localhost:8080;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                  }
              }
              EOT

              systemctl restart nginx
              EOF

  tags = {
    Name = "app-instance"
  }

  monitoring = false
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres13"
  name   = "custom-postgres13"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_db_subnet_group" "postgres" {
  name       = "postgres-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "Postgres subnet group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "mydb"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13"
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  parameter_group_name   = aws_db_parameter_group.postgres.name
  publicly_accessible    = true
  skip_final_snapshot    = true
  multi_az               = false
  monitoring_interval    = 0

  tags = {
    Name = "mydb-instance"
  }
}