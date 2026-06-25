-- NicePOS - Row Level Security
-- Tek mağaza / tek kullanıcı senaryosu: giriş yapmış (authenticated) her kullanıcı
-- tüm tablolarda tam CRUD erişimine sahiptir. Giriş yapmamış kullanıcılar erişemez.

alter table product_groups enable row level security;
alter table products enable row level security;
alter table customers enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table customer_payments enable row level security;

create policy "authenticated full access" on product_groups
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on products
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on customers
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on sales
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on sale_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on customer_payments
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
