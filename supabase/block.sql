create table if not exists public.squares_blocked (pool text not null, name text not null, primary key (pool, name));
alter table public.squares_blocked enable row level security;
create or replace function public.squares_remove_member(p_pool text, p_pin text, p_name text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not squares_check_pin(p_pool, p_pin) then return false; end if;
  delete from squares_members where pool = upper(trim(p_pool)) and name = p_name;
  insert into squares_blocked(pool,name) values (upper(trim(p_pool)), p_name) on conflict do nothing;
  return true;
end $$;
create or replace function public.squares_join(p_id text, p_pool text, p_name text, p_teams jsonb) returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from squares_blocked where pool = upper(trim(p_pool)) and name = left(p_name,40)) then
    delete from squares_members where id = p_id; return;
  end if;
  insert into squares_members(id,pool,name,teams) values (p_id, upper(trim(p_pool)), left(p_name,40), p_teams)
  on conflict (id) do update set pool=excluded.pool, name=excluded.name, teams=excluded.teams, updated_at=now();
end $$;
create or replace function public.squares_blocked_list(p_pool text, p_pin text) returns setof text language plpgsql security definer set search_path = public as $$
begin
  if not squares_check_pin(p_pool, p_pin) then return; end if;
  return query select name from squares_blocked where pool = upper(trim(p_pool)) order by name;
end $$;
create or replace function public.squares_unblock(p_pool text, p_pin text, p_name text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not squares_check_pin(p_pool, p_pin) then return false; end if;
  delete from squares_blocked where pool = upper(trim(p_pool)) and name = p_name;
  return true;
end $$;
grant execute on function public.squares_blocked_list(text,text) to anon;
grant execute on function public.squares_unblock(text,text,text) to anon;
