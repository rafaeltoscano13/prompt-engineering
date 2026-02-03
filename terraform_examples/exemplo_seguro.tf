# ========================================
# EXEMPLO SEGURO - Terraform
# ========================================
# Este exemplo demonstra as boas práticas
# de segurança para AWS com Terraform

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = "ProjetoSK8s"
      Environment  = var.environment
      ManagedBy    = "Terraform"
      CostCenter   = var.cost_center
      CreatedDate  = timestamp()
    }
  }
}

# ========================================
# VARIABLES - Entrada de configuração
# ========================================

variable "aws_region" {
  description = "Região AWS para recursos"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "Region deve ser um valor válido da AWS."
  }
}

variable "environment" {
  description = "Ambiente de deployment"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment deve ser dev, staging ou prod."
  }
}

variable "cost_center" {
  description = "Centro de custo para billing"
  type        = string
}

variable "app_port" {
  description = "Porta da aplicação"
  type        = number
  default     = 8080
  
  validation {
    condition     = var.app_port > 1024 && var.app_port < 65535
    error_message = "Porta deve estar entre 1024 e 65534."
  }
}

# ========================================
# SECURITY GROUP - Acesso restritivo
# ========================================

resource "aws_security_group" "app" {
  name_prefix = "app-sg-"
  description = "Security group para aplicação com acesso restritivo"
  vpc_id      = aws_vpc.main.id

  # Acesso apenas da ALB
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Tráfego da ALB"
  }

  # Egress permitido apenas para recursos necessários
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]
    description     = "HTTPS para RDS"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["8.8.8.8/32", "8.8.4.4/32"]
    description = "DNS resolution"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "app-security-group"
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "alb-sg-"
  description = "Security group para ALB com HTTPS"
  vpc_id      = aws_vpc.main.id

  # Apenas HTTPS de internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
    description = "HTTPS de clientes autorizados"
  }

  # HTTP redirect
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
    description = "HTTP redirect"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = {
    Name = "alb-security-group"
  }
}

# ========================================
# RDS DATABASE - Encriptação habilitada
# ========================================

resource "aws_rds_instance" "main" {
  identifier = "myapp-db-${var.environment}"

  # Engine seguro
  engine               = "postgres"
  engine_version       = "15.3"
  instance_class       = "db.t3.micro"
  allocated_storage    = 100
  max_allocated_storage = 1000  # Auto-scaling

  # Database inicial
  db_name  = "appdb"
  username = "postgres"
  password = random_password.db_master.result

  # Segurança primária
  storage_encrypted           = true
  storage_encryption_kms_key_id = aws_kms_key.rds.arn
  
  # Backup e snapshots
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  copy_tags_to_snapshot  = true
  skip_final_snapshot    = false
  final_snapshot_identifier = "myapp-db-${var.environment}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Monitoring
  performance_insights_enabled    = var.environment == "prod"
  performance_insights_retention_period = 7
  monitoring_interval             = var.environment == "prod" ? 60 : 0
  monitoring_role_arn            = var.environment == "prod" ? aws_iam_role.rds_monitoring.arn : null

  # Outras proteções
  deletion_protection      = var.environment == "prod"
  iam_database_authentication_enabled = true
  enable_http_endpoint     = false

  tags = {
    Name = "myapp-primary-db"
  }

  depends_on = [
    aws_security_group.db,
    aws_db_subnet_group.main
  ]
}

# ========================================
# S3 BUCKET - Encriptação e access logs
# ========================================

resource "aws_s3_bucket" "app_data" {
  bucket_prefix = "myapp-data-"

  tags = {
    Name = "Application Data"
  }
}

# Bloqueia acesso público
resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encriptação por padrão
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# Versionamento para proteção
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = var.environment == "prod" ? "Enabled" : "Disabled"
  }
}

# Logging de acesso
resource "aws_s3_bucket_logging" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "app-data/"
}

# ========================================
# KMS KEYS - Encriptação de dados
# ========================================

resource "aws_kms_key" "rds" {
  description             = "KMS key para RDS ${var.environment}"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = {
    Name = "rds-encryption-key"
  }
}

resource "aws_kms_key" "s3" {
  description             = "KMS key para S3 ${var.environment}"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = {
    Name = "s3-encryption-key"
  }
}

# ========================================
# OUTPUTS - Valores exportados
# ========================================

output "rds_endpoint" {
  description = "Endpoint do RDS"
  value       = aws_rds_instance.main.endpoint
  sensitive   = false
}

output "rds_port" {
  description = "Porta do RDS"
  value       = aws_rds_instance.main.port
}

output "s3_bucket_name" {
  description = "Nome do bucket S3"
  value       = aws_s3_bucket.app_data.id
}

output "security_group_app_id" {
  description = "ID do security group da aplicação"
  value       = aws_security_group.app.id
}
