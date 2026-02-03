# ========================================
# EXEMPLO INSEGURO - Terraform
# ========================================
# Este exemplo demonstra ANTI-PADRÕES
# NÃO USE ESTE CÓDIGO EM PRODUÇÃO!

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ========================================
# ❌ PROBLEMA 1: Credenciais Hardcoded
# ========================================

resource "aws_rds_instance" "database" {
  identifier     = "mydb"
  engine         = "mysql"
  instance_class = "db.t2.micro"
  
  # ❌ CRÍTICO: Password hardcoded em código!
  username = "admin"
  password = "MyP@ssw0rd123!"  # Será visto em git history!
  
  # ❌ ALTO: Sem encriptação
  storage_encrypted = false
  
  # ❌ CRÍTICO: Sem backups finais
  skip_final_snapshot = true
  
  # ❌ ALTO: Sem backups automáticos
  backup_retention_period = 0
  
  # ❌ ALTO: Acessível publicamente
  publicly_accessible = true
  
  # ❌ CRÍTICO: Sem logging
  enabled_cloudwatch_logs_exports = []
}

# ========================================
# ❌ PROBLEMA 2: S3 Bucket com Acesso Público
# ========================================

resource "aws_s3_bucket" "data" {
  bucket = "my-company-data-bucket"
  
  # ❌ CRÍTICO: Sem controle de acesso público
}

# ❌ CRÍTICO: Torna bucket completamente público
resource "aws_s3_bucket_acl" "data" {
  bucket = aws_s3_bucket.data.id
  acl    = "public-read"  # Qualquer um pode ler!
}

# ❌ CRÍTICO: Sem encriptação
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  # FALTA IMPLEMENTAÇÃO - Dados sem encriptação!
}

# ========================================
# ❌ PROBLEMA 3: Security Group Aberto
# ========================================

resource "aws_security_group" "app" {
  name = "app-sg"
  
  # ❌ CRÍTICO: Permite acesso de qualquer lugar
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Internet inteira!
    description = "All traffic"
  }
  
  # ❌ ALTO: Egress sem restrição
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========================================
# ❌ PROBLEMA 4: Secrets em Variáveis
# ========================================

variable "db_password" {
  description = "Password do banco"
  type        = string
  # ❌ CRÍTICO: Default password em código
  default = "DefaultPassword123!"
}

variable "api_key" {
  description = "API Key"
  type        = string
  # ❌ CRÍTICO: Sem sensitive = true
  # Será exibido em logs e outputs!
}

# ========================================
# ❌ PROBLEMA 5: Sem Validação
# ========================================

variable "instance_count" {
  description = "Número de instâncias"
  type        = number
  # ❌ ALTO: Sem validação
  # Usuário pode passar -5 ou 10000!
  default = 1
}

variable "environment" {
  description = "Ambiente"
  type        = string
  # ❌ ALTO: Sem validação
  # Pode ser "prod", "PROD", "production", etc
  default = "production"
}

# ========================================
# ❌ PROBLEMA 6: Sem Tags/Governança
# ========================================

resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.large"
  
  # ❌ ALTO: Sem tags para billing e governança
  # Impossível rastrear custos por projeto
  
  # ❌ ALTO: Sem monitoring
  monitoring = false
  
  # ❌ ALTO: Sem auto-shutdown para dev
  # Pode ficar rodando inadvertidamente e custar muito
  
  tags = {
    Name = "MyInstance"
    # Faltam: Environment, CostCenter, Project, Owner, etc
  }
}

# ========================================
# ❌ PROBLEMA 7: State Management Inseguro
# ========================================

terraform {
  # ❌ CRÍTICO: State local - sem backup/versionamento
  # Perder arquivo = perder controle da infraestrutura
  
  # ❌ CRÍTICO: Sem locking - múltiplos usuários podem aplicar simultaneamente
  # Pode causar race conditions e inconsistência
}

# ========================================
# ❌ PROBLEMA 8: Sem Validação de Provider
# ========================================

# ❌ ALTO: Sem versão de provider especificada
# Mudanças futuras podem quebrar código

# ========================================
# ❌ PROBLEMA 9: Secrets em Outputs
# ========================================

output "db_password" {
  value = aws_rds_instance.database.password
  # ❌ CRÍTICO: Sem sensitive = true
  # Password será exibido em logs e state file em clear text!
}

output "db_connection_string" {
  # ❌ CRÍTICO: URL com credenciais
  value = "mysql://admin:MyP@ssw0rd123!@${aws_rds_instance.database.endpoint}/mydb"
}

# ========================================
# ❌ PROBLEMA 10: Sem Documentação
# ========================================

# ❌ ALTO: Variáveis sem descrição clara
# ❌ ALTO: Sem comentários explicando decisões
# ❌ ALTO: Sem arquivo README.md
# ❌ ALTO: Sem exemplos de uso

# ========================================
# RESUMO DE PROBLEMAS
# ========================================
/*
CRÍTICO (4):
- Credenciais hardcoded
- Password em outputs sem sensitive
- Bucket S3 completamente público
- State sem segurança

ALTO (6):
- Sem encriptação
- Security group aberto
- Sem validação de inputs
- Sem tags/governança
- Sem monitoring
- Sem tags de billing
*/
