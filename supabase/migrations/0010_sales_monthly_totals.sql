-- NicePOS - Aylık satış toplamları görünümü (dashboard yıllık grafik hızı)
--
-- Amaç: Dashboard yıllık karşılaştırma grafiği eskiden binlerce `sales` satırını
-- istemciye çekip Dart tarafında topluyordu (ilk yükleme yavaştı). Bu görünüm
-- toplamayı sunucuda (Postgres GROUP BY) yapar → istemci yıl×ay başına yalnız
-- tek satır çeker (yılda en fazla 12 satır).
--
-- Zaman dilimi notu (ÖNEMLİ): İstemci eski kodda `sale_date`'i yerel saate
-- (`DateTime.toLocal()`) çevirip yıl/ay çıkarıyordu. Aynı gruplamayı BİREBİR
-- korumak için burada da `AT TIME ZONE 'Europe/Istanbul'` ile yerel saate
-- çevrilir; böylece ay/yıl sınırındaki (gece yarısı civarı) satışlar eski
-- davranışla aynı aya düşer, rakamlar değişmez.
--
-- RLS: `security_invoker = true` → görünümü sorgulayan kullanıcının `sales`
-- tablosundaki RLS politikası uygulanır (customer_balances görünümü ile aynı
-- desen). Böylece yalnız giriş yapmış (authenticated) kullanıcı satırları görür.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da çalıştırın.

create or replace view sales_monthly_totals
with (security_invoker = true) as
select
  extract(year  from (sale_date at time zone 'Europe/Istanbul'))::int as year,
  extract(month from (sale_date at time zone 'Europe/Istanbul'))::int as month,
  sum(total_amount) as total
from sales
group by 1, 2;

-- anon/authenticated rollerinin görünümü SELECT edebilmesi için grant.
-- (Satır görünürlüğü security_invoker sayesinde yine `sales` RLS politikasına
--  bağlıdır; grant yalnız görünüme erişim iznidir.)
grant select on sales_monthly_totals to anon, authenticated;
