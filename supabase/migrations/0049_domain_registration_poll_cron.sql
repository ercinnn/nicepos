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
-- ⚠️ MANUEL DOLDURMA GEREKİR: aşağıdaki `REPLACE_WITH_RANDOM_SECRET` gerçek,
-- rastgele üretilmiş bir değerle değiştirilmeli (ör. `openssl rand -hex 32`)
-- VE AYNI değer `domain-registration-poll` Edge Function'ının
-- `POLL_TRIGGER_SECRET` secret'ı olarak da ayarlanmalı
-- (`supabase secrets set POLL_TRIGGER_SECRET=...`) — ikisi eşleşmezse
-- fonksiyon her tetiklemeyi 401 ile reddeder (bilinçli fail-closed davranış,
-- bkz. authContext deseni). Servis-rolü anahtarı BURAYA (versiyon kontrollü
-- bir migration dosyasına) asla yazılmaz — ayrı, tek amaçlı bir paylaşılan
-- sır kullanılır.
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
      'x-poll-secret', 'REPLACE_WITH_RANDOM_SECRET'
    ),
    body := '{}'::jsonb
  );
  $$
);
