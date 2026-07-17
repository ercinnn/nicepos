-- NicePOS - Tarih aralığı ciro toplamı RPC'si (dashboard YTD/365-gün hızı)
--
-- Amaç: Dashboard "Yıllık Ciro" (YTD) ve "Son 365 Günlük Ciro" kartları eskiden
-- o aralıktaki TÜM `sales` satırlarını istemciye çekip Dart tarafında topluyordu
-- (binlerce satır, ~5sn). Bu fonksiyon toplamayı sunucuda (`sale_date` index'i
-- ile) tek `SUM()` sorgusuyla yapar → istemci tek sayısal değer alır.
--
-- RLS: SECURITY INVOKER (varsayılan) — fonksiyonu çağıran kullanıcının `sales`
-- tablosundaki RLS politikası uygulanır (sales_monthly_totals view'ı ile aynı
-- desen).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace function sales_revenue_between(start_ts timestamptz, end_ts timestamptz)
returns numeric language sql stable as $$
  select coalesce(sum(total_amount), 0) from sales
  where sale_date >= start_ts and sale_date < end_ts;
$$;

grant execute on function sales_revenue_between to anon, authenticated;
