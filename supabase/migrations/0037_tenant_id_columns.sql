-- =============================================================================
-- 0037: Her iş tablosuna tenant_id eklenmesi — Faz A / Adım 2
-- =============================================================================
-- Önkoşul: 0036_tenancy_foundation.sql (tenants/memberships tabloları +
-- current_tenant_id() fonksiyonu + 1. kiracının seed edilmesi).
--
-- Her tabloya aynı desen uygulanır:
--   1) tenant_id uuid sütunu eklenir (nullable, tenants FK'li).
--   2) Mevcut TÜM satırlar 0036'da seed edilen "1. kiracı"ya bağlanır.
--   3) not null kısıtı eklenir.
--   4) default current_tenant_id() eklenir — bundan sonra istemci INSERT'lerinde
--      tenant_id'yi HİÇ belirtmesi gerekmez, DB otomatik dolduur (Dart tarafında
--      `toInsertMap()` metodlarının HİÇBİRİNE dokunulmasına gerek YOK — bu,
--      "izolasyon uygulama kodunda değil DB'de zorunlu kılınmalı" ilkesinin
--      pratik karşılığı).
--   5) tenant_id lider indeks olarak eklenir (bundan sonra her sorgunun ana
--      filtresi olacağı için).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir — kısmen uygulanmışsa tekrar çalıştırmak güvenlidir.
-- ⚠️ Bu migration'dan SONRA ama 0039 (RLS yeniden yazımı) UYGULANMADAN ÖNCE
-- uygulama eski "authenticated = tam erişim" politikalarıyla çalışmaya devam
-- eder — geçiş penceresinde veri kaybı/erişim kaybı riski yoktur.
-- =============================================================================

do $$
declare
  v_seed_tenant uuid := '00000000-0000-0000-0000-000000000001';
  t text;
  tables text[] := array[
    'product_groups', 'products', 'customers', 'sales', 'sale_items',
    'customer_payments', 'companies', 'kasa_entries', 'kasa_expense_categories',
    'kasa_opening_balances', 'kasa_reconciliations', 'online_orders',
    'online_order_items', 'label_pool_items', 'label_scan_activity',
    'gorev_tamamlamalar'
  ];
begin
  foreach t in array tables loop
    execute format('alter table %I add column if not exists tenant_id uuid references tenants(id)', t);
    execute format('update %I set tenant_id = %L where tenant_id is null', t, v_seed_tenant);
    execute format('alter table %I alter column tenant_id set not null', t);
    execute format('alter table %I alter column tenant_id set default current_tenant_id()', t);
    execute format('create index if not exists %I on %I (tenant_id)', 'idx_' || t || '_tenant_id', t);
  end loop;
end $$;
