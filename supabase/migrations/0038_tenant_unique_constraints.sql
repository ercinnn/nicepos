-- =============================================================================
-- 0038: Global unique kısıtların kiracı-bazlı hale getirilmesi — Faz A / Adım 3
-- =============================================================================
-- Önkoşul: 0037_tenant_id_columns.sql (tenant_id her tabloda mevcut).
--
-- Sorun: Bazı sütunlar bugüne kadar TÜM veritabanında (tek şirket olduğu için
-- sorunsuzca) global unique'ti. Çok kiracılı bir dünyada bu YANLIŞ: iki farklı
-- şirket aynı barkodu (çoğu zaman standart bir üretici barkodu), aynı müşteri
-- adını veya aynı gider kategori adını ("Kira") kullanabilir — bunlar birbirini
-- ENGELLEMEMELİ. Çözüm: her kısıt (tenant_id, <sütun>) bileşik hale getirilir —
-- tekillik artık yalnızca AYNI kiracı içinde geçerli olur.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (drop if exists + yeniden ekleme) — kısmen uygulanmışsa tekrar
-- çalıştırmak güvenlidir.
-- =============================================================================

-- products.barcode: tek şirkette benzersizdi → artık (tenant_id, barcode).
alter table products drop constraint if exists products_barcode_key;
alter table products drop constraint if exists products_tenant_barcode_key;
alter table products add constraint products_tenant_barcode_key unique (tenant_id, barcode);

-- sales.sale_code: (tenant_id, sale_code).
alter table sales drop constraint if exists sales_sale_code_key;
alter table sales drop constraint if exists sales_tenant_sale_code_key;
alter table sales add constraint sales_tenant_sale_code_key unique (tenant_id, sale_code);

-- customers.name: (tenant_id, name) — iki şirket aynı isimde müşteri tutabilir.
alter table customers drop constraint if exists customers_name_key;
alter table customers drop constraint if exists customers_tenant_name_key;
alter table customers add constraint customers_tenant_name_key unique (tenant_id, name);

-- online_orders.order_code: (tenant_id, order_code).
alter table online_orders drop constraint if exists online_orders_order_code_key;
alter table online_orders drop constraint if exists online_orders_tenant_order_code_key;
alter table online_orders add constraint online_orders_tenant_order_code_key unique (tenant_id, order_code);

-- kasa_expense_categories.name: (tenant_id, name) — her kiracı kendi gider
-- kategori setini yönetir ("Kira" adı iki kiracıda da bağımsız var olabilir).
alter table kasa_expense_categories drop constraint if exists kasa_expense_categories_name_key;
alter table kasa_expense_categories drop constraint if exists kasa_expense_categories_tenant_name_key;
alter table kasa_expense_categories add constraint kasa_expense_categories_tenant_name_key unique (tenant_id, name);

-- kasa_opening_balances: PK tek başına fiscal_year'dı → (tenant_id, fiscal_year).
alter table kasa_opening_balances drop constraint if exists kasa_opening_balances_pkey;
alter table kasa_opening_balances add primary key (tenant_id, fiscal_year);

-- kasa_reconciliations: gün+kanal idempotentliği artık kiracı bazında.
alter table kasa_reconciliations drop constraint if exists kasa_reconciliations_day_channel_uq;
alter table kasa_reconciliations drop constraint if exists kasa_reconciliations_tenant_day_channel_uq;
alter table kasa_reconciliations add constraint kasa_reconciliations_tenant_day_channel_uq
  unique (tenant_id, fiscal_year, entry_date, channel);
