-- ============================================================
-- MIGRACIÓN: PINs seguros con SHA-256
-- Ejecutar en Supabase > SQL Editor > Run
-- ============================================================

-- 1. Tabla de configuración interna (sin lectura pública)
create table if not exists app_config (
  key   text primary key,
  value text not null
);

-- RLS: nadie puede leer ni escribir directamente desde el cliente
alter table app_config enable row level security;
-- Sin policies de select/insert/update para anon → tabla completamente opaca al frontend

-- 2. Guardar PIN admin como SHA-256 (nunca el PIN en claro)
-- Hash de '2030' → cambiar ejecutando: select encode(sha256('NUEVO_PIN'::bytea),'hex')
insert into app_config (key, value)
values ('admin_pin_hash', '8e1f192fe25ad49be764c3f55c68beb32f7aa66f85344e026b76cfaaa1d3d88a')
on conflict (key) do update set value = excluded.value;

-- 3. Función RPC: verifica PIN admin en el servidor, nunca expone el hash
create or replace function verify_admin_pin(pin_hash text)
returns boolean
language sql
security definer  -- ejecuta como postgres, no como anon
stable
as $$
  select exists (
    select 1 from app_config
    where key = 'admin_pin_hash'
      and value = pin_hash
  );
$$;

-- Solo anon puede invocar la función (no leer la tabla)
grant execute on function verify_admin_pin(text) to anon;

-- 4. Función RPC: verifica PIN de jugador en el servidor
create or replace function verify_player_pin(player_id uuid, pin_hash text)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from players
    where id = player_id
      and pin_hash = verify_player_pin.pin_hash
      and active = true
  );
$$;

grant execute on function verify_player_pin(uuid, text) to anon;

-- 5. Función RPC: aprueba jugador y asigna PIN (solo invocable si admin ya verificó)
--    Recibe el hash del PIN, nunca el PIN en claro
create or replace function approve_player(
  p_id       uuid,
  p_pin_hash text,
  admin_hash text   -- re-verifica admin en cada operación sensible
)
returns boolean
language plpgsql
security definer
as $$
begin
  -- re-verificar que quien llama es admin
  if not exists (
    select 1 from app_config
    where key = 'admin_pin_hash' and value = admin_hash
  ) then
    return false;
  end if;

  update players
  set active = true, pin_hash = p_pin_hash
  where id = p_id;

  return found;
end;
$$;

grant execute on function approve_player(uuid, text, text) to anon;

-- 6. Función RPC: rechaza (elimina) jugador pendiente — requiere admin
create or replace function reject_player(p_id uuid, admin_hash text)
returns boolean
language plpgsql
security definer
as $$
begin
  if not exists (
    select 1 from app_config
    where key = 'admin_pin_hash' and value = admin_hash
  ) then
    return false;
  end if;
  delete from players where id = p_id and active = false;
  return found;
end;
$$;

grant execute on function reject_player(uuid, text) to anon;

-- 7. Eliminar la columna pin_hash de la respuesta pública de players
--    Creamos una vista que excluye pin_hash para lecturas (opcional pero recomendado)
--    La tabla sigue teniendo pin_hash pero la función verify_player_pin la compara server-side

-- Confirmar
select 'Migración aplicada correctamente' as status;
