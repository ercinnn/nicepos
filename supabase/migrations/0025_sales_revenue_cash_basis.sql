-- NicePOS - `sales_revenue_between` RPC'sini NAKİT-ESASLI ciroya çevirir
--
-- Amaç: Dashboard "Yıllık Ciro" (YTD), "Son 365 Günlük Ciro" ve "Geçen Ay"
-- kartları bu RPC'yi kullanır. Önceki tanım `SUM(total_amount)` (tahakkuk-esaslı:
-- satış anındaki brüt tutar) idi. Kullanıcı kararı: TÜM ciro yüzeyleri
-- NAKİT-ESASLI olmalı — "o gün/aralıkta fiilen kasaya giren para".
--
-- Nakit-esaslı ciro tanımı (aralık [start_ts, end_ts) için):
--   (1) o aralıkta yapılan satışların `paid_amount` toplamı (peşin kısım;
--       açık hesabın ödenmemiş kısmı `remaining_debt`'te kalır, ciroya GİRMEZ),
--   + (2) o aralıkta gelen borç TAHSİLATLARI: `customer_payments` içinde
--       yalnız `type = 'odeme'` kayıtlarının `amount` toplamı.
--
-- ⚠️ `type = 'borc'` HARİÇ: açık hesap satışında `completeSale` otomatik olarak
-- `type='borc'` (pozitif amount) bir hareket ekler — bu borcun KENDİSİdir, kasaya
-- giren para değildir. Sayılırsa ciroyu şişirir. Bu yüzden yalnız `'odeme'`.
-- İade satışlarında `paid_amount` negatiftir → ciroyu doğru biçimde azaltır.
-- Kanal (nakit/pos) ayrımı YOK: her ikisi de kasaya giren paradır.
--
-- İmza (start_ts, end_ts) ve dönüş tipi (numeric) DEĞİŞMEDİ → `CREATE OR REPLACE`
-- yeterli, eski overload temizliğine gerek yok.
--
-- Zaman dilimi: start_ts/end_ts istemcide yerel gün sınırlarından (`DateTime` →
-- `.toUtc()`) üretilir; karşılaştırma mutlak zamanda yapıldığından istemcinin
-- yerel-gün gruplamasıyla (dailySales/monthSummary `.toLocal()`) birebir örtüşür.
--
-- RLS: SECURITY INVOKER (varsayılan) — çağıran kullanıcının hem `sales` hem
-- `customer_payments` RLS politikaları uygulanır (ikisi de "authenticated full
-- access", bkz. 0002_rls.sql).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- ⚠️ Bu migration UYGULANMADAN önce RPC eski (brüt) değeri döndürmeye devam eder;
--    uygulandıktan sonra Yıllık/365-gün/Geçen Ay kartları nakit-esaslıya döner.

create or replace function sales_revenue_between(start_ts timestamptz, end_ts timestamptz)
returns numeric language sql stable as $$
  select
    coalesce((
      select sum(paid_amount) from sales
      where sale_date >= start_ts and sale_date < end_ts
    ), 0)
    + coalesce((
      select sum(amount) from customer_payments
      where type = 'odeme'
        and payment_date >= start_ts and payment_date < end_ts
    ), 0);
$$;

grant execute on function sales_revenue_between to anon, authenticated;
