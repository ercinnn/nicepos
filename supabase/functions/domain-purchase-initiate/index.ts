import "@supabase/functions-js/edge-runtime.d.ts";
import { getCloudflareClient, type RegistrantContact } from "../_shared/cloudflare.ts";
import { initializeCheckoutForm, SERVICE_FEE_MULTIPLIER } from "../_shared/iyzico.ts";
import { AuthError, requireAuthContext, requireOwnerOrAdmin } from "../_shared/authContext.ts";
import { handleCorsPreflight, jsonResponse } from "../_shared/cors.ts";

// identityNumber yalnız iyzico'nun ödeme/KYC şeması gereği (T.C. kimlik no
// veya yabancı kimlik/pasaport) — Cloudflare Registrar'a GÖNDERİLMEZ, v1
// TLD kapsamı (.com/.net/.org) bunu gerektirmiyor. Bu yüzden RegistrantContact
// (Cloudflare tarafı) ile ayrı tutulur, aşağıda destructure edilir.
interface InitiateBody {
  domain: string;
  registrant: RegistrantContact & { identityNumber: string };
  callbackUrl: string;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const ctx = await requireAuthContext(req);
    requireOwnerOrAdmin(ctx);

    const body: InitiateBody = await req.json();
    if (!body.domain || !body.registrant || !body.callbackUrl) {
      return jsonResponse({ error: "Eksik alan." }, 400);
    }

    // 1) Ödeme başlatmadan ÖNCE taze fiyat/müsaitlik kontrolü.
    const [check] = await getCloudflareClient().checkDomains([body.domain]);
    if (!check || !check.available) {
      return jsonResponse({ error: "Bu domain artık müsait değil." }, 409);
    }

    const cfPrice = check.priceAmount;
    const paidPrice = Math.round(cfPrice * SERVICE_FEE_MULTIPLIER * 100) / 100;
    const conversationId = crypto.randomUUID();
    const { identityNumber, ...cfContact } = body.registrant;

    // 2) iyzico Checkout Form başlat — kiracıdan (mağaza sahibinden) tahsilat,
    // storefront'un müşteri ödemesinden AYRI bir akış.
    // iyzico'da `price` (sepet toplamı) ile basketItems fiyatları toplamı
    // eşleşmeli — burada indirim/kampanya YOK, kiracıya fiilen tahsil edilen
    // (Cloudflare maliyeti + %25 hizmet bedeli) hem `price` hem `paidPrice`
    // hem de tek basketItem'ın fiyatı olarak birebir kullanılır.
    const iyzico = await initializeCheckoutForm({
      conversationId,
      price: paidPrice.toFixed(2),
      paidPrice: paidPrice.toFixed(2),
      currency: check.priceCurrency === "USD" ? "USD" : "TRY",
      basketId: `domain-${body.domain}`,
      callbackUrl: body.callbackUrl,
      buyer: {
        id: ctx.userId,
        name: cfContact.firstName,
        surname: cfContact.lastName,
        identityNumber,
        email: cfContact.email,
        gsmNumber: cfContact.phone,
        registrationAddress: cfContact.address,
        city: cfContact.city,
        country: cfContact.country,
        ip: req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "0.0.0.0",
      },
      billingAddress: {
        address: cfContact.address,
        contactName: `${cfContact.firstName} ${cfContact.lastName}`,
        city: cfContact.city,
        country: cfContact.country,
      },
      basketItems: [
        {
          id: body.domain,
          price: paidPrice.toFixed(2),
          name: `Alan adı kaydı: ${body.domain}`,
          category1: "Domain",
          itemType: "VIRTUAL",
        },
      ],
    });

    if (iyzico.status !== "success" || !iyzico.token) {
      return jsonResponse(
        { error: iyzico.errorMessage ?? "Ödeme başlatılamadı." },
        502,
      );
    }

    // 3) Takip satırını KULLANICININ KENDİ JWT'siyle oluştur — service-role
    // DEĞİL, current_tenant_id()'nin doğru kiracıya çözülmesi için.
    const { data: row, error } = await ctx.client
      .rpc("create_domain_purchase_request", {
        p_domain: body.domain,
        p_price_amount: cfPrice,
        p_price_currency: check.priceCurrency,
        p_registrant_contact: body.registrant,
        p_iyzico_conversation_id: conversationId,
        p_iyzico_token: iyzico.token,
      })
      .single();

    if (error) throw error;

    return jsonResponse({
      purchaseId: (row as { id: string }).id,
      checkoutFormContent: iyzico.checkoutFormContent,
      paymentPageUrl: iyzico.paymentPageUrl,
    });
  } catch (e) {
    if (e instanceof AuthError) return jsonResponse({ error: e.message }, e.status);
    console.error(e);
    return jsonResponse({ error: "Satın alma başlatılamadı." }, 500);
  }
});
