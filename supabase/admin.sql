create table if not exists public.squares_pin_attempts (code text primary key, fails int default 0, locked_until timestamptz);
alter table public.squares_pin_attempts enable row level security;
create or replace function public.squares_check_pin(p_code text, p_pin text) returns boolean language plpgsql security definer set search_path = public as $$
declare h text; a record; f int; c text := upper(trim(p_code));
begin
  select pin_hash into h from squares_pools where code = c;
  if not found or h is null then return true; end if;
  select * into a from squares_pin_attempts where code = c;
  if found and a.locked_until is not null and a.locked_until > now() then return false; end if;
  if h = encode(extensions.digest(coalesce(p_pin,''),'sha256'),'hex') then delete from squares_pin_attempts where code = c; return true; end if;
  f := case when found and a.locked_until is null then coalesce(a.fails,0) + 1 else 1 end;
  insert into squares_pin_attempts(code,fails,locked_until) values (c, case when f >= 5 then 0 else f end, case when f >= 5 then now() + interval '15 minutes' else null end)
    on conflict (code) do update set fails = excluded.fails, locked_until = excluded.locked_until;
  return false;
end $$;
create or replace function public.squares_pin_wait(p_code text) returns int language sql security definer set search_path = public as $$
  select coalesce((select greatest(0, ceil(extract(epoch from locked_until - now())))::int from squares_pin_attempts where code = upper(trim(p_code)) and locked_until > now()), 0);
$$;
create or replace function public.squares_remove_member(p_pool text, p_pin text, p_name text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not squares_check_pin(p_pool, p_pin) then return false; end if;
  delete from squares_members where pool = upper(trim(p_pool)) and name = p_name;
  return true;
end $$;
create or replace function public.squares_change_pin(p_pool text, p_old text, p_new text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if length(coalesce(p_new,'')) < 4 or not squares_check_pin(p_pool, p_old) then return false; end if;
  update squares_pools set pin_hash = encode(extensions.digest(p_new,'sha256'),'hex') where code = upper(trim(p_pool));
  return true;
end $$;
grant execute on function public.squares_pin_wait(text) to anon;
grant execute on function public.squares_remove_member(text,text,text) to anon;
grant execute on function public.squares_change_pin(text,text,text) to anon;
