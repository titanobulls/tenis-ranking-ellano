-- ============================================================
-- MIGRACIÓN: Activar Temporada 2 · 2026
-- Ejecutar en Supabase > SQL Editor > Run
-- ============================================================

-- 1. Cerrar Temporada 1
update seasons
set active = false
where name = '2026-A';

-- 2. Crear e iniciar Temporada 2 (solo si no existe)
insert into seasons (name, label, start_date, end_date, active)
select '2026-B', 'Temporada 2 · 2026', '2026-07-01', '2026-12-31', true
where not exists (select 1 from seasons where name = '2026-B');

-- Si ya existía, solo activarla
update seasons
set active = true,
    label  = 'Temporada 2 · 2026'
where name = '2026-B';

select name, label, active from seasons order by start_date;
