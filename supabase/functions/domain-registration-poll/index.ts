import "@supabase/functions-js/edge-runtime.d.ts";
import { getCloudflareClient, PAGES_TARGET } from "../_shared/cloudflare.ts";
import { getSupabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { jsonResponse } from "../_shared/cors.ts";

// pg_cron + pg_net tarafından her dakika tetiklenir (bkz. 0049 migration).
// Gerçek bir Supabase JWT taşımaz — paylaşılan bir sırla (POLL_TRIGGER_SECRET)
// doğrulanır, aksi halde herkese açık bir uç olurdu (fail-closed).
const TIMEOUT_MS = 24 * 60 * 60 * 1000; // 24 saat sonra hâlâ 'registering'se elle incelemeye düşer

Deno.serve(async (req) => {
  const providedSecret = req.headers.get("x-poll-secret");
  const expectedSecret = Deno.env.get("POLL_TRIGGER_SECRET");
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return jsonResponse({ error: "Yetkisiz." }, 401);
  }

  const admin = getSupabaseAdmin();
  const cf = getCloudflareClient();

  const { data: rows, error } = await admin
    .from("domain_purchases")
    .select("id, domain, tenant_id, created_at")
    .eq("status", "registering");

  if (error) {
    console.error(error);
    return jsonResponse({ error: "Sorgu hatası." }, 500);
  }

  let connected = 0;
  let stillPending = 0;
  let timedOut = 0;

  for (const row of rows ?? []) {
    try {
      const status = await cf.getRegistrationStatus(row.domain);

      if (status.status !== "complete") {
        const elapsed = Date.now() - new Date(row.created_at).getTime();
        if (elapsed > TIMEOUT_MS) {
          await admin
            .from("domain_purchases")
            .update({
              status: "failed",
              failure_stage: "timeout",
              needs_manual_review: true,
              last_error: { reason: "registration_status_timeout" },
              updated_at: new Date().toISOString(),
            })
            .eq("id", row.id);
          timedOut++;
        } else {
          stillPending++;
        }
        continue;
      }

      // Kayıt tamamlandı — aynı geçişte DNS + Pages custom domain bağlanır.
      const zoneId = status.zoneId!;
      const dnsRecordId = await cf.createCnameRecord(zoneId, PAGES_TARGET);
      const pagesResult = await cf.addPagesCustomDomain(row.domain);

      await admin
        .from("domain_purchases")
        .update({
          status: "connected",
          cf_zone_id: zoneId,
          cf_raw_status: status.status,
          dns_record_id: dnsRecordId,
          pages_domain_status: pagesResult.status,
          updated_at: new Date().toISOString(),
        })
        .eq("id", row.id);

      await admin
        .from("tenants")
        .update({ custom_domain: row.domain, custom_domain_status: "connected" })
        .eq("id", row.tenant_id);

      connected++;
    } catch (e) {
      // Kayıt gerçekten alınmış olabilir (yalnız DNS/Pages adımı takıldı) —
      // ödeme+domain kaybı senaryosundan daha düşük önemde, yine de elle
      // inceleme bayrağı konur.
      console.error(`Poll hatası (${row.domain}):`, e);
      await admin
        .from("domain_purchases")
        .update({
          status: "failed",
          failure_stage: "connecting_dns",
          needs_manual_review: true,
          last_error: { message: String(e) },
          updated_at: new Date().toISOString(),
        })
        .eq("id", row.id);
    }
  }

  return jsonResponse({ processed: rows?.length ?? 0, connected, stillPending, timedOut });
});
