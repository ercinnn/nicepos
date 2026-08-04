-- customer_payments üzerinde nakit-esaslı ciro sorguları (dashboard/raporlar/kasa)
-- payment_date + type='odeme' predicate'iyle filtreliyor ama bu kolonlarda index yoktu
-- (yalnız customer_id indeksliydi, bkz. 0001_init.sql). Kısmi index yalnız 'odeme'
-- satırlarını kapsar, yazma maliyeti düşük.
create index if not exists customer_payments_odeme_date_idx
  on customer_payments (payment_date)
  where type = 'odeme';
