# for main componets of all tiers

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#region EC2
resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro" # Instance type
  # key_name                    = "my-key-pair" # Replace with your key pair name
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  availability_zone           = "${var.main_az}a"
  tags = {
    Name = "api-vm"
  }
user_data = <<-EOF
    #!/bin/bash
    # Update the package manager and install necessary tools
    apt update -y
    apt install -y git curl

    # Install Node.js and npm
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt install -y nodejs

    # Clone the GitHub repository
    git clone https://github.com/yourusername/your-repo.git /home/ubuntu/app

    # Change to the application directory
    cd /home/ubuntu/app

    # Install application dependencies
    npm install

    # Set up the application to run on startup
    cat <<EOF > /etc/systemd/system/nodeapp.service
    [Unit]
    Description=Node.js API Server
    After=network.target

    [Service]
    ExecStart=/usr/bin/node /home/ubuntu/app/index.js
    Restart=always
    User=ubuntu
    Group=ubuntu
    Environment=PATH=/usr/bin:/usr/local/bin
    Environment=NODE_ENV=production
    WorkingDirectory=/home/ubuntu/app

    [Install]
    WantedBy=multi-user.target
    EOF

    # Reload systemd to recognize the new service
    systemctl daemon-reload

    # Start and enable the Node.js application service
    systemctl start nodeapp
    systemctl enable nodeapp

    # Clean up
    rm -rf /home/ubuntu/app/.git
  EOF
}
#endregion
