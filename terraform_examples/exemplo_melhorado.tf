# Exemplo Melhorado - Corrigindo Vulnerabilidades

## De Inseguro para Seguro

Este arquivo demonstra como transformar código inseguro (exemplo_inseguro.tf) em código seguro seguindo as práticas recomendadas.

---

## Problemas Identificados e Soluções

### PROBLEMA 1: Credenciais Hardcoded

**❌ ANTES:**
```terraform
resource "aws_rds_instance" "database" {
  username = "admin"
  password = "MyP@ssw0rd123!"  # CRÍTICO!
}
```

**✅ DEPOIS:**
```terraform
# Usar AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix             = "rds-password-"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.db_master.result
  })
}

resource "aws_rds_instance" "database" {
  identifier     = "mydb"
  engine         = "postgres"
  engine_version = "15.3"
  username       = "postgres"
  password       = random_password.db_master.result  # Gerado aleatoriamente
  
  # Remover arquivo de state com credenciais
  lifecycle {
    ignore_changes = [password]
  }
}
```

---

### PROBLEMA 2: S3 Bucket Público

**❌ ANTES:**
```terraform
resource "aws_s3_bucket" "data" {
  bucket = "my-company-data-bucket"
}

resource "aws_s3_bucket_acl" "data" {
  bucket = aws_s3_bucket.data.id
  acl    = "public-read"  # CRÍTICO!
}
```

**✅ DEPOIS:**
```terraform
resource "aws_s3_bucket" "data" {
  bucket_prefix = "my-company-data-"
}

# Bloquear acesso público completamente
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Usar ACL privada (padrão)
resource "aws_s3_bucket_acl" "data" {
  bucket = aws_s3_bucket.data.id
  acl    = "private"
}

# Adicionar bucket policy para acesso específico
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_distribution.main.s3_origin_access_identity
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}
```

---

### PROBLEMA 3: Security Group Aberto

**❌ ANTES:**
```terraform
resource "aws_security_group" "app" {
  name = "app-sg"
  
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRÍTICO!
  }
}
```

**✅ DEPOIS:**
```terraform
# Security group para ALB (acesso público controlado)
resource "aws_security_group" "alb" {
  name_prefix = "alb-sg-"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "HTTPS from allowed clients"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.app.id]
    description     = "To app tier"
  }
}

# Security group para aplicação (apenas da ALB)
resource "aws_security_group" "app" {
  name_prefix = "app-sg-"
  description = "Security group for application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "From ALB only"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]
    description     = "To database"
  }
}

# Security group para banco de dados (apenas da app)
resource "aws_security_group" "db" {
  name_prefix = "db-sg-"
  description = "Security group for database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "PostgreSQL from app"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
    description = "No outbound allowed"
  }
}
```

---

### PROBLEMA 4: Variáveis sem Validação

**❌ ANTES:**
```terraform
variable "db_password" {
  type    = string
  default = "DefaultPassword123!"
}

variable "instance_count" {
  type    = number
  default = 1
}
```

**✅ DEPOIS:**
```terraform
variable "db_password" {
  description = "Master password for RDS (overridden by Secrets Manager)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_password) >= 20
    error_message = "Password deve ter pelo menos 20 caracteres."
  }
}

variable "instance_count" {
  description = "Número de instâncias EC2 para a aplicação"
  type        = number
  default     = 3
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count deve estar entre 1 e 10."
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

variable "allowed_cidrs" {
  description = "CIDRs permitidas para acesso"
  type        = list(string)
  default     = []
  
  validation {
    condition     = length(var.allowed_cidrs) > 0
    error_message = "Pelo menos um CIDR deve ser especificado."
  }
}
```

---

### PROBLEMA 5: Sem Encriptação

**❌ ANTES:**
```terraform
resource "aws_rds_instance" "database" {
  storage_encrypted = false  # ALTO!
}
```

**✅ DEPOIS:**
```terraform
# KMS key para encriptação
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "rds-encryption-key"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-key-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}

# RDS com encriptação
resource "aws_rds_instance" "database" {
  # ... outras configurações ...
  
  storage_encrypted           = true
  storage_encryption_kms_key_id = aws_kms_key.rds.arn
  
  # Encriptação em trânsito
  publicly_accessible = false
}
```

---

### PROBLEMA 6: Sem Backups

**❌ ANTES:**
```terraform
resource "aws_rds_instance" "database" {
  backup_retention_period = 0  # CRÍTICO!
  skip_final_snapshot     = true
}
```

**✅ DEPOIS:**
```terraform
resource "aws_rds_instance" "database" {
  # Backups automáticos
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true
  
  # Snapshots finais
  skip_final_snapshot       = false
  final_snapshot_identifier = "final-snapshot-${var.environment}-${formatdate("YYYY-MM-DD", timestamp())}"
  
  # Janela de manutenção
  maintenance_window = "mon:04:00-mon:05:00"
  
  # Multi-AZ para produção
  multi_az = var.environment == "prod"
}

# Replicação de cross-region para produção
resource "aws_db_instance_automated_backups_replication" "db" {
  count = var.environment == "prod" ? 1 : 0
  
  source_db_instance_arn = aws_rds_instance.database.arn
  retention_period       = 30
}
```

---

### PROBLEMA 7: Sem Monitoring

**❌ ANTES:**
```terraform
resource "aws_instance" "app" {
  monitoring = false  # ALTO!
}
```

**✅ DEPOIS:**
```terraform
# IAM role para monitoring
resource "aws_iam_role" "ec2_monitoring" {
  name_prefix = "ec2-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_monitoring" {
  role       = aws_iam_role.ec2_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_instance" "app" {
  count                = var.instance_count
  iam_instance_profile = aws_iam_instance_profile.ec2_monitoring.name
  
  # Monitoramento habilitado
  monitoring = true
  
  # CloudWatch agent instalado
  user_data = base64encode(file("${path.module}/install-cloudwatch-agent.sh"))
}

# CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "app-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

---

### PROBLEMA 8: Sem Tags/Governança

**❌ ANTES:**
```terraform
resource "aws_instance" "app" {
  tags = {
    Name = "MyInstance"
  }
}
```

**✅ DEPOIS:**
```terraform
locals {
  common_tags = {
    Project        = "MyApp"
    Environment    = var.environment
    CostCenter     = var.cost_center
    Owner          = "Platform Team"
    CreatedDate    = timestamp()
    ManagedBy      = "Terraform"
    BackupPolicy   = "daily"
    ComplianceScope = "pci-dss"
  }
}

resource "aws_instance" "app" {
  count = var.instance_count
  
  tags = merge(
    local.common_tags,
    {
      Name       = "app-instance-${count.index + 1}"
      Role       = "webserver"
      Version    = var.app_version
    }
  )
}

resource "aws_s3_bucket" "logs" {
  bucket_prefix = "app-logs-"
  
  tags = merge(
    local.common_tags,
    {
      Name     = "Application Logs"
      Retention = "90-days"
    }
  )
}
```

---

### PROBLEMA 9: State Management Inseguro

**❌ ANTES:**
```terraform
# State local - sem backup!
terraform {
  # Nenhuma configuração
}
```

**✅ DEPOIS:**
```terraform
# S3 com versionamento e backup
terraform {
  backend "s3" {
    bucket         = "terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }

  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configurar bucket do state
resource "aws_s3_bucket" "terraform_state" {
  provider      = aws.state
  bucket_prefix = "terraform-state-"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  provider = aws.state
  bucket   = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  provider = aws.state
  bucket   = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  provider       = aws.state
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery_specification {
    enabled = true
  }
}
```

---

## Checklist Final

- ✅ Credenciais em Secrets Manager
- ✅ Encriptação habilitada
- ✅ Acesso restritivo
- ✅ Backups configurados
- ✅ Monitoring ativo
- ✅ Tags para governança
- ✅ State seguro
- ✅ Validação de inputs
- ✅ Documentação clara
- ✅ Auditoria habilitada

## Conclusão

Este arquivo demonstra que é possível transformar código inseguro em código seguro seguindo as boas práticas da AWS e do Terraform. A segurança é um processo contínuo e iterativo.

