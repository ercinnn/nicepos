-- NicePOS - Görevler (raf kontrolü) tamamlanma kayıtları: dün satılan bir
-- ürünün rafı kontrol edilip tamamlandı işaretlendiğinde buraya bir satır
-- eklenir. Cihazlar arası paylaşılan tabloda tutulur ki aynı (paylaşılan)
-- kullanıcı başka bir cihazdan girdiğinde tamamlanan görevleri görebilsin
-- (önceki yerel/SharedPreferences tabanlı sürümün yerini alır).
--
-- gorev_tarihi = görev listesinin ait olduğu gün (görevin göründüğü gün,
-- dünün satışlarının hangi "bugün"e ait raf kontrolü olduğunu belirler) —
-- istemci yerel tarihini ('YYYY-MM-DD') gönderir, gün değişince otomatik
-- yeni bir liste başlar (eski kayıtlar silinmez, geçmiş log olarak kalır).
--
-- Tek paylaşılan Supabase Auth hesabı senaryosu (0002_rls.sql'deki blanket
-- "authenticated full access" deseni yeterli, kullanıcı bazlı izolasyon
-- gerekmez — bkz. label_pool_items/0032 ile aynı desen).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create table gorev_tamamlamalar (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  gorev_tarihi date not null,
  completed_at timestamptz not null default now(),
  unique (product_id, gorev_tarihi)
);

create index gorev_tamamlamalar_tarih_idx on gorev_tamamlamalar (gorev_tarihi);

alter table gorev_tamamlamalar enable row level security;

create policy "authenticated full access" on gorev_tamamlamalar
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
