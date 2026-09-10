-- =============================================================================
-- 0058: Firmalar sekmesinde KAYITLI OLMAYAN 16 firma grubunu normalize et
-- =============================================================================
-- 0056'nın `companies` tablosuna dayalı otomatik eşleştirmesi bu 16 grubu
-- BİLEREK atlamıştı (kayıtları yok). Kullanıcı yine de düzeltilmesini istedi
-- — diğer TÜM kayıtlı firmaların (OKYANUS, ENDER, GÜNDÜZ, DERYA, ...) büyük
-- harf + Türkçe karakterli yazıldığı kurala uyularak aynı üslupla normalize
-- edilir. Bu firmalar `companies` tablosuna KAYITLI DEĞİL — ileride Ürünler →
-- Firmalar sekmesinden eklenirse tıkla-düzenle autocomplete'i de kullanabilir.
--
-- Eşleştirme, description'ın ilk kelimesini Türkçe-aksan-sadeleştirip
-- (0056'daki translate() ile aynı desen) aşağıdaki eşleme tablosuyla TAM
-- (exact) eşleştirir — 0056'nın aksine burada PREFIX eşleşme KULLANILMAZ:
-- bu 16 grupta diagnostic sorguda hiç bitişik-tarihli bozuk varyant
-- görülmedi (hepsi temiz tek-kelime), ve "net"/"fms"/"irak" gibi kısa
-- isimlerde prefix eşleşme yanlışlıkla alakasız/farklı bir firmayı (ör.
-- "NETWORK...") yutabilirdi — tam eşleşme bu riski tamamen ortadan kaldırır.
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

with mapping (firma_key, firma_target) as (
  values
    ('ustun',    'ÜSTÜN'),
    ('sen',      'ŞEN'),
    ('guven',    'GÜVEN'),
    ('hauspec',  'HAUSPEC'),
    ('fms',      'FMS'),
    ('demirel',  'DEMİREL'),
    ('net',      'NET'),
    ('acemoglu', 'ACEMOĞLU'),
    ('irak',     'IRAK'),
    ('mersan',   'MERSAN'),
    ('menba',    'MENBA'),
    ('abant',    'ABANT'),
    ('proff',    'PROFF'),
    ('krd.',     'KRD.'),
    ('candeger', 'CANDEĞER'),
    ('alkar',    'ALKAR')
),
products_norm as (
  select
    p.id,
    lower(translate(split_part(p.description, ' ', 1), 'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')) as firma_norm
  from products p
  where p.description is not null and p.description <> '' and p.description <> '-'
),
matches as (
  select distinct on (pn.id)
    pn.id as product_id,
    m.firma_target
  from products_norm pn
  join mapping m on pn.firma_norm = m.firma_key
  order by pn.id, length(m.firma_key) desc
)
update products p
set description = mt.firma_target
from matches mt
where p.id = mt.product_id
  and p.description is distinct from mt.firma_target
returning p.id, p.name, p.description;
