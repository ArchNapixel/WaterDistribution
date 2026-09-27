-- Run this once in Supabase Dashboard -> SQL Editor.

create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_number text,
  address text,
  barangay text,
  latitude double precision,
  longitude double precision,
  meter_number text,
  connection_date date not null default current_date,
  status text not null default 'active' check (status in ('active', 'inactive')),
  boundary jsonb, -- list of [lat, lng] pairs tracing the property outline
  created_at timestamptz not null default now()
);

create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  period text not null, -- e.g. '2026-09'
  amount numeric not null default 1000,
  due_date date not null,
  status text not null default 'unpaid' check (status in ('unpaid', 'paid')),
  paid_date date,
  created_at timestamptz not null default now(),
  unique (client_id, period)
);

alter table clients enable row level security;
alter table invoices enable row level security;

-- Single-owner app: any authenticated user (you, logged in from any device)
-- can read/write everything. Add per-user scoping later only if you ever
-- add more than one login.
create policy "authenticated full access" on clients
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on invoices
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
