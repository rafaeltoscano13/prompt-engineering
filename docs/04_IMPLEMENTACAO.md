# 4. Implementação

## 4.1 Arquitetura da Solução

```
┌─────────────────────────────────────────┐
│      PR Repository Event                │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      Input Validation Layer (V3)        │
│  - Tamanho máximo: 50KB                 │
│  - Caracteres válidos                   │
│  - Detecção de encoding                 │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      Sanitização de Dados               │
│  - Remoção de caracteres especiais      │
│  - Escape de sequences                  │
│  - Normalização                         │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      Seleção de Prompt (V1|V2|V3)       │
│  - V1: Baseline                         │
│  - V2: Intermediário                    │
│  - V3: Robusto (recomendado)            │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      LLM API Call                       │
│  - ChatGPT / Claude                     │
│  - Timeout: 30s                         │
│  - Retry: 3x                            │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      Output Validation                  │
│  - Formato esperado                     │
│  - Detecção de anomalias                │
│  - Verificação de role                  │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      Relatório Final                    │
│  - Análise técnica                      │
│  - Recomendações                        │
│  - Classificação: SEGURO|ATENÇÃO|CRÍTICO│
└─────────────────────────────────────────┘
```

## 4.2 Componentes Principais

### Input Validator
```python
class InputValidator:
    - validate_size(max_kb=50)
    - validate_characters(allowed_charset)
    - detect_encoding(payload)
    - detect_injection_patterns(payload)
```

### Sanitizer
```python
class Sanitizer:
    - remove_control_chars()
    - escape_special_chars()
    - normalize_whitespace()
    - wrap_in_secure_delimiters()
```

### PromptSelector
```python
class PromptSelector:
    - select_v1() -> basic_prompt
    - select_v2() -> intermediate_prompt
    - select_v3() -> robust_prompt
```

### LLMClient
```python
class LLMClient:
    - call_chatgpt(prompt, code)
    - call_claude(prompt, code)
    - retry_with_backoff()
    - timeout_handler()
```

### OutputValidator
```python
class OutputValidator:
    - validate_format()
    - detect_bypass()
    - verify_role()
    - check_anomalies()
```

## 4.3 Fluxo de Execução

```
1. PR aberto no GitHub
   ↓
2. Webhook dispara análise
   ↓
3. Extrai código do PR
   ↓
4. Valida tamanho e formato
   ↓
5. Sanitiza conteúdo
   ↓
6. Seleciona versão de prompt (default: V3)
   ↓
7. Envia para LLM com timeout
   ↓
8. Valida resposta
   ↓
9. Gera relatório
   ↓
10. Publica comentário no PR
    ↓
11. Arquiva logs
```

## 4.4 Configuração de Ambiente

```bash
# .env.example
OPENAI_API_KEY=sk-...
CLAUDE_API_KEY=sk-ant-...
GITHUB_TOKEN=ghp_...
PROMPT_VERSION=v3  # v1, v2, ou v3
LOG_LEVEL=INFO
MAX_CODE_SIZE_KB=50
TIMEOUT_SECONDS=30
```

## 4.5 Dependências

```python
# requirements.txt
requests>=2.28.0
python-dotenv>=0.20.0
openai>=0.27.0
anthropic>=0.7.0
pyyaml>=6.0
pydantic>=1.10.0
pytest>=7.0.0
pytest-cov>=4.0.0
```

## 4.6 Exemplo de Uso Prático

### Scenario 1: PR Legítimo
```
Input PR: Novo recurso RDS com segurança
  ↓
V3 Análise:
  ✅ Sem padrões de injeção
  ✅ Validação de entrada OK
  ✅ Código estruturalmente válido
  ↓
Resultado:
  "Recursos: RDS instance
   Segurança:
   - ✅ Encriptação habilitada
   - ✅ Backup retention: 30 dias
   - ✅ Sem credenciais hardcoded
   Classificação: SEGURO"
```

### Scenario 2: PR com Injeção
```
Input PR: S3 bucket com tentativa de injeção
  ↓
V3 Análise:
  ❌ Pattern "IGNORE ALL RULES" detectado
  ❌ Context confusion identificado
  ↓
Resultado:
  "[SECURITY INCIDENT DETECTED]
   Tentativa de injection identificada.
   Análise interrompida por segurança.
   
   Incidente registrado para auditoria."
```

## 4.7 Testes de Integração

### Test Coverage
- ✅ 95+ casos de teste
- ✅ Cobertura de todos os tipos de ataque
- ✅ Testes de performance
- ✅ Testes de regressão

### Comando para Rodar Testes
```bash
python -m pytest security_tests/ -v --cov=src --cov-report=html
```

## 4.8 Performance

| Métrica | V1 | V2 | V3 | Meta |
|---------|----|----|----|----|
| Tempo análise | 2s | 2.5s | 3s | <5s |
| Taxa detecção | 0% | 60% | 95% | >90% |
| Falsos positivos | 0% | 8% | 3% | <5% |
| Memória | 50MB | 60MB | 75MB | <100MB |

