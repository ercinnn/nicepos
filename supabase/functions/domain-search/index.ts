import "@supabase/functions-js/edge-runtime.d.ts";
import { getCloudflareClient } from "../_shared/cloudflare.ts";
import { AuthError, requireAuthContext } from "../_shared/authContext.ts";
import { handleCorsPreflight, jsonResponse } from "../_shared/cors.ts";

// Aday domain isimleri + önbellekli fiyat — salt-okunur, düşük risk, herhangi
// bir kiracı kullanıcısı (owner/admin/staff) çağırabilir. Aşama A'da
// (Cloudflare Registrar hesabı hazır olana kadar) mock veri döner —
// bkz. _shared/cloudflare.ts.
Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    await requireAuthContext(req);

    const { query } = await req.json();
    if (!query || typeof query !== "string" || query.trim().length < 2) {
      return jsonResponse({ error: "En az 2 karakter girin." }, 400);
    }

    const results = await getCloudflareClient().searchDomains(query);
    return jsonResponse({ results });
  } catch (e) {
    if (e instanceof AuthError) return jsonResponse({ error: e.message }, e.status);
    console.error(e);
    return jsonResponse({ error: "Arama başarısız oldu." }, 500);
  }
});
