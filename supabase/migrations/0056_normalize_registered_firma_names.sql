-- =============================================================================
-- 0056: description firma adlarını `companies` tablosundaki kayıtlı adlara göre normalize et
-- =============================================================================
-- Kullanıcının diagnostic sorgusu 50+ farklı yazım-varyantlı firma grubu
-- buldu (okyanus/Okyanus/OKYANUS, izpa/İzpa, mien/Mien, vb.) DURA/CHEFINOX/
-- GÜNDÜZ gibi her biri için ayrı SQL yazmak yerine bu migration TEK sorguda
-- `companies` tablosunu (Ürünler → Firmalar sekmesi) referans alıp eşleşen
-- HER ürünün description'ını kayıtlı firma adına çevirir.
--
-- Eşleştirme mantığı:
--   1. Türkçe karakterler sadeleştirilir (ç/ğ/ı/İ/ö/ş/ü → ASCII) ve küçük
--      harfe çevrilir — "İzpa"/"izpa"/"İZPA" hepsi aynı köke iner (diagnostic
--      sorgu bunları case-insensitive ~* ile bile AYRI grup göstermişti,
--      çünkü İ/ı harfleri plain i/I'dan FARKLI karakterdir, yalnız büyük/
--      küçük harf dönüşümü bunu birleştirmez — translate() gerekir).
--   2. description'ın ilk kelimesi (firma her zaman baştadır) bu sadeleşmiş
--      köke göre companies.name ile HER İKİ yönde "başlangıç" eşleşmesi
--      aranır: firma kökü company adının başlangıcıysa (ör. "gnd" →
--      "GNDGIFT", "hobby" → "HOBBYLIFE", "şah" → "ŞAH İTHALAT", "duru" →
--      "DURU AHŞAP") YA DA tersi (ör. bozuk "pala05.06.2026" → "PALA",
--      "mien-20.11.2024" → "MİEN").
--   3. Birden fazla firma eşleşirse (olmamalı, ama güvenlik için) EN UZUN
--      (en spesifik) eşleşen kazanır (`distinct on ... order by length desc`).
--   4. Zaten doğru olan kayıtlar (`is distinct from`) tekrar yazılmaz —
--      RETURNING yalnız GERÇEKTEN değişen satırları gösterir.
--
-- ⚠️ companies tablosunda "CHEFİNOX" ile YANINDA ayrıca "CHEFFİNOX" (çift F,
-- muhtemelen yazım hatası/duplike kayıt) da kayıtlı — bu migration ikisine
-- de DOKUNMAZ (aralarında prefix ilişkisi yok, çakışma riski yok), ama bu
-- muhtemel duplike company kaydını ayrıca gözden geçirmeniz iyi olur.
--
-- ⚠️ KAYITLI OLMAYAN firma grupları (diagnostic sorguda bulunan ama
-- `companies` tablosunda KARŞILIĞI OLMAYAN) bilerek dokunulmadan bırakıldı:
-- üstün(163), şen(128), güven+guven(51), hauspec(35), fms(33), mersan(11),
-- krd.(3), candeğer(2), alkar(2), abant(6), menba(7), irak(12), net(17),
-- acemoğlu(14). Bunlar için önce companies tablosuna kayıt açılmalı veya
-- doğru yazımın ne olacağı netleşmeli.
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

with companies_norm as (
  select
    id,
    name,
    lower(translate(name, 'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')) as name_norm
  from companies
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
    cn.name as company_name
  from products_norm pn
  join companies_norm cn
    on pn.firma_norm like cn.name_norm || '%'
    or cn.name_norm like pn.firma_norm || '%'
  order by pn.id, length(cn.name_norm) desc
)
update products p
set description = m.company_name
from matches m
where p.id = m.product_id
  and p.description is distinct from m.company_name
returning p.id, p.name, p.description;

-- 0kyanus/0KYANUS (4 ürün) — rakam "0" ile harf "O" karışıklığı, translate()
-- bunu ele almaz (Türkçe aksan değil, ayrı bir yazım hatası) → ayrı düzeltme:
update products
set description = 'OKYANUS'
where description ~* '^0kyanus'
returning id, name, description;
