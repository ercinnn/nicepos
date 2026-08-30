// iyzico Checkout Form (CF) entegrasyonu — bu oturumda docs.iyzico.com'dan
// doğrulanan alan adları/uç noktalar (Ağustos 2026). Sandbox ortamı üye
// işyeri onayı BEKLEMEDEN kullanılabilir — Aşama A bu dosyayı sandbox'a
// karşı test eder, Aşama C'de yalnız IYZICO_BASE_URL + key'ler production'a
// çevrilir, kod DEĞİŞMEZ.

const SANDBOX_BASE_URL = "https://sandbox-api.iyzipay.com";
// Aşama C'de production'a geçiş: `supabase secrets set
// IYZICO_BASE_URL=https://api.iyzipay.com` — kod DEĞİŞMEZ.

function getBaseUrl(): string {
  return Deno.env.get("IYZICO_BASE_URL") ?? SANDBOX_BASE_URL;
}

export interface CheckoutFormInitializeRequest {
  conversationId: string;
  price: string; // ondalık, nokta ayraçlı (iyzico string bekliyor)
  paidPrice: string;
  currency: "TRY" | "USD" | "EUR";
  basketId: string;
  callbackUrl: string;
  buyer: {
    id: string;
    name: string;
    surname: string;
    identityNumber: string; // gerçek TC/vergi no yoksa iyzico'nun test/placeholder deseni kullanılır (implementasyonda teyit)
    email: string;
    gsmNumber: string;
    registrationAddress: string;
    city: string;
    country: string;
    ip: string;
  };
  billingAddress: {
    address: string;
    contactName: string;
    city: string;
    country: string;
  };
  basketItems: {
    id: string;
    price: string;
    name: string;
    category1: string;
    itemType: "VIRTUAL";
  }[];
}

export interface CheckoutFormInitializeResponse {
  status: "success" | "failure";
  token?: string;
  checkoutFormContent?: string;
  paymentPageUrl?: string;
  errorMessage?: string;
}

export interface CheckoutFormRetrieveResponse {
  status: "success" | "failure";
  paymentStatus?: string; // "SUCCESS" bekleniyor, implementasyonda teyit
  paymentId?: string;
  price?: string;
  paidPrice?: string;
  fraudStatus?: number; // 1: onaylı, 0: incelemede, -1: reddedildi
  errorMessage?: string;
}

async function hmacSha256Hex(key: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// IYZWSv2 imza şeması (docs.iyzico.com/en/getting-started/preliminaries/
// authentication/hmacsha256-auth, bu oturumda doğrulandı):
//   randomKey + uriPath + requestBody  →  HMACSHA256(secretKey)  →  hex
//   authorizationString = "apiKey:"+apiKey+"&randomKey:"+randomKey+"&signature:"+hex
//   header = "IYZWSv2 " + base64(authorizationString)
async function buildAuthHeaders(
  uriPath: string,
  body: string,
): Promise<{ Authorization: string; "x-iyzi-rnd": string }> {
  const apiKey = Deno.env.get("IYZICO_API_KEY");
  const secretKey = Deno.env.get("IYZICO_SECRET_KEY");
  if (!apiKey || !secretKey) {
    throw new Error("IYZICO_API_KEY / IYZICO_SECRET_KEY secret olarak ayarlanmamış.");
  }

  const randomKey = `${Date.now()}${crypto.randomUUID().replace(/-/g, "").slice(0, 16)}`;
  const signature = await hmacSha256Hex(secretKey, randomKey + uriPath + body);
  const authorizationString =
    `apiKey:${apiKey}&randomKey:${randomKey}&signature:${signature}`;
  const encoded = btoa(unescape(encodeURIComponent(authorizationString)));

  return { Authorization: `IYZWSv2 ${encoded}`, "x-iyzi-rnd": randomKey };
}

export async function initializeCheckoutForm(
  request: CheckoutFormInitializeRequest,
): Promise<CheckoutFormInitializeResponse> {
  const uriPath = "/payment/iyzipos/checkoutform/initialize/auth/ecom";
  const body = JSON.stringify(request);
  const authHeaders = await buildAuthHeaders(uriPath, body);

  const res = await fetch(`${getBaseUrl()}${uriPath}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...authHeaders },
    body,
  });
  return await res.json();
}

export async function retrieveCheckoutForm(
  token: string,
  conversationId: string,
): Promise<CheckoutFormRetrieveResponse> {
  const uriPath = "/payment/iyzipos/checkoutform/auth/ecom/detail";
  const body = JSON.stringify({ token, conversationId, locale: "tr" });
  const authHeaders = await buildAuthHeaders(uriPath, body);

  const res = await fetch(`${getBaseUrl()}${uriPath}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...authHeaders },
    body,
  });
  return await res.json();
}

// ⚠️ X-IYZ-SIGNATURE-V3 imza doğrulaması hesapta AYRICA açılması gereken
// bir özellik (destek@iyzico.com ile), bu turda araştırılan formül:
//   HMACSHA256(secretKey, secretKey+iyziEventType+paymentId+paymentConversationId+status) → hex
// Aşama A'da webhook, bu imza mevcutsa doğrular; YOKSA (özellik hesapta
// henüz açık değilse) imza kontrolünü ATLAMAZ — reddeder (fail-closed). Bu
// nedenle Aşama A sandbox testinde önce iyzico destek ile webhook imza
// özelliğinin açıldığından emin olunmalı; aksi halde webhook hiç geçmez.
export async function verifyWebhookSignature(
  headerSignature: string | null,
  payload: {
    iyziEventType: string;
    paymentId: string;
    paymentConversationId: string;
    status: string;
  },
): Promise<boolean> {
  if (!headerSignature) return false;
  const secretKey = Deno.env.get("IYZICO_SECRET_KEY");
  if (!secretKey) throw new Error("IYZICO_SECRET_KEY secret olarak ayarlanmamış.");

  const expected = await hmacSha256Hex(
    secretKey,
    secretKey +
      payload.iyziEventType +
      payload.paymentId +
      payload.paymentConversationId +
      payload.status,
  );
  return expected === headerSignature;
}

// Hizmet bedeli: Cloudflare maliyet fiyatının üzerine v1 kararı olan %25
// (kullanıcı onaylı). Edge Function içinde tek yerde tutulur ki oran
// değişirse tek satır güncellensin.
export const SERVICE_FEE_MULTIPLIER = 1.25;
