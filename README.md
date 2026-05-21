# Cotahub

Plataforma B2B para negociação de compras com fluxo completo:

- autenticacao e cadastro validado;
- criacao de cotacoes;
- envio de propostas por fornecedores;
- selecao de proposta;
- envio e revisao de XML fiscal no mesmo fluxo;
- suporte interno com chamados;
- assistente de IA para operacao.

## Problema que o projeto resolve

Em operacoes B2B, cotacao e fechamento fiscal costumam ficar espalhados entre
WhatsApp, e-mail, planilhas e sistemas diferentes. Isso gera:

- baixa rastreabilidade da decisao;
- retrabalho no cadastro;
- risco de identidade incompleta/falsa;
- falhas no fechamento fiscal.

O Cotahub reduz essa fragmentacao centralizando negociacao + compliance fiscal
em um unico produto.

## Intuito do produto

1. Reduzir risco operacional na compra B2B.
2. Aumentar confianca entre comprador e fornecedor.
3. Fechar o ciclo de compra sem depender de canais paralelos.
4. Estruturar governanca: identidade, propostas, decisao e XML auditaveis.

## Como o Cotahub funciona

1. Usuario cria conta e escolhe papel (comprador/fornecedor).
2. Conta passa por verificacao de e-mail.
3. Usuario conclui cadastro empresarial e do responsavel.
4. Comprador abre cotacao com itens e observacoes.
5. Fornecedores enviam proposta de preco/prazo.
6. Comprador seleciona proposta vencedora.
7. Fornecedor envia XML da nota fiscal.
8. Comprador revisa consistencia e conclui compra.

## Como isso esta sendo resolvido tecnicamente

### Identidade e sessao

- Firebase Auth para autenticacao e persistencia de sessao.
- Gate de acesso por camadas:
  - usuario autenticado;
  - e-mail verificado;
  - perfil completo (`profileCompleted == true`).

### Perfil e consistencia de dados

- Perfil salvo em `users/{uid}` (nunca `add()` para usuario).
- Criacao idempotente de perfil base.
- Atualizacao canonica para evitar regressao de `profileCompleted`.
- Reprocessamento de cadastro legado quando necessario.

### Fluxo de negocio

- Colecoes principais:
  - `users`
  - `quotations`
  - `proposals`
  - `support_tickets`
  - `quotations/{quotationId}/invoiceXmls/{proposalId}`
- Firestore Rules para controle por papel (buyer/supplier) e por estado do fluxo.

### Suporte e IA

- Chamados internos com categoria e status.
- Chat de assistente flutuante nas telas principais.
- Integracao preparada para Ollama via endpoint configuravel (`OLLAMA_BASE_URL`),
  com fallback seguro quando indisponivel.

## Resultado esperado

- Menos cadastros incompletos e menos fraude de identidade.
- Menos retrabalho no fechamento de compras.
- Rastreabilidade completa da decisao de compra.
- Validacao fiscal integrada ao processo comercial.

## Stack

- Flutter
- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Ollama (via servico intermediario de suporte IA)

## Rodando localmente

```bash
flutter clean
flutter pub get
flutter analyze lib
flutter run -d chrome
```

## Repositorio

Origem oficial: [7Genesis/Cotahub](https://github.com/7Genesis/Cotahub)
