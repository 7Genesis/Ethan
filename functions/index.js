const crypto = require("crypto");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const twilio = require("twilio");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const OTP_TTL_SECONDS = 10 * 60;
const OTP_MAX_ATTEMPTS = 5;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const OTP_SEND_LIMIT_PER_WINDOW = 4;
const OTP_CONFIRM_LIMIT_PER_WINDOW = 8;
const SUPPORT_TICKET_LIMIT_PER_WINDOW = 5;
const PROFILE_EMAIL_LIMIT_PER_WINDOW = 5;
const TWILIO_ACCOUNT_SID = defineSecret("TWILIO_ACCOUNT_SID");
const TWILIO_AUTH_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const TWILIO_WHATSAPP_FROM = defineSecret("TWILIO_WHATSAPP_FROM");
const SUPPORT_CATEGORIES = new Set([
  "Cadastro",
  "Login",
  "CNPJ",
  "Cotacao",
  "Proposta",
  "XML fiscal",
  "Outro",
]);

function nowMs() {
  return Date.now();
}

function hashStable(value) {
  return crypto
    .createHash("sha256")
    .update(String(value || ""))
    .digest("hex");
}

function extractClientIp(request) {
  const rawForwarded =
    request?.rawRequest?.headers?.["x-forwarded-for"] ||
    request?.rawRequest?.headers?.["X-Forwarded-For"] ||
    "";
  const forwarded = String(rawForwarded || "").split(",")[0].trim();
  if (forwarded) {
    return forwarded;
  }
  return String(request?.rawRequest?.ip || "unknown");
}

async function enforceRateLimit({
  scope,
  key,
  maxRequests,
  windowMs = RATE_LIMIT_WINDOW_MS,
}) {
  const normalizedScope = String(scope || "").trim();
  const normalizedKey = String(key || "").trim().toLowerCase();

  if (!normalizedScope || !normalizedKey) {
    throw new HttpsError("invalid-argument", "Dados de limite inválidos.");
  }

  const now = nowMs();
  const docId = hashStable(`${normalizedScope}:${normalizedKey}`);
  const ref = db.collection("_rate_limits").doc(docId);

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const data = snap.data() || {};
    const windowStartedAtMs = Number(data.windowStartedAtMs || 0);
    const currentCount = Number(data.requestCount || 0);
    const inWindow = windowStartedAtMs > 0 && now - windowStartedAtMs < windowMs;
    const nextCount = inWindow ? currentCount + 1 : 1;

    if (inWindow && currentCount >= maxRequests) {
      throw new HttpsError(
        "resource-exhausted",
        "Muitas solicitações em pouco tempo. Tente novamente em instantes.",
      );
    }

    transaction.set(
      ref,
      {
        scope: normalizedScope,
        keyHash: hashStable(normalizedKey),
        requestCount: nextCount,
        windowStartedAtMs: inWindow ? windowStartedAtMs : now,
        windowMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

function normalizeEmail(email) {
  return String(email || "")
    .trim()
    .toLowerCase();
}

function digitsOnly(value) {
  return String(value || "").replace(/\D/g, "");
}

function normalizePhone(value) {
  const digits = digitsOnly(value);
  if (digits.length === 13 && digits.startsWith("55")) {
    return digits;
  }
  if (digits.length === 11) {
    return `55${digits}`;
  }
  return null;
}

function maskPhone(phone) {
  if (!phone || phone.length < 6) {
    return "";
  }
  const country = phone.slice(0, 2);
  const ddd = phone.slice(2, 4);
  const suffix = phone.slice(-4);
  return `+${country} (${ddd}) *****-${suffix}`;
}

function hashOtp(code, salt) {
  return crypto
    .createHash("sha256")
    .update(`${salt}:${code}`)
    .digest("hex");
}

function generateOtpCode() {
  const value = Math.floor(100000 + Math.random() * 900000);
  return String(value);
}

function isStrongPassword(password) {
  const value = String(password || "");
  if (value.length < 8) {
    return false;
  }
  if (!/[a-z]/i.test(value) || !/\d/.test(value)) {
    return false;
  }
  return true;
}

async function writeAuditEvent(eventType, payload) {
  try {
    await db.collection("audit_events").add({
      eventType,
      payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error("writeAuditEvent failed", { eventType, error });
  }
}

async function createNotification({ uid, type, title, body, context = {} }) {
  if (!uid) {
    return;
  }

  await db.collection("users").doc(uid).collection("notifications").add({
    type,
    title,
    body,
    context,
    readAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendWhatsAppMessage({ toPhone, message }) {
  const accountSid =
    TWILIO_ACCOUNT_SID.value() || process.env.TWILIO_ACCOUNT_SID || "";
  const authToken =
    TWILIO_AUTH_TOKEN.value() || process.env.TWILIO_AUTH_TOKEN || "";
  const from =
    TWILIO_WHATSAPP_FROM.value() || process.env.TWILIO_WHATSAPP_FROM || "";

  if (!accountSid || !authToken || !from) {
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      logger.info("Twilio env not configured. Emulated send.", { toPhone });
      return;
    }
    throw new HttpsError(
      "failed-precondition",
      "Gateway WhatsApp não configurado.",
    );
  }

  const client = twilio(accountSid, authToken);
  await client.messages.create({
    from,
    to: `whatsapp:+${toPhone}`,
    body: message,
  });
}

exports.sendPasswordResetWhatsAppOtp = onCall(
  {
    enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true",
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_WHATSAPP_FROM],
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const phone = normalizePhone(request.data?.whatsapp);
    const clientIp = extractClientIp(request);

    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "E-mail inválido.");
    }
    if (!phone) {
      throw new HttpsError("invalid-argument", "WhatsApp inválido.");
    }

    await enforceRateLimit({
      scope: "otp_send_ip",
      key: clientIp,
      maxRequests: OTP_SEND_LIMIT_PER_WINDOW,
    });
    await enforceRateLimit({
      scope: "otp_send_email",
      key: email,
      maxRequests: OTP_SEND_LIMIT_PER_WINDOW,
    });

    const user = await auth.getUserByEmail(email).catch(() => null);
    const requestId = crypto.randomUUID();
    const expiresAtMs = nowMs() + OTP_TTL_SECONDS * 1000;
    const destinationMask = maskPhone(phone);

    // Resposta neutra para não vazar existência de conta.
    if (!user) {
      await writeAuditEvent("password_reset_otp_user_not_found", {
        email,
        phone,
        requestId,
      });
      return {
        requestId,
        expiresInSeconds: OTP_TTL_SECONDS,
        destinationMask,
      };
    }

    const code = generateOtpCode();
    const salt = crypto.randomBytes(16).toString("hex");
    const codeHash = hashOtp(code, salt);

    await db.collection("password_reset_otp_challenges").doc(requestId).set({
      requestId,
      uid: user.uid,
      email,
      phone,
      codeHash,
      salt,
      attemptCount: 0,
      usedAt: null,
      createdAtMs: nowMs(),
      expiresAtMs,
    });

    const text =
      "Projeto Ethan: código para redefinir sua senha: " +
      `${code}. Validade: 10 minutos. Se não solicitou, ignore.`;
    await sendWhatsAppMessage({ toPhone: phone, message: text });

    await writeAuditEvent("password_reset_otp_sent", {
      uid: user.uid,
      email,
      phoneMask: destinationMask,
      requestId,
    });

    const response = {
      requestId,
      expiresInSeconds: OTP_TTL_SECONDS,
      destinationMask,
    };

    if (process.env.FUNCTIONS_EMULATOR === "true") {
      response.devOtpCode = code;
    }

    return response;
  },
);

exports.confirmPasswordResetWhatsAppOtp = onCall(
  { enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" },
  async (request) => {
  const email = normalizeEmail(request.data?.email);
  const phone = normalizePhone(request.data?.whatsapp);
  const requestId = String(request.data?.requestId || "").trim();
  const otpCode = String(request.data?.otpCode || "").trim();
  const newPassword = String(request.data?.newPassword || "");
  const clientIp = extractClientIp(request);

  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "E-mail inválido.");
  }
  if (!phone) {
    throw new HttpsError("invalid-argument", "WhatsApp inválido.");
  }
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId obrigatório.");
  }
  if (otpCode.length < 4) {
    throw new HttpsError("invalid-argument", "Código OTP inválido.");
  }
  if (!isStrongPassword(newPassword)) {
    throw new HttpsError(
      "invalid-argument",
      "Senha fraca. Use ao menos 8 caracteres com letras e números.",
    );
  }

  await enforceRateLimit({
    scope: "otp_confirm_ip",
    key: clientIp,
    maxRequests: OTP_CONFIRM_LIMIT_PER_WINDOW,
  });
  await enforceRateLimit({
    scope: "otp_confirm_request",
    key: requestId,
    maxRequests: OTP_CONFIRM_LIMIT_PER_WINDOW,
  });

  const ref = db.collection("password_reset_otp_challenges").doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Desafio OTP não encontrado.");
  }

  const data = snap.data() || {};
  if (data.usedAt) {
    throw new HttpsError("failed-precondition", "OTP já utilizado.");
  }
  if (nowMs() > Number(data.expiresAtMs || 0)) {
    throw new HttpsError("deadline-exceeded", "OTP expirado.");
  }
  if (data.email !== email || data.phone !== phone) {
    throw new HttpsError("permission-denied", "Dados do desafio divergentes.");
  }

  const currentAttempts = Number(data.attemptCount || 0);
  if (currentAttempts >= OTP_MAX_ATTEMPTS) {
    throw new HttpsError(
      "resource-exhausted",
      "Muitas tentativas inválidas. Solicite um novo OTP.",
    );
  }

  const expectedHash = hashOtp(otpCode, String(data.salt || ""));
  if (expectedHash !== data.codeHash) {
    await ref.set(
      { attemptCount: currentAttempts + 1 },
      { merge: true },
    );
    throw new HttpsError("permission-denied", "Código OTP inválido.");
  }

  const uid = String(data.uid || "");
  if (!uid) {
    throw new HttpsError("not-found", "Usuário não encontrado para reset.");
  }

  await auth.updateUser(uid, { password: newPassword });
  await ref.set(
    {
      usedAt: nowMs(),
      updatedAt: nowMs(),
    },
    { merge: true },
  );

  await createNotification({
    uid,
    type: "password_reset",
    title: "Senha redefinida",
    body: "Sua senha foi alterada por OTP via WhatsApp.",
    context: {
      channel: "whatsapp_otp",
    },
  });
  await writeAuditEvent("password_reset_otp_confirmed", {
    uid,
    email,
    requestId,
  });

  return { success: true };
  },
);

exports.sendProfileCompletedEmail = onCall(
  { enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Autenticação obrigatória.");
    }

    const uid = request.auth.uid;
    const emailFromAuth = normalizeEmail(request.auth.token?.email);
    const emailFromPayload = normalizeEmail(request.data?.email);
    const email = emailFromPayload || emailFromAuth;

    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "E-mail inválido.");
    }

    await enforceRateLimit({
      scope: "profile_email_uid",
      key: uid,
      maxRequests: PROFILE_EMAIL_LIMIT_PER_WINDOW,
    });

    await writeAuditEvent("profile_completed_email_requested", {
      uid,
      email,
      channel: "callable",
      status: "pending_backend_delivery",
    });

    return {
      accepted: true,
      delivery: "pending_backend_delivery",
      message:
        "Solicitação registrada. Configure um provedor de e-mail no backend para envio em produção.",
    };
  },
);

exports.createSupportTicket = onCall(
  { enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Autenticação obrigatória.");
    }

    const uid = request.auth.uid;
    const clientIp = extractClientIp(request);
    const categoryRaw = String(request.data?.category || "").trim();
    const message = String(request.data?.message || "").trim();

    if (!message) {
      throw new HttpsError(
        "invalid-argument",
        "Descreva o problema para abrir o chamado.",
      );
    }

    await enforceRateLimit({
      scope: "support_ticket_uid",
      key: uid,
      maxRequests: SUPPORT_TICKET_LIMIT_PER_WINDOW,
    });
    await enforceRateLimit({
      scope: "support_ticket_ip",
      key: clientIp,
      maxRequests: SUPPORT_TICKET_LIMIT_PER_WINDOW,
    });

    const category = SUPPORT_CATEGORIES.has(categoryRaw) ? categoryRaw : "Outro";
    const userEmail = normalizeEmail(request.auth.token?.email);
    const userProfile = await db.collection("users").doc(uid).get();
    const companyName = String(userProfile.data()?.companyName || "");
    const ticketRef = db.collection("support_tickets").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await ticketRef.set({
      userId: uid,
      userEmail,
      companyName,
      category,
      message,
      status: "open",
      createdAt: now,
      updatedAt: now,
    });

    await createNotification({
      uid,
      type: "support_ticket_opened",
      title: "Chamado aberto",
      body: `Seu chamado (${ticketRef.id}) foi registrado.`,
      context: {
        ticketId: ticketRef.id,
        category,
      },
    });

    await writeAuditEvent("support_ticket_created", {
      uid,
      ticketId: ticketRef.id,
      category,
    });

    return {
      ticketId: ticketRef.id,
      status: "open",
    };
  },
);

exports.onProposalCreated = onDocumentCreated(
  "proposals/{proposalId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const quotationId = String(data.quotationId || "");
    const supplierId = String(data.supplierId || "");
    const supplierName = String(data.supplier || "Fornecedor");
    const price = Number(data.price || 0);

    if (!quotationId) return;
    const quotationSnap = await db.collection("quotations").doc(quotationId).get();
    const quotation = quotationSnap.data() || {};
    const buyerId = String(quotation.buyerId || "");

    await createNotification({
      uid: buyerId,
      type: "proposal_received",
      title: "Nova proposta recebida",
      body: `${supplierName} enviou proposta de R$ ${price.toFixed(2)}.`,
      context: { quotationId, proposalId: event.params.proposalId },
    });
    await createNotification({
      uid: supplierId,
      type: "proposal_sent",
      title: "Proposta enviada",
      body: "Sua proposta foi registrada com sucesso.",
      context: { quotationId, proposalId: event.params.proposalId },
    });
    await writeAuditEvent("proposal_created", {
      quotationId,
      proposalId: event.params.proposalId,
      supplierId,
      buyerId,
      price,
    });
  },
);

exports.onProposalStatusUpdated = onDocumentUpdated(
  "proposals/{proposalId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const previous = String(before.status || "");
    const current = String(after.status || "");

    if (!previous || previous === current) return;

    const quotationId = String(after.quotationId || "");
    const supplierId = String(after.supplierId || "");
    const supplierName = String(after.supplier || "Fornecedor");

    if (!quotationId) return;
    const quotationSnap = await db.collection("quotations").doc(quotationId).get();
    const quotation = quotationSnap.data() || {};
    const buyerId = String(quotation.buyerId || "");

    if (current === "accepted" || current === "rejected") {
      await createNotification({
        uid: supplierId,
        type: `proposal_${current}`,
        title: current === "accepted" ? "Proposta aceita" : "Proposta rejeitada",
        body:
          current === "accepted"
            ? "Sua proposta foi escolhida. Envie o XML da nota fiscal."
            : "O comprador rejeitou esta proposta.",
        context: { quotationId, proposalId: event.params.proposalId },
      });

      await createNotification({
        uid: buyerId,
        type: `proposal_${current}_by_buyer`,
        title:
          current === "accepted"
            ? "Proposta aprovada"
            : "Proposta marcada como rejeitada",
        body: `${supplierName} (${event.params.proposalId}) recebeu status ${current}.`,
        context: { quotationId, proposalId: event.params.proposalId },
      });
    }

    await writeAuditEvent("proposal_status_changed", {
      quotationId,
      proposalId: event.params.proposalId,
      from: previous,
      to: current,
      supplierId,
      buyerId,
    });
  },
);

exports.onInvoiceReviewUpdated = onDocumentUpdated(
  "quotations/{quotationId}/invoiceXmls/{proposalId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const previous = String(before.reviewStatus || "");
    const current = String(after.reviewStatus || "");
    if (!previous || previous === current) return;

    const quotationId = event.params.quotationId;
    const proposalId = event.params.proposalId;
    const supplierId = String(after.supplierId || "");

    const quotationSnap = await db.collection("quotations").doc(quotationId).get();
    const quotation = quotationSnap.data() || {};
    const buyerId = String(quotation.buyerId || "");

    if (current === "verified" || current === "rejected") {
      await createNotification({
        uid: supplierId,
        type: `invoice_${current}`,
        title: current === "verified" ? "XML validado" : "XML rejeitado",
        body:
          current === "verified"
            ? "O comprador validou seu XML."
            : "O comprador marcou divergência no XML.",
        context: { quotationId, proposalId },
      });
      await createNotification({
        uid: buyerId,
        type: `invoice_${current}_by_buyer`,
        title:
          current === "verified"
            ? "Compra concluída"
            : "XML com divergência",
        body:
          current === "verified"
            ? "A validação do XML foi concluída."
            : "Fornecedor precisará reenviar XML.",
        context: { quotationId, proposalId },
      });
    }

    await writeAuditEvent("invoice_review_status_changed", {
      quotationId,
      proposalId,
      from: previous,
      to: current,
      supplierId,
      buyerId,
    });
  },
);

exports.onUserProfileActivated = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeCompleted = before.profileCompleted === true;
    const afterCompleted = after.profileCompleted === true;
    const beforeStage = String(before.registrationStage || "");
    const afterStage = String(after.registrationStage || "");

    if ((!beforeCompleted && afterCompleted) || beforeStage !== afterStage) {
      await createNotification({
        uid: event.params.userId,
        type: "profile_updated",
        title: "Cadastro atualizado",
        body:
          afterStage === "active"
            ? "Seu cadastro está completo e ativo."
            : "Seu cadastro foi atualizado.",
        context: {
          registrationStage: afterStage,
          profileCompleted: afterCompleted,
        },
      });
    }

    await writeAuditEvent("user_profile_updated", {
      uid: event.params.userId,
      beforeCompleted,
      afterCompleted,
      beforeStage,
      afterStage,
      identityVerificationStatus: String(after.identityVerificationStatus || ""),
    });
  },
);
