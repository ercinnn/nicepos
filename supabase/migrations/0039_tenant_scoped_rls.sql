-- =============================================================================
-- 0039: RLS politikalarının kiracı-bazlı yeniden yazılması — Faz A / Adım 4
-- =============================================================================
-- Önkoşul: 0037 (tenant_id her tabloda) + 0038 (unique kısıtlar kiracı-bazlı).
--
-- 0002_rls.sql'den beri her tabloda tekrarlanan "authenticated full access"
-- politikası (`auth.role() = 'authenticated'`) — giriş yapmış HERKESE tüm
-- satırlarda tam erişim veriyordu. Bu, tek şirket senaryosunda doğruydu; çok
-- kiracılı bir dünyada bu politika HİÇ değişmeden kalırsa her kiracı diğer
-- TÜM kiracıların satış/müşteri/fiyat verisini görür ve değiştirebilir — bu
-- migration'ın tek amacı budur: her politikayı
--   `tenant_id = current_tenant_id()`
-- ile değiştirmek. `product_groups` üzerindeki AYRI "public read product_groups"
-- politikasına (0029, storefront kategori navigasyonu için anon'a açık) BURADA
-- DOKUNULMAZ — o politika bilinçli olarak tenant-agnostik bırakılmıştır; gerçek
-- çoklu-kiracı storefront yönlendirmesi Faz F'nin kapsamındadır (bkz. plan).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (drop if exists + yeniden oluşturma) — kısmen uygulanmışsa
-- tekrar çalıştırmak güvenlidir.
-- ⚠️ Bu migration'ı uygulamadan ÖNCE en az bir kullanıcı hesabının 0036'daki
-- seed adımıyla bir `memberships` satırına sahip olduğunu doğrulayın — aksi
-- halde `current_tenant_id()` NULL döner ve o kullanıcı HİÇBİR satırı göremez
-- (kilitlenme riski, veri kaybı değil — ama uygulama boş görünür).
-- =============================================================================

do $$
declare
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
    execute format('drop policy if exists %I on %I', 'authenticated full access', t);
    execute format('drop policy if exists %I on %I', 'tenant scoped access', t);
    execute format(
      'create policy %I on %I for all using (tenant_id = current_tenant_id()) with check (tenant_id = current_tenant_id())',
      'tenant scoped access', t
    );
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- product_groups: "public read" (0029) düzeltmesi — yalnız `anon` rolüne
-- -----------------------------------------------------------------------------
-- 0029'daki `for select using (true)` politikası rol belirtmediğinden hem
-- `anon` hem `authenticated` için geçerliydi. Postgres AYNI komut (select)
-- için permissive politikaları OR'lar — yani yukarıdaki tenant-scoped
-- politika var olsa bile bu politika `true` döndürdüğü için authenticated bir
-- kullanıcı TÜM kiracıların product_groups adlarını görmeye devam ederdi
-- (fiyat/stok değil ama yine de bir çapraz-kiracı sızıntısı). Politika yalnız
-- `anon` rolüne daraltılır — storefront'un bugünkü (Faz F öncesi, tek kiracı)
-- kategori navigasyonu bundan etkilenmez, authenticated personel artık
-- yalnızca kendi kiracısının kategorilerini görür.
drop policy if exists "public read product_groups" on product_groups;
create policy "public read product_groups" on product_groups
  for select to anon using (true);
