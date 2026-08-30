import "@supabase/functions-js/edge-runtime.d.ts";
import { getCloudflareClient, type RegistrantContact } from "../_shared/cloudflare.ts";
import { retrieveCheckoutForm, verifyWebhookSignature } from "../_shared/iyzico.ts";
import { getSupabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { handleCorsPreflight, jsonResponse } from "../_shared/cors.ts";

// Public uç — iyzico çağırır, Supabase JWT YOK. İstemci/webhook body'sine
// asla güvenilmez: "ödeme başarılı" iddiası her zaman CF Retrieve ile
// SUNUCU tarafında teyit edilir (bkz. verifyWebhookSignature + retrieveCheckoutForm).
Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  let body: {
    iyziEventType: string;
    paymentId: string;
    paymentConversationId: string;
    status: string;
    token?: string;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Geçersiz istek gövdesi." }, 400);
  }

  const signature = req.headers.get("x-iyz-signature-v3");
  const signatureValid = await verifyWebhookSignature(signature, {
    iyziEventType: body.iyziEventType,
    paymentId: body.paymentId,
    paymentConversationId: body.paymentConversationId,
    status: body.status,
  });
  if (!signatureValid) {
    // fail-closed: imza özelliği hesapta açık değilse (bkz. iyzico.ts notu)
    // TÜM webhook'lar burada reddedilir — Aşama A'da iyzico destek ile
    // özelliğin açıldığından emin olunmalı, aksi halde bu asla geçmez.
    console.error("iyzico webhook imza doğrulaması başarısız.");
    return jsonResponse({ error: "İmza geçersiz." }, 401);
  }

  const admin = getSupabaseAdmin();

  const { data: purchase, error: findError } = await admin
    .from("domain_purchases")
    .select("*")
    .eq("iyzico_conversation_id", body.paymentConversationId)
    .maybeSingle();

  if (findError) {
    console.error(findError);
    return jsonResponse({ error: "Sorgu hatası." }, 500);
  }
  if (!purchase) {
    // Eşleşen kayıt yok — tekrar denemesi faydasız, 200 ile ack et.
    console.warn(`Eşleşmeyen webhook: ${body.paymentConversationId}`);
    return jsonResponse({ ok: true });
  }

  // Sunucu tarafında GERÇEK ödeme durumunu teyit et — webhook body'sine güvenilmez.
  const retrieve = await retrieveCheckoutForm(
    purchase.iyzico_token,
    body.paymentConversationId,
  );

  if (retrieve.status !== "success" || retrieve.paymentStatus !== "SUCCESS") {
    // Ödeme gerçekten başarısız/reddedildi — para HİÇ alınmadı, normal bir
    // "başarısız ödeme" durumu (elle inceleme GEREKMİYOR).
    await admin
      .from("domain_purchases")
      .update({
        status: "failed",
        failure_stage: "payment_pending",
        last_error: retrieve,
        updated_at: new Date().toISOString(),
      })
      .eq("id", purchase.id);
    return jsonResponse({ ok: true });
  }

  await admin
    .from("domain_purchases")
    .update({
      status: "paid",
      iyzico_payment_id: retrieve.paymentId,
      iyzico_raw_status: retrieve.paymentStatus,
      updated_at: new Date().toISOString(),
    })
    .eq("id", purchase.id);

  // Fiyat/müsaitlik ödeme sırasında kaymış olabilir — kayıttan hemen önce
  // TEKRAR kontrol et (Cloudflare'in "check immediately before register"
  // best practice'i).
  const cf = getCloudflareClient();
  const [recheck] = await cf.checkDomains([purchase.domain]);

  if (!recheck || !recheck.available) {
    // ⚠️ "Para alındı, domain alınamadı" — v1 cevabı: elle inceleme bayrağı,
    // OTOMATİK İADE YOK (bkz. plan §7/§8).
    await admin
      .from("domain_purchases")
      .update({
        status: "failed",
        failure_stage: "registering",
        needs_manual_review: true,
        last_error: { reason: "domain_no_longer_available" },
        updated_at: new Date().toISOString(),
      })
      .eq("id", purchase.id);
    return jsonResponse({ ok: true });
  }

  try {
    const contact = purchase.registrant_contact as RegistrantContact;
    const registration = await cf.registerDomain(purchase.domain, contact);
    await admin
      .from("domain_purchases")
      .update({
        status: "registering",
        cf_registration_id: registration.registrationId,
        cf_raw_status: registration.status,
        updated_at: new Date().toISOString(),
      })
      .eq("id", purchase.id);
  } catch (e) {
    // Yine "para alındı, domain alınamadı" senaryosu — Cloudflare tarafı
    // hata verdi.
    await admin
      .from("domain_purchases")
      .update({
        status: "failed",
        failure_stage: "registering",
        needs_manual_review: true,
        last_error: { message: String(e) },
        updated_at: new Date().toISOString(),
      })
      .eq("id", purchase.id);
  }

  // Webhook'lar hızlı yanıt vermeli — asıl kayıt/DNS bekleme
  // domain-registration-poll'un işi.
  return jsonResponse({ ok: true });
});
