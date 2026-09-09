-- =============================================================================
-- 0049: domain-registration-poll için pg_cron zamanlaması
-- =============================================================================
-- Postgres kendi başına dış HTTP çağrısı yapamaz — `pg_net` (async HTTP) +
-- `pg_cron` (zamanlayıcı) ile Edge Function'ı düzenli tetikleyen standart
-- Supabase deseni budur. `domain-registration-poll` fonksiyonu `registering`
-- durumundaki satırları tarar, Cloudflare kayıt durumunu sorup DNS/Pages
-- bağlamasını tamamlar (bkz. supabase/functions/domain-registration-poll).
--
-- ⚠️ MANUEL ÖN KOŞUL (bu migration'ı çalıştırmadan ÖNCE): Supabase Dashboard
-- → Database → Extensions'tan `pg_cron` ve `pg_net` açılmalı — SQL Editor'dan
-- `create extension` bazı planlarda/izinlerde çalışmayabiliyor, dashboard'dan
-- açmak garantili yol.
--
-- Aşağıdaki değer, `domain-registration-poll`'un bu isteğin GERÇEKTEN bizim
-- veritabanımızdan geldiğini anlaması için kullandığı paylaşımlı bir "iç
-- şifre" (rastgele üretildi, elle hatırlamanız/kullanmanız gerekmez) — AYNI
-- değer `POLL_TRIGGER_SECRET` adıyla Edge Function secret'ı olarak da
-- ayarlanmalı (bu depoyu yöneten tarafından `supabase secrets set` ile),
-- ikisi eşleşmezse fonksiyon her tetiklemeyi 401 ile reddeder (bilinçli
-- fail-closed davranış). Servis-rolü anahtarı BURAYA (versiyon kontrollü bir
-- migration dosyasına) asla yazılmaz — bu ondan ayrı, tek amaçlı bir sır.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (cron.schedule aynı isimle çağrılırsa günceller).
-- =============================================================================

select cron.schedule(
  'domain-registration-poll',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://maogkrllltlxkfdwfsdj.supabase.co/functions/v1/domain-registration-poll',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-poll-secret', 'd3dc6e7f0376115031be59baeb0b1c477f8e0ac325ead3e4'
    ),
    body := '{}'::jsonb
  );
  $$
);
