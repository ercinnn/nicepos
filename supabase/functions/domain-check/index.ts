import "@supabase/functions-js/edge-runtime.d.ts";
import { getCloudflareClient } from "../_shared/cloudflare.ts";
import { AuthError, requireAuthContext } from "../_shared/authContext.ts";
import { handleCorsPreflight, jsonResponse } from "../_shared/cors.ts";

// Gerçek zamanlı müsaitlik + kesin fiyat (≤20 domain). Kayıttan HEMEN önce
// tekrar çağrılması gerekir (bkz. domain-purchase-initiate, iyzico-webhook)
// — fiyat/müsaitlik zamanla kayabilir.
Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    await requireAuthContext(req);

    const { domains } = await req.json();
    if (!Array.isArray(domains) || domains.length === 0 || domains.length > 20) {
      return jsonResponse({ error: "1-20 arası domain gerekli." }, 400);
    }

    const results = await getCloudflareClient().checkDomains(domains);
    return jsonResponse({ results });
  } catch (e) {
    if (e instanceof AuthError) return jsonResponse({ error: e.message }, e.status);
    console.error(e);
    return jsonResponse({ error: "Kontrol başarısız oldu." }, 500);
  }
});
