-- =============================================================================
-- 0067: Konsept Ürünler — birden çok parçadan oluşan ürünlere tek barkod
-- =============================================================================
-- Örnek: "C261002001" konsepti = 1× vazo (10001) + 2× papatya (20002) +
-- 5× okaliptus (20003). Satış ekranında konsept barkodu okutulunca parçalar
-- sepete AYRI satırlar olarak eklenir — stok düşümü, raporlar, offline satış
-- kuyruğu ve satış düzenleme mevcut `complete_sale` akışıyla hiç değişmeden
-- çalışır (bu yüzden RPC'lere DOKUNULMAZ).
--
-- Konseptin KENDİ stoku YOKTUR (kullanıcı kararı) — `products` tablosuna
-- girmez, Ürünler listesinde görünmez; yalnız "Konsept Ürünler" sekmesinde
-- listelenir.
--
-- Barkod biçimi: C + YY + AA + GG + sıra(3) → "C261002001". İstemci üretir
-- (`ConceptRepository.fetchBarcodesWithPrefix` + `nextBarcodeCandidate`),
-- benzersizlik `(tenant_id, barcode)` unique kısıtıyla DB'de garanti edilir.
--
-- `price` NULL ise satış fiyatı = parçaların Fiyat1 toplamı; doluysa fark
-- satışta parçalara oransal (%) iskonto olarak dağıtılır (istemci tarafı).
--
-- RLS: 0039'daki "tenant scoped access" deseni (tam CRUD, kiracıya kısıtlı).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (if not exists / drop-then-create policy).
-- =============================================================================

create table if not exists concept_products (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  barcode     text not null,
  name        text not null,
  price       numeric(12,2) check (price is null or price >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint concept_products_tenant_barcode_key unique (tenant_id, barcode)
);

create index if not exists idx_concept_products_tenant_id on concept_products (tenant_id);

create table if not exists concept_product_items (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  concept_id  uuid not null references concept_products(id) on delete cascade,
  -- Parça ürün silinirse konseptten de düşer (konsept sayfası eksik parçayı
  -- göstermez; kullanıcı konsepti gözden geçirmeli).
  product_id  uuid not null references products(id) on delete cascade,
  quantity    numeric(12,3) not null check (quantity > 0),
  sort_order  int not null default 0,
  constraint concept_product_items_concept_product_key unique (concept_id, product_id)
);

create index if not exists idx_concept_product_items_concept on concept_product_items (concept_id);
create index if not exists idx_concept_product_items_product on concept_product_items (product_id);
create index if not exists idx_concept_product_items_tenant_id on concept_product_items (tenant_id);

alter table concept_products enable row level security;
alter table concept_product_items enable row level security;

drop policy if exists "tenant scoped access" on concept_products;
create policy "tenant scoped access" on concept_products
  for all using (tenant_id = current_tenant_id())
  with check (tenant_id = current_tenant_id());

drop policy if exists "tenant scoped access" on concept_product_items;
create policy "tenant scoped access" on concept_product_items
  for all using (tenant_id = current_tenant_id())
  with check (tenant_id = current_tenant_id());

-- -----------------------------------------------------------------------------
-- Kaydetme tek atomik RPC ile: konsept satırı + parça listesi aynı transaction'da
-- yazılır (parçalar silinip yeniden eklenir). İstemcide iki ayrı insert'e
-- bölünseydi bağlantı arada koparsa parçasız "yarım" konsept kalabilirdi.
-- p_id NULL → yeni konsept; dolu → güncelleme. Dönüş: konseptin id'si.
-- p_items: [{"product_id": "...", "quantity": 2}, ...]
-- -----------------------------------------------------------------------------
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
    insert into concept_product_items (tenant_id, concept_id, product_id, quantity, sort_order)
    values (v_tenant_id, v_id, (item->>'product_id')::uuid, (item->>'quantity')::numeric, v_order);
    v_order := v_order + 1;
  end loop;

  return v_id;
end;
$$ language plpgsql security invoker;

grant execute on function save_concept_product(uuid, text, text, numeric, jsonb) to authenticated;
