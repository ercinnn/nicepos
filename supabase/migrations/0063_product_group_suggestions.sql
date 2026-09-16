-- "AI ile Grupla" özelliği: harici bir LLM/API kullanılmıyor — kullanıcının
-- açık isteği üzerine ("kendi makine öğrenmemizi yapalım") tamamen projenin
-- kendi verisiyle çalışan, sunucu tarafında bir k-En Yakın Komşu (k-NN)
-- sınıflandırıcı kuruluyor.
--
-- Yöntem: zaten bir gruba ("etiketli") atanmış ürünlerin adları ile grubu
-- boş ("etiketsiz") ürünlerin adları arasında pg_trgm trigram benzerliği
-- hesaplanır. Her etiketsiz ürün için en benzer p_k adet etiketli ürün
-- bulunur (p_min_similarity eşiği üstünde); bu komşuların group_id'leri
-- arasında benzerlik-ağırlıklı bir "oylama" yapılır ve en çok oy alan grup
-- öneri olarak döner (confidence = kazanan grubun oy payı). Yeterince
-- benzer komşu yoksa hiç satır dönmez — istemci tarafı bunu "sınıflandırılamadı"
-- olarak ele alır. Yöntem HER ZAMAN mevcut bir gruba atar, yeni grup uydurmaz.
--
-- ⚠️ MATERIALIZED KULLANILMAZ (yaşanmış hata — canlıda 3242 etiketsiz ürünle
-- "upstream timeout" verdi): `labeled` CTE'sini MATERIALIZED yapmak, onu
-- ayrı/indekssiz bir geçici sonuç kümesine dönüştürüp `l.name % u.name`
-- join'inin `idx_products_name_trgm` GIN indeksini kullanmasını ENGELLİYOR
-- — planlayıcı bunun yerine tüm etiketsiz × etiketli çiftlerini kaba kuvvetle
-- karşılaştırıyor. Hiçbir CTE burada birden fazla kez referans alınmadığından
-- (CLAUDE.md'deki "büyük tabloya JOIN + window fonksiyonu" durumunun aksine)
-- MATERIALIZED zaten gereksizdi — kaldırılınca planlayıcı `labeled`/`unlabeled`'ı
-- `products` tablosuna geri "inline" edip GIN index nested-loop kullanabiliyor.
--
-- ⚠️ DDL anon key ile çalıştırılamaz — bu dosya Supabase SQL Editor'da elle
-- uygulanmalı. Uygulandıktan sonra supabase/migrations/APPLIED.md güncellenir.

create extension if not exists pg_trgm;

create index if not exists idx_products_name_trgm
  on products using gin (name gin_trgm_ops);

create or replace function suggest_product_groups(
  p_k int default 5,
  p_min_similarity numeric default 0.35
)
returns table(
  product_id uuid,
  product_name text,
  suggested_group_id uuid,
  suggested_group_name text,
  suggested_parent_group_name text,
  confidence numeric,
  match_count int,
  sample_matches text
)
language plpgsql stable security invoker as $$
begin
  -- % operatörünün GIN indeksi kullanması pg_trgm.similarity_threshold'a
  -- bağlı (varsayılan 0.3) — fonksiyon parametresiyle tutarlı olsun diye
  -- burada elle ayarlanıyor. set local: yalnız bu fonksiyon çağrısı için.
  perform set_config('pg_trgm.similarity_threshold', least(p_min_similarity, 0.3)::text, true);

  return query
  with labeled as (
    select p.id, p.name, p.group_id
    from products p
    where p.group_id is not null
  ),
  unlabeled as (
    select p.id, p.name
    from products p
    where p.group_id is null
  ),
  matches as (
    select
      u.id as uid, u.name as uname,
      l.group_id, l.name as matched_name,
      similarity(u.name, l.name) as sim
    from unlabeled u
    join labeled l on l.name % u.name
    where similarity(u.name, l.name) >= p_min_similarity
  ),
  ranked as (
    select *, row_number() over (partition by uid order by sim desc) as rn
    from matches
  ),
  top_k as (
    select * from ranked where rn <= p_k
  ),
  votes as (
    select uid, uname, group_id,
      sum(sim) as vote_weight,
      -- ⚠️ confidence'ı "kazanan grubun rakiplere göre oy payı" olarak
      -- hesaplamak yaşanmış bir hataydı: bir üründe TÜM top-k komşular
      -- (rakip grup olmadığından) aynı gruba aitse oy payı benzerlik
      -- skorundan BAĞIMSIZ hep %100 çıkıyordu (tek 0.35 benzerlikli
      -- eşleşme bile "%100 güven" gösteriyordu, canlı veride görüldü).
      -- confidence bunun yerine bu grubu destekleyen komşuların ORTALAMA
      -- benzerlik skoru — gerçek eşleşme kalitesini yansıtır. vote_weight
      -- yalnızca (rakip grup varsa) hangi grubun kazanacağına karar vermek
      -- için kullanılmaya devam eder.
      avg(sim) as avg_sim,
      count(*) as n,
      -- ⚠️ "sample_matches" DEĞİL: RETURNS TABLE'daki aynı adlı çıktı
      -- sütunu plpgsql içinde örtük bir değişkene dönüşüyor — CTE'de aynı
      -- adı unqualified kullanmak "column reference is ambiguous" hatası
      -- veriyor (yaşanmış hata). İçeride farklı bir isim (matches_txt)
      -- kullanılıp yalnız dış select'te pozisyonel olarak sample_matches
      -- çıktı sütununa eşleniyor.
      string_agg(matched_name || ' (' || round(sim::numeric, 2) || ')', ', ' order by sim desc) as matches_txt
    from top_k
    group by uid, uname, group_id
  ),
  winner as (
    select distinct on (uid)
      uid, uname, group_id, n, matches_txt, avg_sim as conf
    from votes
    order by uid, vote_weight desc
  )
  select
    w.uid, w.uname, w.group_id,
    pg.name, parent_pg.name,
    -- ⚠️ İki tip cast'i yaşanmış hata: similarity() `real` döner
    -- (round(real,int) diye bir overload yok → ::numeric cast şart) ve
    -- count(*) `bigint` döner (match_count `int` ile uyuşmuyor → ::int cast şart).
    round(w.conf::numeric, 3), w.n::int, w.matches_txt
  from winner w
  join product_groups pg on pg.id = w.group_id
  left join product_groups parent_pg on parent_pg.id = pg.parent_group_id
  order by w.conf desc, w.uname;
end;
$$;

grant execute on function suggest_product_groups(int, numeric) to authenticated;

-- Doğrulama (SQL Editor'da migration'dan sonra elle çalıştırılabilir):
--   select count(*) from products where group_id is null;
--   select * from suggest_product_groups(5, 0.35) limit 20;
--   explain analyze select * from suggest_product_groups(5, 0.35);
--     (plan çıktısında "Bitmap Index Scan on idx_products_name_trgm" veya
--      "Index Scan ... idx_products_name_trgm" görülmeli, "Seq Scan" değil
--      — aksi halde performans sorunu var demektir.)
