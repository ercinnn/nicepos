-- NicePOS - Müşteri bakiye görünümü
-- Borç modeli: customer_payments tablosu tek kaynak.
--   type='borc'  -> müşteri borcunu artıran kayıt (açık hesap satışı veya manuel "Borç Ekle")
--   type='odeme' -> müşteri borcunu azaltan kayıt ("Ödeme Ekle")
-- Kalan Borç = sum(borc) - sum(odeme)

create or replace view customer_balances
with (security_invoker = true) as
select
  c.id,
  c.name,
  c.payment_term_days,
  c.phone,
  c.address,
  c.note,
  c.credit_limit,
  c.tax_office,
  c.tax_number,
  c.created_at,
  coalesce(s.purchase_count, 0) as purchase_count,
  coalesce(b.borc_total, 0) as open_account_total,
  coalesce(p.paid_total, 0) as paid_total,
  coalesce(b.borc_total, 0) - coalesce(p.paid_total, 0) as remaining_debt,
  p.last_payment_date
from customers c
left join (
  select customer_id, count(*) as purchase_count
  from sales
  where customer_id is not null
  group by customer_id
) s on s.customer_id = c.id
left join (
  select customer_id, sum(amount) as borc_total
  from customer_payments
  where type = 'borc'
  group by customer_id
) b on b.customer_id = c.id
left join (
  select customer_id, sum(amount) as paid_total, max(payment_date) as last_payment_date
  from customer_payments
  where type = 'odeme'
  group by customer_id
) p on p.customer_id = c.id;
