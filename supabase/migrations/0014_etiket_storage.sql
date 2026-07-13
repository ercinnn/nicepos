-- =============================================================================
-- 0014: Raf etiketi PDF'leri için Storage bucket + RLS (KARAR v1.11)
-- =============================================================================
-- NOT: anon key ile DDL / storage.buckets insert ÇALIŞMAZ → bu dosyayı Supabase
-- panelinde (SQL Editor) uygula. Uygulama yalnız yükleme/listeleme/imzalı URL/
-- silme yapar; program'dan silme = Storage'dan silme (kullanıcı kararı).
-- Idempotent: tekrar çalıştırmak güvenlidir.

-- Private bucket (public = false → yalnız imzalı URL ile erişim).
insert into storage.buckets (id, name, public)
values ('etiket_pdfleri', 'etiket_pdfleri', false)
on conflict (id) do nothing;

-- RLS politikaları — authenticated rolü bu bucket'ta select/insert/delete.
-- (Etiket PDF'i güncellenmez; yeni ad ile yeniden yüklenir → update politikası yok.)

create policy "Authenticated read etiket pdf"
  on storage.objects for select
  using (bucket_id = 'etiket_pdfleri' and auth.role() = 'authenticated');

create policy "Authenticated upload etiket pdf"
  on storage.objects for insert
  with check (bucket_id = 'etiket_pdfleri' and auth.role() = 'authenticated');

create policy "Authenticated delete etiket pdf"
  on storage.objects for delete
  using (bucket_id = 'etiket_pdfleri' and auth.role() = 'authenticated');
