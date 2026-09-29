resource "aws_security_group" "alb" {
  name        = "tk-test-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "Allow HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tk-test-alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name        = "tk-test-ec2-sg"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.test.id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tk-test-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "tk-test-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.test.id

  ingress {
    description     = "Allow MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = {
    Name = "tk-test-rds-sg"
  }
}