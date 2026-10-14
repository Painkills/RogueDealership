-- Rogue Dealership: the play metrics table (see game/scripts/view/telemetry.gd).
-- Paste all of this into Supabase -> SQL Editor -> New query, then Run.
--
-- What it allows, for anyone holding the game's public (anon) key:
--   * add events - batches of them, each no bigger than a few KB
-- What it does NOT allow: reading anything back, changing or deleting anything.
-- Reading is for you: the dashboard, or tools/telemetry_report.py with the
-- service_role key (Settings -> API), which never goes in the game or the repo.
--
-- Anonymous by design: `install` and `session` are random ids the game makes up;
-- no name, email or anything typed is ever sent.

create table public.events (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  install    text    not null check (char_length(install) between 1 and 64),
  session    text    not null check (char_length(session) <= 64),
  run        text             check (run is null or char_length(run) <= 64),
  build      text    not null default '' check (char_length(build) <= 64),
  seq        integer not null check (seq >= 0),
  t_ms       bigint  not null check (t_ms >= 0),
  think_ms   integer          check (think_ms is null or think_ms >= 0),
  kind       text    not null check (char_length(kind) between 1 and 40),
  data       jsonb   not null default '{}'::jsonb check (pg_column_size(data) <= 16000)
);

create index events_by_time on public.events (created_at);
create index events_by_session on public.events (session, seq);
create index events_by_kind on public.events (kind, created_at);

-- Row level security: nothing is allowed unless a policy below says so.
alter table public.events enable row level security;

create policy "anyone can add an event"
  on public.events for insert
  to anon
  with check (true);

-- Only these columns can be written - the id and the timestamp are the
-- database's. No select, update or delete for the public key at all.
revoke all on public.events from anon, authenticated;
grant insert (install, session, run, build, seq, t_ms, think_ms, kind, data)
  on public.events to anon;

-- A flood guard: refuse new events once 5000 have arrived in the last minute,
-- so a script hammering the table can't fill it.
create or replace function public.events_flood_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.events
      where created_at > now() - interval '1 minute') >= 5000 then
    raise exception 'too many events right now, try again in a minute';
  end if;
  return new;
end;
$$;

create trigger events_flood_guard
  before insert on public.events
  for each row execute function public.events_flood_guard();

-- Quick looks from the dashboard (Table editor -> views).

-- Refused moves, most common first: where the rules said no.
create or replace view public.events_refusals as
  select data->>'refused' as refusal, data->>'cmd' as move,
         count(*) as times, count(distinct install) as players
  from public.events
  where kind = 'action' and (data->>'ok')::boolean = false
  group by 1, 2
  order by times desc;

-- How long each kind of move takes to decide.
create or replace view public.events_think_time as
  select data->>'cmd' as move, count(*) as moves,
         percentile_cont(0.5) within group (order by think_ms) as median_ms,
         percentile_cont(0.9) within group (order by think_ms) as p90_ms
  from public.events
  where kind = 'action' and think_ms is not null
  group by 1
  order by median_ms desc;

-- Shifts by how they went.
create or replace view public.events_shifts as
  select data->>'profile' as shift, count(*) as worked,
         avg(((data->>'made_quota')::boolean)::int) as made_quota,
         avg((data->>'customers_walked')::numeric) as walkouts
  from public.events
  where kind = 'shift_end'
  group by 1
  order by worked desc;

-- The views are yours alone, like the table.
revoke all on public.events_refusals, public.events_think_time, public.events_shifts
  from anon, authenticated;
