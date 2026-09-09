import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

// Service-role client — yalnız webhook (iyzico-webhook) ve cron (
// domain-registration-poll) fonksiyonlarında kullanılır. RLS'i bypass eder,
// bu yüzden bu iki fonksiyon DIŞINDA hiçbir yerde import EDİLMEMELİ. Normal
// kullanıcı istekleri (domain-search/domain-check/domain-purchase-initiate)
// çağıranın kendi JWT'siyle authContext.ts üzerinden gitmeli.
export function getSupabaseAdmin(): SupabaseClient {
  // SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY her Edge Function ortamına
  // Supabase tarafından OTOMATİK enjekte edilir — `supabase secrets set` ile
  // AYRICA ayarlanmaz (aksine izin de verilmez, rezerve isimlerdir).
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY secret olarak ayarlanmamış.",
    );
  }
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });
}
