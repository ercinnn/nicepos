// Flutter web (ana uygulama, farklı origin'den) Edge Function'ları doğrudan
// tarayıcıdan çağırıyor — CORS preflight (OPTIONS) + yanıt header'ları burada
// tek yerde. `iyzico-webhook` de bunu kullanır (zararsız, tarayıcıdan
// çağrılmasa da header'lar sorun çıkarmaz).
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function handleCorsPreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
