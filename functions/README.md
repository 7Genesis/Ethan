# Projeto Ethan Cloud Functions

## Incluído

1. `sendPasswordResetWhatsAppOtp` (callable)
2. `confirmPasswordResetWhatsAppOtp` (callable)
3. `onProposalCreated` (trigger Firestore)
4. `onProposalStatusUpdated` (trigger Firestore)
5. `onInvoiceReviewUpdated` (trigger Firestore)

## Variáveis de ambiente para WhatsApp (Twilio)

Defina no Secret Manager das Functions:

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_WHATSAPP_FROM
```

No valor de `TWILIO_WHATSAPP_FROM`, use formato `whatsapp:+14155238886`.
Sem os secrets, o envio real de OTP por WhatsApp não ocorre em produção.

## Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```
