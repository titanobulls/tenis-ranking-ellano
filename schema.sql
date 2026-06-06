-- ============================================================
-- RANKING EL LLANO · Tenis
-- Pegar en Supabase > SQL Editor > Run
-- ============================================================

-- Temporadas semestrales
create table seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,           -- ej: "2026-A", "2026-B"
  label text not null,          -- ej: "Temporada 1 · 2026"
  start_date date not null,
  end_date date not null,
  active boolean default false,
  created_at timestamptz default now()
);

-- Jugadores
create table players (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  initials text not null,       -- 2 letras avatar
  pin_hash text not null default '',  -- PIN hasheado (4 dígitos); vacío hasta aprobación
  whatsapp text,                -- número sin +, ej: 56912345678
  points integer default 1000,  -- puntos acumulados (reset por temporada)
  played integer default 0,
  won integer default 0,
  lost integer default 0,
  streak integer default 0,     -- sábados consecutivos
  total_saturdays integer default 0,
  active boolean default false, -- false = pendiente de aprobación admin
  created_at timestamptz default now()
);

-- Sesiones (cada sábado)
create table sessions (
  id uuid primary key default gen_random_uuid(),
  season_id uuid references seasons(id),
  date date not null unique,
  notes text,
  created_at timestamptz default now()
);

-- Asistencia
create table attendance (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references sessions(id) on delete cascade,
  player_id uuid references players(id) on delete cascade,
  unique(session_id, player_id)
);

-- Partidos
create table matches (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references sessions(id) on delete cascade,
  season_id uuid references seasons(id),
  format text not null,
  -- individual: stb10, tb7, set_normal, set9, d21, americano, rebote
  -- dobles: dobles_stb10, dobles_set, dobles_americano
  is_doubles boolean default false,
  -- individual
  player1_id uuid references players(id),
  player2_id uuid references players(id),
  player3_id uuid references players(id),  -- d21 / americano
  player4_id uuid references players(id),  -- d21 / americano
  -- dobles
  team1_p1 uuid references players(id),
  team1_p2 uuid references players(id),
  team2_p1 uuid references players(id),
  team2_p2 uuid references players(id),
  -- scores
  score1 integer,
  score2 integer,
  score3 integer,
  score4 integer,
  winner_team integer,   -- 1 o 2 (dobles) o null (individual → usar winner_id)
  winner_id uuid references players(id),  -- individual
  pts_awarded jsonb,     -- { "player_id": pts }
  -- confirmación
  status text default 'pending' check (status in ('pending','confirmed','disputed')),
  submitted_by uuid references players(id),
  confirmed_by uuid references players(id),
  created_at timestamptz default now()
);

-- Índices
create index on matches(session_id);
create index on matches(season_id);
create index on matches(status);
create index on matches(player1_id);
create index on matches(player2_id);

-- RLS: lectura pública, escritura autenticada por PIN en la app
alter table players enable row level security;
alter table seasons enable row level security;
alter table sessions enable row level security;
alter table attendance enable row level security;
alter table matches enable row level security;

create policy "public read" on players    for select using (true);
create policy "public read" on seasons    for select using (true);
create policy "public read" on sessions   for select using (true);
create policy "public read" on attendance for select using (true);
create policy "public read" on matches    for select using (true);

create policy "anon insert players"    on players    for insert with check (true);
create policy "anon update players"    on players    for update using (true);
create policy "anon insert sessions"   on sessions   for insert with check (true);
create policy "anon insert attendance" on attendance for insert with check (true);
create policy "anon insert matches"    on matches    for insert with check (true);
create policy "anon update matches"    on matches    for update using (true);
create policy "anon insert seasons"    on seasons    for insert with check (true);
create policy "anon update seasons"    on seasons    for update using (true);

-- Temporada inicial
insert into seasons (name, label, start_date, end_date, active)
values ('2026-A', 'Temporada 1 · 2026', '2026-01-01', '2026-06-30', true);
