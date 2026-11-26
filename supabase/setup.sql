-- Debbie's Squares push alerts — run once in Supabase SQL Editor
create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.squares_push_subs (
  endpoint text primary key,
  p256dh text not null,
  auth text not null,
  name text,
  teams jsonb not null,          -- 18 arrays of team abbreviations, one per week
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create table if not exists public.squares_game_state (
  key text primary key,          -- "<week>-<TEAM>" or "hu-<week>"
  state text, score int, updated_at timestamptz default now()
);
alter table public.squares_push_subs enable row level security;
alter table public.squares_game_state enable row level security;
-- no policies: the public app can't read these tables; it only uses the two functions below

create or replace function public.squares_subscribe(p_endpoint text, p_p256dh text, p_auth text, p_teams jsonb, p_name text)
returns void language sql security definer set search_path = public as $$
  insert into squares_push_subs(endpoint,p256dh,auth,teams,name)
  values (p_endpoint,p_p256dh,p_auth,p_teams,left(p_name,40))
  on conflict (endpoint) do update set p256dh=excluded.p256dh, auth=excluded.auth, teams=excluded.teams, name=excluded.name, updated_at=now();
$$;
create or replace function public.squares_unsubscribe(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from squares_push_subs where endpoint = p_endpoint;
$$;
grant execute on function public.squares_subscribe(text,text,text,jsonb,text) to anon;
grant execute on function public.squares_unsubscribe(text) to anon;

-- run the alert checker every minute
select cron.unschedule('squares-alerts') where exists (select 1 from cron.job where jobname='squares-alerts');
select cron.schedule('squares-alerts', '* * * * *', $$
  select net.http_post(
    url := 'https://ksuvjhutalvwgikvsdeu.supabase.co/functions/v1/squares-alerts',
    headers := '{"Content-Type":"application/json","apikey":"sb_publishable_v60aHIwkGcr_a9UvWTb9jA_7qcffk8B"}'::jsonb,
    body := '{}'::jsonb);
$$);
