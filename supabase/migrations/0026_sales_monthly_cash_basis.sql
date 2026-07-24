-- NicePOS - `sales_monthly_totals` görünümünü NAKİT-ESASLI ciroya çevirir
--
-- Amaç: Dashboard "Yıllık Ciro Karşılaştırma" + "Yıllık Ortalama Ciro" grafikleri
-- ve "Yıllık Ciro" kartının sparkline'ı bu görünümdeki aylık kırılımı kullanır
-- (currentYearMonthly / historicalYearly). Önceki tanım `SUM(total_amount)`
-- (tahakkuk-esaslı) idi. Kullanıcı kararı: TÜM ciro yüzeyleri NAKİT-ESASLI olmalı.
--
-- Nakit-esaslı aylık ciro = o aya düşen iki bileşenin toplamı:
--   (1) o ay yapılan satışların `paid_amount` toplamı (peşin kısım),
--   + (2) o ay gelen borç TAHSİLATLARI: `customer_payments` type='odeme' amount.
-- ⚠️ `type='borc'` HARİÇ (borcun kendisi, kasaya giren para değil). İade
-- satışlarında `paid_amount` negatiftir → doğru biçimde düşer. (Bkz. RPC için
-- 0025_sales_revenue_cash_basis.sql — aynı nakit-esaslı tanım.)
--
-- ⚠️ GÖRÜNÜM AYNI ADLA YENİDEN TANIMLANIR (`CREATE OR REPLACE VIEW`): çıktı
-- kolonları (year, month, total) ve tipleri DEĞİŞMEZ → istemci tarafında sorgu
-- adı/kolonları değişmez, "relation does not exist" riski YOKTUR. Migration
-- uygulanana kadar görünüm eski (brüt) değerleri döndürmeye devam eder, çökmez;
-- uygulandıktan sonra yıllık grafikler nakit-esaslıya döner.
--
-- Zaman dilimi (ÖNEMLİ): İstemcinin yerel-gün/ay gruplamasıyla (`.toLocal()` =
-- Europe/Istanbul) birebir örtüşmesi için hem `sale_date` hem `payment_date`
-- `AT TIME ZONE 'Europe/Istanbul'` ile yerele çevrilip yıl/ay çıkarılır. Böylece
-- ay sınırındaki (gece yarısı) kayıtlar istemcideki günlük/aylık kartlarla aynı
-- aya düşer → "günlük çubukların toplamı = aylık kart = yıllık" tutarlılığı korunur.
--
-- RLS: `security_invoker = true` → görünümü sorgulayan kullanıcının hem `sales`
-- hem `customer_payments` RLS politikaları uygulanır (ikisi de "authenticated
-- full access", bkz. 0002_rls.sql). CREATE OR REPLACE ile bu ayar yeniden belirtilir.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace view sales_monthly_totals
with (security_invoker = true) as
with cash_flows as (
  -- (1) Satışların peşin (paid_amount) kısmı — satış gününe göre
  select
    extract(year  from (sale_date at time zone 'Europe/Istanbul'))::int as year,
    extract(month from (sale_date at time zone 'Europe/Istanbul'))::int as month,
    sum(paid_amount) as total
  from sales
  group by 1, 2
  union all
  -- (2) Borç tahsilatları (yalnız type='odeme') — tahsilat gününe göre
  select
    extract(year  from (payment_date at time zone 'Europe/Istanbul'))::int as year,
    extract(month from (payment_date at time zone 'Europe/Istanbul'))::int as month,
    sum(amount) as total
  from customer_payments
  where type = 'odeme'
  group by 1, 2
)
select
  year,
  month,
  sum(total) as total
from cash_flows
group by 1, 2;

-- anon/authenticated rollerinin görünümü SELECT edebilmesi için grant
-- (satır görünürlüğü security_invoker sayesinde yine tabloların RLS'ine bağlıdır).
grant select on sales_monthly_totals to anon, authenticated;
