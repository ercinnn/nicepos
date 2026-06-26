-- 0008: Satış başlığına birebir iskonto saklama (TL tutar + iskonto türü)
--
-- sales tablosu iskontoyu önceden yalnızca yüzde (discount_percent) olarak
-- tutuyordu; TL iskonto yüzdeye çevrilince yuvarlama farkı oluşuyordu.
-- discount_amount: iskontonun kesin TL tutarı.
-- discount_type:  kullanıcının % mi yoksa ₺ mi girdiğini hatırlar (round-trip).
alter table sales
  add column if not exists discount_amount numeric not null default 0,
  add column if not exists discount_type text not null default 'percent'
    check (discount_type in ('percent','tl'));

-- Mevcut satırlardaki yüzde iskontoyu birebir TL tutara çevir (geri doldur).
-- total_amount = net (iskontolu) tutar olduğundan:
--   brüt ara toplam = total_amount / (1 - p/100)
--   iskonto tutarı  = brüt * p/100
-- Yalnızca 0 < discount_percent < 100 olan satırlar için.
update sales
set discount_amount = round(
      (total_amount / (1 - discount_percent / 100.0)) * (discount_percent / 100.0)::numeric,
      2)
where discount_percent > 0 and discount_percent < 100;
