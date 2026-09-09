-- NicePOS - Etiket Havuzu: kullanıcılar/cihazlar arası paylaşılan bekleyen
-- etiket kuyruğu (Raf/Tel/Geniş/Ürün Etiketi). Mobil ürün formundaki "Etiket"
-- butonu buraya ekler; Etiket sayfasındaki "Havuz" sekmesi tür bazlı biriken
-- toplamı gösterir, "PDF Kaydet" o an kontrol=0 olan tüm kalemleri TEK pdf'te
-- üretip kontrol=1 işaretler (silinmez — geçmiş kayıt olarak kalır, yeni
-- eklemeler kontrol=0 ile devam eder).
--
-- Tek paylaşılan Supabase Auth hesabı senaryosu (kullanıcı doğruladı) —
-- 0002_rls.sql'deki blanket "authenticated full access" deseni yeterli,
-- kullanıcı bazlı izolasyon gerekmez.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create table label_pool_items (
  id uuid primary key default gen_random_uuid(),
  label_type text not null check (label_type in ('raf', 'tel', 'genis', 'urun')),
  barcode text not null,
  product_name text not null,
  price numeric,              -- 'urun' tipinde NULL (fiyatsız etiket)
  quantity integer not null check (quantity > 0),
  kontrol integer not null default 0,  -- 0 = bekliyor, 1 = PDF'e alındı
  created_at timestamptz not null default now()
);

create index label_pool_items_pending_idx on label_pool_items (label_type, kontrol, created_at);

alter table label_pool_items enable row level security;

create policy "authenticated full access" on label_pool_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
