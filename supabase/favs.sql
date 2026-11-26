alter table public.squares_push_subs add column if not exists favs jsonb;
drop function if exists public.squares_subscribe(text,text,text,jsonb,text,jsonb);
create or replace function public.squares_subscribe(p_endpoint text, p_p256dh text, p_auth text, p_teams jsonb, p_name text, p_tv jsonb default null, p_favs jsonb default null) returns void language sql security definer set search_path = public as $$
  insert into squares_push_subs(endpoint,p256dh,auth,teams,name,tv,favs) values (p_endpoint,p_p256dh,p_auth,p_teams,left(p_name,40),p_tv,p_favs)
  on conflict (endpoint) do update set p256dh=excluded.p256dh, auth=excluded.auth, teams=excluded.teams, name=excluded.name, tv=excluded.tv, favs=excluded.favs, updated_at=now();
$$;
grant execute on function public.squares_subscribe(text,text,text,jsonb,text,jsonb,jsonb) to anon;
