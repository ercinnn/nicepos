-- =============================================================================
-- 0060: 0058'de düzeltilen ama Firmalar sekmesinde kayıtlı OLMAYAN 16 firmayı ekle
-- =============================================================================
-- `companies.tenant_id` NOT NULL + `default current_tenant_id()` — ancak
-- SQL Editor postgres rolüyle çalıştığından `auth.uid()` boş döner ve
-- `current_tenant_id()` NULL verir; bu yüzden tenant_id'yi mevcut bir
-- companies satırından ALINTI olarak açıkça belirtiyoruz (işletmenin
-- gerçek kiracı id'si neyse onu kullanır, hardcoded seed-tenant varsayımı
-- YAPILMAZ).
--
-- `where not exists` ile aynı isim (case-insensitive) zaten kayıtlıysa
-- tekrar eklenmez — idempotent.
--
-- Uygulama: anon key ile INSERT de RLS'ye takılır → Supabase SQL Editor'da
-- elle çalıştırılmalı.

with target_tenant as (
  select tenant_id from companies limit 1
),
new_names (name) as (
  values
    ('ÜSTÜN'), ('ŞEN'), ('GÜVEN'), ('HAUSPEC'), ('FMS'), ('DEMİREL'), ('NET'),
    ('ACEMOĞLU'), ('IRAK'), ('MERSAN'), ('MENBA'), ('ABANT'), ('PROFF'),
    ('KRD.'), ('CANDEĞER'), ('ALKAR')
)
insert into companies (name, tenant_id)
select n.name, t.tenant_id
from new_names n
cross join target_tenant t
where not exists (
  select 1 from companies c where lower(c.name) = lower(n.name)
)
returning id, name, tenant_id;
