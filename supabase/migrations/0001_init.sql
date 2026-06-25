-- NicePOS - başlangıç şeması
create extension if not exists pgcrypto;

-- Ürün Grupları
create table product_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  parent_group_id uuid references product_groups(id) on delete set null,
  show_on_sales_page boolean not null default false,
  show_on_price_list boolean not null default false,
  created_at timestamptz not null default now()
);

-- Ürünler
create table products (
  id uuid primary key default gen_random_uuid(),
  barcode text unique,
  name text not null,
  stock_code text,
  group_id uuid references product_groups(id) on delete set null,
  unit text not null default 'Adet',
  origin_country text,
  stock_quantity numeric not null default 0,
  critical_stock numeric not null default 0,
  purchase_price numeric not null default 0,
  purchase_price_vat_included boolean not null default true,
  price1 numeric not null default 0,
  price1_vat_included boolean not null default true,
  price2 numeric not null default 0,
  price2_vat_included boolean not null default true,
  vat_rate numeric not null default 20,
  weight numeric,
  description text,
  image_url text,
  quick_list_order int,
  is_online_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on products (group_id);
create index on products (barcode);

-- Müşteriler
create table customers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  payment_term_days int,
  phone text,
  address text,
  note text,
  credit_limit numeric not null default 0,
  tax_office text,
  tax_number text,
  created_at timestamptz not null default now()
);

-- Satışlar (başlık)
create table sales (
  id uuid primary key default gen_random_uuid(),
  sale_code text unique not null,
  customer_id uuid references customers(id),
  branch text not null default 'ANA HESAP',
  total_amount numeric not null default 0,
  discount_percent numeric not null default 0,
  paid_amount numeric not null default 0,
  payment_type text not null check (payment_type in ('nakit','pos','acik_hesap','parcali')),
  cash_amount numeric not null default 0,
  card_amount numeric not null default 0,
  remaining_debt numeric not null default 0,
  personnel text,
  note text,
  sale_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index on sales (sale_date);
create index on sales (customer_id);

-- Satış Kalemleri
create table sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid references sales(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  quantity numeric not null default 1,
  unit_price numeric not null default 0,
  discount_value numeric not null default 0,
  total numeric not null default 0,
  note text
);
create index on sale_items (sale_id);

-- Müşteri Ödeme/Borç hareketleri (Ödeme Ekle / Borç Ekle)
create table customer_payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id) on delete cascade,
  sale_id uuid references sales(id),
  type text not null check (type in ('odeme','borc')),
  amount numeric not null default 0,
  note text,
  payment_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index on customer_payments (customer_id);

-- Satış kodu üretimi: YYMMDD + günlük sıra + rastgele 2 harf (örn: 2606150007-XB)
create sequence sale_code_seq;

create or replace function generate_sale_code() returns text as $$
declare
  date_part text := to_char(now(), 'YYMMDD');
  seq_part text := lpad((nextval('sale_code_seq') % 10000)::text, 4, '0');
  rand_part text := upper(substr(md5(random()::text), 1, 2));
begin
  return date_part || seq_part || '-' || rand_part;
end;
$$ language plpgsql;
