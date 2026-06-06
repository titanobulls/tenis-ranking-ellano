-- ============================================================
-- MIGRACIÓN: Función para que jugadores editen su perfil
-- Ejecutar en Supabase > SQL Editor > Run
-- ============================================================

create or replace function update_player_profile(
  p_id       uuid,
  p_name     text,
  p_initials text,
  p_pin_hash text
)
returns boolean
language plpgsql
security definer
as $$
begin
  if not exists (
    select 1 from players
    where id = p_id
      and pin_hash = p_pin_hash
      and active = true
  ) then
    return false;
  end if;

  update players
  set name     = trim(p_name),
      initials = upper(trim(p_initials))
  where id = p_id and active = true;

  return found;
end;
$$;

grant execute on function update_player_profile(uuid, text, text, text) to anon;

select 'Función update_player_profile creada correctamente' as status;
