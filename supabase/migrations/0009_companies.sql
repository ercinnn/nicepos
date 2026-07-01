-- NicePOS - Firmalar tablosu
create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz default now()
);
alter table companies enable row level security;
create policy "authenticated full access" on companies
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
