# Projeto Ethan

Plataforma B2B de compras que leva uma negociação da cotação até a validação da nota fiscal em um único fluxo rastreável. App em Flutter, com Firebase (Auth, Firestore, Storage, Cloud Functions) como backend.

## Problema

Em muitas operações B2B a compra fica espalhada entre WhatsApp, e-mail e planilhas. Isso gera:

- pouca rastreabilidade de quem ofereceu o quê e por que uma proposta foi escolhida;
- cadastros de empresa inconsistentes ou incompletos;
- retrabalho no fechamento da compra, na conferência da nota fiscal;
- risco fiscal quando a NF-e não bate com a proposta ou com os dados do comprador.

O Ethan centraliza cotação, propostas e conferência do XML da NF-e no mesmo lugar.

## O que o app faz

Fluxo implementado no código:

1. O usuário cria conta (e-mail e senha ou Google) e escolhe o papel: comprador (`buyer`) ou fornecedor (`supplier`).
2. O app exige e-mail verificado e perfil completo (empresa e responsável) antes de liberar a área principal. CPF e CNPJ são validados pelos dígitos verificadores, e o WhatsApp é validado e normalizado (`lib/core/validators/br_documents.dart`).
3. O comprador publica uma cotação com produto, quantidade e observações.
4. Fornecedores enviam proposta com preço e prazo de entrega.
5. O comprador escolhe a proposta vencedora. A cotação é fechada, a proposta escolhida vira `accepted` e as demais `rejected`, tudo em um único batch do Firestore.
6. O fornecedor envia o XML da NF-e. O app extrai chave, emitente, destinatário, valor total e data, e gera um relatório de consistência (`pass`, `warning` ou `fail`):
   - falha: chave com menos de 44 caracteres, valor total inválido, CNPJ do destinatário diferente do cadastro do comprador, CNPJ do emitente diferente do cadastro do fornecedor, valor da NF-e mais de 50% distante da proposta;
   - aviso: valor mais de 20% distante da proposta, comprador sem documento fiscal cadastrado.
7. O comprador revisa o XML e marca como verificado ou rejeitado, com observação.
8. Há também: recuperação de senha com código (OTP) por WhatsApp, notificações dentro do app, abertura de chamados de suporte por categoria e um assistente de suporte flutuante.

## Decisões técnicas

- **Firebase como backend.** Auth, Firestore, Storage e Functions cobrem o MVP sem servidor próprio, com atualização em tempo real via `snapshots()`. O custo é acoplamento ao ecossistema Google.
- **Portões de acesso em ordem, na raiz do app** (`lib/main.dart`): autenticado, depois `emailVerified`, depois `profileCompleted`, e só então a home do papel correspondente. Nenhuma tela de negócio é alcançável sem passar por essas etapas.
- **Perfil sempre em `users/{uid}`.** O documento é criado de forma idempotente no primeiro login, o que evita perfis duplicados e regressão de `profileCompleted`.
- **Autorização nas regras do Firestore e do Storage** (`firestore.rules`, `storage.rules`), não só no cliente. As regras levam em conta o papel e o estado da cotação, da proposta e da revisão fiscal.
- **Camada de repositórios** (`lib/repositories`) separa o acesso a dados das telas, e os modelos (`lib/models`) convertem os documentos do Firestore.
- **Fechamento da cotação em batch.** Escolher a proposta atualiza cotação e propostas de forma atômica, sem estado intermediário em que duas propostas aparecem como vencedoras.
- **Conferência do XML no cliente.** O parse (pacote `xml`) e as regras de consistência rodam no app no momento do upload. É simples e dá retorno imediato, mas não substitui consulta à SEFAZ (ver limitações).
- **Cloud Functions para o que não pode confiar no cliente:** OTP por WhatsApp (Twilio, com TTL de 10 min, máximo de 5 tentativas e limite de requisições por janela), criação de chamados com limite por usuário e por IP, notificações e eventos de auditoria disparados por mudanças em propostas, XML e perfil. As callables exigem App Check fora do emulador.
- **App Check** ativado no app (Play Integrity no Android, App Attest no iOS, reCAPTCHA v3 na web).
- **Assistente com Ollama e degradação segura.** O chat chama um Ollama configurável por `OLLAMA_BASE_URL`; se der erro ou timeout (20 s), o app mostra uma mensagem pedindo para abrir um chamado.

## Como rodar

Pré-requisitos:

- Flutter estável com Dart `^3.12.0` (exigido em `pubspec.yaml`). A verificação abaixo foi feita com Flutter 3.44.0 / Dart 3.12.0.
- Um projeto Firebase. O repositório traz `lib/firebase_options.dart` e `firebase.json` apontando para o projeto original do autor; para rodar com o seu, execute `flutterfire configure` e substitua esses arquivos (e `android/app/google-services.json`).
- No console do Firebase: Authentication (e-mail/senha e Google), Firestore e Storage ativos, e as regras publicadas com `firebase deploy --only firestore:rules,storage`.
- Node 20 e Firebase CLI para as Functions.

```bash
flutter pub get
flutter run -d chrome
```

Na web, o App Check precisa da chave reCAPTCHA v3; em modo debug ele é ignorado se a chave faltar:

```bash
flutter run -d chrome --dart-define=FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY=<sua-chave>
```

### Cloud Functions

```bash
cd functions
npm install
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_WHATSAPP_FROM   # formato whatsapp:+14155238886
cd ..
firebase deploy --only functions
```

Sem os secrets do Twilio, o OTP por WhatsApp não é enviado de verdade em produção. Detalhes das funções em `functions/README.md`.

### Assistente de suporte (opcional)

Suba um Ollama com o modelo `llama3.1` (valor fixo em `lib/services/ai_support_service.dart`) e informe o endereço, se não for o padrão `http://localhost:11434`:

```bash
flutter run -d chrome --dart-define=OLLAMA_BASE_URL=http://localhost:11434
```

## Testes

```bash
flutter test
flutter analyze lib test
```

Hoje existe um único teste (`test/widget_test.dart`), um smoke test de renderização. Ele passa, e `flutter analyze lib test` não reporta problemas. Não há testes para repositórios, validadores, regras do Firestore ou Functions.

## Estado do projeto

Experimento em avaliação: o rumo do projeto ainda está em definição, e o projeto Firebase configurado em `android/app/google-services.json` e `lib/firebase_options.dart` é um ambiente de teste. Versão `1.0.0+1`, sem deploy público nem demonstração publicada. Este repositório não inclui capturas de tela.

Limitações conhecidas:

- **Cobertura de testes mínima**, como descrito acima.
- **A validação do XML é só local:** não consulta a SEFAZ nem verifica assinatura digital da NF-e. A chave é checada apenas pelo tamanho.
- **E-mail de perfil concluído não é enviado:** a função `sendProfileCompletedEmail` apenas registra a solicitação (`pending_backend_delivery`) até que um provedor de e-mail seja configurado.
- **O app fala direto com o Ollama**, a partir do cliente, sem serviço intermediário. Para uso real, o modelo e o endpoint deveriam ficar atrás de um backend autenticado.
- **Chamados:** se a Function `createSupportTicket` falhar, o app tenta gravar o chamado direto no Firestore como alternativa.
- Há telas grandes (`login_page.dart` e `complete_profile_page.dart` passam de mil linhas) que pediriam divisão em widgets menores.

## Stack

- Flutter / Dart
- Firebase Auth (e-mail/senha e Google), Cloud Firestore, Firebase Storage, Cloud Functions (Node 20), App Check
- Twilio (OTP por WhatsApp)
- Ollama (assistente de suporte)

## Repositório

Código-fonte: [7Genesis/Ethan](https://github.com/7Genesis/Ethan)
