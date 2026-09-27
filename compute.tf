data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd

    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html>
      <head>
        <title>AWS Terraform Portfolio</title>
      </head>
      <body>
        <h1>AWS Terraform Portfolio</h1>
        <p>Web server is running successfully.</p>
      </body>
    </html>
    HTML
  EOF

  tags = {
    Name = "tk-test-web"
  }
}

