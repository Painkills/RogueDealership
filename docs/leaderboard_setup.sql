-- Rogue Dealership: the shared high-score table.
-- Paste all of this into Supabase -> SQL Editor -> New query, then Run.
--
-- What it allows, for anyone holding the game's public (anon) key:
--   * read every score
--   * add a score: a name, a score, what was banked, and whether they were fired
-- What it does NOT allow: changing or deleting anything, or back-dating a row.
-- Only you, from the Supabase dashboard, can edit or delete rows.

create table public.scores (
  id         bigint generated always as identity primary key,
  name       text        not null check (char_length(btrim(name)) between 1 and 18),
  score      integer     not null check (score between -1000000 and 10000000),
  banked     integer     not null default 0 check (banked between 0 and 100000000),
  fired      boolean     not null default false,
  created_at timestamptz not null default now()
);

create index scores_by_score on public.scores (score desc, created_at asc);

-- Row level security: nothing is allowed unless a policy below says so.
alter table public.scores enable row level security;

create policy "anyone can read scores"
  on public.scores for select
  to anon
  using (true);

create policy "anyone can add a score"
  on public.scores for insert
  to anon
  with check (true);

-- Only these four columns can be written - the id and the timestamp are the
-- database's. No update or delete for the public key at all.
revoke all on public.scores from anon, authenticated;
grant select on public.scores to anon;
grant insert (name, score, banked, fired) on public.scores to anon;

-- A flood guard: refuse new scores once 30 have arrived in the last minute,
-- so a script hammering the table can't bury the real ones.
create or replace function public.scores_flood_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.scores
      where created_at > now() - interval '1 minute') >= 30 then
    raise exception 'too many scores right now, try again in a minute';
  end if;
  return new;
end;
$$;

create trigger scores_flood_guard
  before insert on public.scores
  for each row execute function public.scores_flood_guard();
