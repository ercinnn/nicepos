-- =============================================================================
-- 0059: Ters sıralı ("7.1.26 OKYANUS" gibi tarih-önce-firma-sonra) kalıntıları yakala
-- =============================================================================
-- 0056/0058, firmayı description'ın İLK KELİMESİ olarak arıyordu — ama en
-- az bir üründe sıra tersti ("7.1.26 OKYANUS": tarih önce, firma sonra), bu
-- yüzden yakalanmadı. Bu migration artık POZİSYONDAN BAĞIMSIZ: zaten doğru
-- olmayan (bilinen tam kanonik isimlerden birine eşit OLMAYAN) her ürünün
-- description'ının HERHANGİ BİR yerinde bilinen bir firma adı geçiyorsa
-- (Türkçe-aksan sadeleştirilmiş, en uzun/en spesifik eşleşen kazanır) o
-- firmaya çevirir. Bilinen firma listesi = `companies` tablosu + 0058'deki
-- 16 kayıtsız firma (ÜSTÜN/ŞEN/GÜVEN/HAUSPEC/FMS/DEMİREL/NET/ACEMOĞLU/IRAK/
-- MERSAN/MENBA/ABANT/PROFF/KRD./CANDEĞER/ALKAR).
--
-- ⚠️ Kapsam genişledi (yalnız ilk kelime değil, description'ın HER YERİ)
-- — bu yüzden RETURNING çıktısını dikkatlice gözden geçirin: kısa isimler
-- (NET, FMS, ŞEN gibi 3 harfli) teorik olarak alakasız bir metne rastlayıp
-- yanlış eşleşebilir. Sonucu paylaşırsanız satır satır kontrol ederim.
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

with canonical as (
  select name from companies
  union
  select v.n from (values
    ('ÜSTÜN'), ('ŞEN'), ('GÜVEN'), ('HAUSPEC'), ('FMS'), ('DEMİREL'), ('NET'),
    ('ACEMOĞLU'), ('IRAK'), ('MERSAN'), ('MENBA'), ('ABANT'), ('PROFF'),
    ('KRD.'), ('CANDEĞER'), ('ALKAR')
  ) as v(n)
),
canonical_norm as (
  select
    name,
    lower(translate(name, 'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')) as name_norm
  from canonical
),
products_check as (
  select
    p.id,
    lower(translate(p.description, 'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')) as desc_norm
  from products p
  where p.description is not null
    and p.description <> ''
    and p.description <> '-'
    and p.description not in (select name from canonical)
),
matches as (
  select distinct on (pc.id)
    pc.id as product_id,
    cn.name as company_name
  from products_check pc
  join canonical_norm cn on pc.desc_norm like '%' || cn.name_norm || '%'
  order by pc.id, length(cn.name_norm) desc
)
update products p
set description = m.company_name
from matches m
where p.id = m.product_id
returning p.id, p.name, p.description;
