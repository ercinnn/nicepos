-- =============================================================================
-- 0069: Konsept Ürünler — parça bazında indirim (% veya ₺)
-- =============================================================================
-- Kullanıcı isteği: konsept tanımlarken indirimi hangi parçaya uygulayacağını
-- seçebilmek (A parçasına %10 veya 15 ₺, B parçasına hiç). 0067'de yalnız
-- konsept geneli bir `price` vardı ve fark TÜM parçalara eşit % olarak
-- dağıtılıyordu.
--
--   discount_type  'percent' | 'tl'
--   discount_value % ise yüzde; ₺ ise o parça SATIRININ (konsept içindeki
--                  adetin tamamı) için toplam indirim tutarı.
--
-- Satış fiyatı artık parça satırlarının indirim sonrası toplamıdır. Eski
-- `concept_products.price` sütunu silinmez: hiç parça indirimi olmayan eski
-- bir konsept satışta eski davranışla (fiyat farkı tüm parçalara dağıtılır)
-- çalışmaya devam eder; form üzerinden kaydedildiğinde `price` NULL'a çekilir.
--
-- `save_concept_product` imzası DEĞİŞMİYOR (p_items jsonb), yalnız gövde yeni
-- alanları okur → `create or replace` yeterli, eski istemci de çalışır
-- (alanları göndermezse indirim 0 sayılır).
--
-- Uygulama: Supabase SQL Editor'da çalıştırılır. Idempotenttir.
-- =============================================================================

alter table concept_product_items
  add column if not exists discount_value numeric(12,2) not null default 0,
  add column if not exists discount_type text not null default 'percent';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'concept_product_items_discount_check'
  ) then
    alter table concept_product_items
      add constraint concept_product_items_discount_check
      check (
        discount_value >= 0
        and discount_type in ('percent', 'tl')
        and (discount_type <> 'percent' or discount_value <= 100)
      );
  end if;
end $$;

create or replace function save_concept_product(
  p_id uuid,
  p_barcode text,
  p_name text,
  p_price numeric,
  p_items jsonb
) returns uuid as $$
declare
  v_tenant_id uuid := current_tenant_id();
  v_id uuid;
  v_order int := 0;
  item jsonb;
begin
  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı';
  end if;
  if jsonb_array_length(coalesce(p_items, '[]'::jsonb)) = 0 then
    raise exception 'Konsept en az bir parça içermeli';
  end if;

  if p_id is null then
    insert into concept_products (tenant_id, barcode, name, price)
    values (v_tenant_id, upper(trim(p_barcode)), trim(p_name), p_price)
    returning id into v_id;
  else
    update concept_products
       set barcode = upper(trim(p_barcode)),
           name = trim(p_name),
           price = p_price,
           updated_at = now()
     where id = p_id and tenant_id = v_tenant_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Konsept bulunamadı';
    end if;
    delete from concept_product_items where concept_id = v_id;
  end if;

  for item in select * from jsonb_array_elements(p_items)
  loop
    insert into concept_product_items (
      tenant_id, concept_id, product_id, quantity, sort_order, discount_value, discount_type
    )
    values (
      v_tenant_id, v_id,
      (item->>'product_id')::uuid,
      (item->>'quantity')::numeric,
      v_order,
      coalesce((item->>'discount_value')::numeric, 0),
      coalesce(item->>'discount_type', 'percent')
    );
    v_order := v_order + 1;
  end loop;

  return v_id;
end;
$$ language plpgsql security invoker;
