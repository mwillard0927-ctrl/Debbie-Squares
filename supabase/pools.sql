create extension if not exists pgcrypto with schema extensions;
create table if not exists public.squares_pools (code text primary key, pin_hash text, created_at timestamptz default now());
alter table public.squares_pools enable row level security;
insert into public.squares_pools(code,pin_hash) values ('DEBBIE', encode(extensions.digest('YOUR-PIN-HERE','sha256'),'hex'))
  on conflict (code) do update set pin_hash = excluded.pin_hash;
create table if not exists public.squares_pool_weekly (pool text not null, week int not null check (week between 1 and 18), high int, low int, updated_by text, updated_at timestamptz default now(), primary key (pool, week));
alter table public.squares_pool_weekly enable row level security;
drop policy if exists "read pool weekly" on public.squares_pool_weekly;
create policy "read pool weekly" on public.squares_pool_weekly for select to anon using (true);
grant select on public.squares_pool_weekly to anon;
insert into public.squares_pool_weekly(pool,week,high,low,updated_by) select 'DEBBIE',week,high,low,updated_by from public.squares_weekly on conflict do nothing;
create table if not exists public.squares_members (id text primary key, pool text not null, name text, teams jsonb, updated_at timestamptz default now());
alter table public.squares_members enable row level security;
drop function if exists public.squares_set_week(int,int,int,text);
create or replace function public.squares_pool_info(p_code text) returns json language sql security definer set search_path = public as $$
  select json_build_object('exists', count(*) > 0, 'locked', coalesce(bool_or(pin_hash is not null), false)) from squares_pools where code = upper(trim(p_code));
$$;
create or replace function public.squares_create_pool(p_code text, p_pin text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from squares_pools where code = upper(trim(p_code))) then return false; end if;
  insert into squares_pools(code,pin_hash) values (upper(trim(p_code)), case when coalesce(p_pin,'') = '' then null else encode(extensions.digest(p_pin,'sha256'),'hex') end);
  return true;
end $$;
create or replace function public.squares_check_pin(p_code text, p_pin text) returns boolean language sql security definer set search_path = public as $$
  select coalesce((select pin_hash is null or pin_hash = encode(extensions.digest(coalesce(p_pin,''),'sha256'),'hex') from squares_pools where code = upper(trim(p_code))), true);
$$;
create or replace function public.squares_set_week2(p_pool text, p_week int, p_high int, p_low int, p_by text, p_pin text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not squares_check_pin(p_pool, p_pin) then return false; end if;
  insert into squares_pool_weekly(pool,week,high,low,updated_by) values (upper(trim(p_pool)),p_week,p_high,p_low,left(p_by,40))
  on conflict (pool,week) do update set high=excluded.high, low=excluded.low, updated_by=excluded.updated_by, updated_at=now();
  return true;
end $$;
create or replace function public.squares_join(p_id text, p_pool text, p_name text, p_teams jsonb) returns void language sql security definer set search_path = public as $$
  insert into squares_members(id,pool,name,teams) values (p_id, upper(trim(p_pool)), left(p_name,40), p_teams)
  on conflict (id) do update set pool=excluded.pool, name=excluded.name, teams=excluded.teams, updated_at=now();
$$;
create or replace function public.squares_pool_members(p_pool text) returns table(name text, teams jsonb, updated_at timestamptz) language sql security definer set search_path = public as $$
  select name, teams, updated_at from squares_members where pool = upper(trim(p_pool)) and updated_at > now() - interval '60 days';
$$;
grant execute on function public.squares_pool_info(text) to anon;
grant execute on function public.squares_create_pool(text,text) to anon;
grant execute on function public.squares_check_pin(text,text) to anon;
grant execute on function public.squares_set_week2(text,int,int,int,text,text) to anon;
grant execute on function public.squares_join(text,text,text,jsonb) to anon;
grant execute on function public.squares_pool_members(text) to anon;
