create table if not exists public.squares_favs (id text primary key, pool text not null, name text not null, favs jsonb not null default '[]', share boolean not null default true, updated_at timestamptz default now());
alter table public.squares_favs enable row level security;
create or replace function public.squares_set_favs(p_id text, p_pool text, p_name text, p_favs jsonb, p_share boolean) returns void language sql security definer set search_path = public as $$
  insert into squares_favs(id,pool,name,favs,share) values (p_id, upper(trim(p_pool)), left(p_name,40), coalesce(p_favs,'[]'), coalesce(p_share,true))
  on conflict (id) do update set pool=excluded.pool, name=excluded.name, favs=excluded.favs, share=excluded.share, updated_at=now();
$$;
create or replace function public.squares_social(p_pool text, p_name text) returns json language sql security definer set search_path = public as $$
  with P as (select upper(trim(p_pool)) c),
  me as (select favs from squares_favs, P where pool = P.c and name = p_name and share order by updated_at desc limit 1),
  myf as (select jsonb_array_elements_text(favs) f from me),
  others as (select distinct on (name) name, favs from squares_favs, P where pool = P.c and share and name <> p_name order by name, updated_at desc),
  blk as (select name from squares_blocked, P where pool = P.c),
  mutual as (select o.name from others o where o.name in (select f from myf) and o.favs ? p_name),
  sugg as (select x.n as name, array_agg(o.name order by o.name) as via from others o cross join lateral jsonb_array_elements_text(o.favs) x(n)
           where o.name in (select f from myf) and x.n <> p_name and x.n not in (select f from myf) and x.n not in (select name from blk) group by x.n)
  select json_build_object('mutual', (select coalesce(json_agg(name order by name), '[]'::json) from mutual),
                           'suggest', (select coalesce(json_agg(json_build_object('name', name, 'via', via) order by cardinality(via) desc, name), '[]'::json) from sugg));
$$;
grant execute on function public.squares_set_favs(text,text,text,jsonb,boolean) to anon;
grant execute on function public.squares_social(text,text) to anon;
