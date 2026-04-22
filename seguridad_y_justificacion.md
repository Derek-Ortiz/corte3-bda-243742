# Seguridad y justificacion por capas

## Capa PostgreSQL
- Se aplico principio de minimo privilegio con roles separados: `role_vet`, `role_recepcion`, `role_admin`.
- `role_vet` solo tiene los permisos necesarios para operar con mascotas, citas, vacunas y la tabla puente que soporta RLS.
- `role_recepcion` puede consultar dueños, mascotas y citas, pero no administrar inventario ni roles.
- `role_admin` conserva permisos amplios de operacion y administracion.
- RLS esta habilitado y forzado en `mascotas`, `citas` y `vacunas_aplicadas`.

## Capa de aplicacion
- La API valida `x-role` y exige `x-vet-id` para el rol `vet`.
- Las consultas de lectura usan parametros preparados, evitando SQL injection.
- El flujo de escritura usa validacion con `zod` antes de tocar la BD.
- La invalidacion de cache se trata como proceso auxiliar y no bloquea la respuesta de negocio.

## Capa de datos
- El acceso de `vet` a `mascotas` queda limitado por la politica RLS que compara contra `app.current_vet_id`.
- La prueba con `app_vet` mostro que sin contexto no puede leer `duenos` y con contexto solo ve sus 3 mascotas.
- Esto demuestra que la autorizacion no depende solo del frontend.

## Capa de cache
- Redis se usa para `v_mascotas_vacunacion_pendiente`.
- La cache se valido con `MISS` y `HIT`.
- Tras escribir una vacuna, la cache se invalida por prefijo para evitar datos obsoletos.

## Justificacion tecnica de la cita
- El procedimiento `sp_agendar_cita` existe y esta documentado, pero la resolucion del `CALL` con este stack de Node/PostgreSQL resulto inestable.
- Para no dejar una ruta fragil, la API ejecuta un `INSERT` parametrizado equivalente, manteniendo validacion, seguridad y el trigger de historial.
- En terminos de seguridad, el comportamiento es correcto porque no expone SQL libre y conserva las restricciones de BD.
