create table if not exists public.squares_names (pool text not null, name_key text not null, name text, owner text not null, created_at timestamptz default now(), primary key (pool, name_key));
alter table public.squares_names enable row level security;
create or replace function public.squares_claim_name(p_pool text, p_name text, p_owner text) returns boolean language plpgsql security definer set search_path = public as $$
declare k text := lower(regexp_replace(trim(p_name), '\s+', ' ', 'g')); o text;
begin
  if k = '' or k = 'debbie' then return false; end if;
  select owner into o from squares_names where pool = upper(trim(p_pool)) and name_key = k;
  if o is null then
    insert into squares_names(pool,name_key,name,owner) values (upper(trim(p_pool)), k, left(trim(p_name),40), p_owner);
    return true;
  end if;
  return o = p_owner;
end $$;
grant execute on function public.squares_claim_name(text,text,text) to anon;
