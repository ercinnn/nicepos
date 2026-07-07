-- =============================================================================
-- 0013: Kasa gider kategorisi seed — "Ürün Alımı"
-- =============================================================================
-- Firma hanesi kasada YALNIZ bu gider kalemi seçiliyken açılır (KARAR v1.9.4).
-- Idempotent: tekrar çalıştırmak güvenlidir.
insert into kasa_expense_categories (name) values ('Ürün Alımı')
on conflict (name) do nothing;
