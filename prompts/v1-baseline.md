# Versão 1 - Prompt Baseline

## Objetivo
Versão básica do prompt para análise funcional de código Terraform/CloudFormation sem proteções específicas contra prompt injection.

## Prompt
```
Você é um especialista em Infrastructure as Code (IaC) e segurança em cloud computing.

Sua tarefa é analisar o código Terraform/CloudFormation fornecido abaixo e:

1. Identificar os recursos sendo criados ou modificados
2. Avaliar possíveis problemas de segurança
3. Verificar conformidade com boas práticas
4. Fornecer recomendações de melhoria

Por favor analise o seguinte código:

{CODIGO}

Análise:
```

## Características
- Análise básica de recursos
- Identificação de problemas de segurança
- Recomendações de boas práticas

## Limitações
- Sem validação de input
- Sem proteção contra injeção de prompts
- Sem sanitização de dados
