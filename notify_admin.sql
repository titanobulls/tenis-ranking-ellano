-- ============================================================
-- NOTIFICACIÓN WhatsApp admin al registrarse un jugador
-- Ejecutar en Supabase > SQL Editor > Run
-- ============================================================

-- pg_net viene incluido en Supabase — solo hay que habilitarlo
create extension if not exists pg_net schema extensions;

-- Función que dispara la notificación
create or replace function notify_admin_new_player()
returns trigger
language plpgsql
security definer
as $$
declare
  v_name   text;
  v_wa     text;
  v_msg    text;
begin
  v_name := replace(coalesce(NEW.name, 'Sin nombre'), ' ', '+');
  v_wa   := coalesce(NEW.whatsapp, 'sin+numero');

  v_msg :=
    '%F0%9F%8E%BE+Ranking+El+Llano%0A'
    || 'Nuevo+jugador+quiere+unirse%3A%0A'
    || '%F0%9F%91%A4+' || v_name || '%0A'
    || '%F0%9F%93%B1+%2B' || v_wa || '%0A'
    || 'Entr%C3%A1+al+panel+Admin+para+aprobar+o+rechazar.';

  perform extensions.http_get(
    url := 'https://api.callmebot.com/whatsapp.php'
         || '?phone=56977467726'
         || '&text=' || v_msg
         || '&apikey=8888811'
  );

  return NEW;
exception
  -- Si la notificación falla, el INSERT igual se completa
  when others then
    return NEW;
end;
$$;

-- Trigger: se activa solo en registros con active = false (solicitudes)
drop trigger if exists on_player_register on players;
create trigger on_player_register
  after insert on players
  for each row
  when (new.active = false)
  execute function notify_admin_new_player();

select 'Notificación WhatsApp configurada correctamente' as status;
