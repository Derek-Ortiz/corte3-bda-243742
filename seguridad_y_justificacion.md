# Seguridad y justificacion por capas

## Capa PostgreSQL — Roles y permisos

Se definio un rol base por tipo de personal mas un rol de aplicacion con login para cada uno:

| Rol base        | Rol de aplicacion | Proposito                                    |
|-----------------|-------------------|----------------------------------------------|
| role_vet        | app_vet           | Veterinarios: acceso restringido por RLS     |
| role_recepcion  | app_recepcion     | Recepcion: datos de contacto y agenda        |
| role_admin      | app_admin         | Administrador: acceso completo               |

**Principio de minimo privilegio aplicado:**

- `role_vet` tiene SELECT en `mascotas` (filtrado por RLS), SELECT en `duenos` e `inventario_vacunas` (requerido para consultar la vista `v_mascotas_vacunacion_pendiente` que hace JOIN y CROSS JOIN sobre esas tablas), INSERT en `vacunas_aplicadas` y `citas` (ambas con politicas RLS que impiden escribir sobre mascotas ajenas). No tiene acceso a `veterinarios`, `historial_movimientos` ni `alertas`.

- `role_recepcion` tiene SELECT en `mascotas`, `duenos`, `veterinarios` y `citas`, mas INSERT/UPDATE en `citas`. No tiene ningun acceso a `vacunas_aplicadas` (informacion medica) ni a tablas administrativas.

- `role_admin` tiene acceso completo a todas las tablas. Es el unico que puede gestionar `inventario_vacunas`, `vet_atiende_mascota`, `historial_movimientos` y `alertas` con INSERT, UPDATE, DELETE.

---

## Capa PostgreSQL — Row-Level Security

RLS esta habilitado y forzado (`ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY`) en tres tablas:

**mascotas:** el vet solo ve las filas donde existe una entrada en `vet_atiende_mascota` para su `vet_id`. Recepcion y admin ven todo.

**citas:** el vet solo ve citas donde `veterinario_id` coincide con su `vet_id`. Al escribir, ademas verifica que la mascota este en su lista. Recepcion y admin ven y modifican todo.

**vacunas_aplicadas:** el vet solo ve vacunas de mascotas que atiende (via `vet_atiende_mascota`). Al insertar, verifica que sea el veterinario asignado y que la mascota sea suya. Recepcion no tiene acceso (bloqueado por GRANT, no por RLS).

El `vet_id` activo se comunica a PostgreSQL mediante `set_config('app.current_vet_id', vetId, true)` al inicio de cada transaccion. El tercer argumento `true` hace que el valor sea local a la transaccion: se descarta con el COMMIT o ROLLBACK, sin afectar otras conexiones del pool.

---

## Capa de aplicacion — Hardening SQLi

Dos barreras en serie para todo input del usuario:

**Barrera 1 — Validacion con Zod:** antes de construir cualquier query, el input pasa por un schema Zod que verifica tipo, longitud maxima (120 caracteres para `q`) y formato. Los payloads de UNION SELECT siguen sin ejecutarse como SQL porque el valor llega parametrizado al driver.

**Barrera 2 — Consultas parametrizadas:** todas las queries usan el protocolo extendido de PostgreSQL a traves del driver `pg`. El SQL se compila primero y el valor del parametro llega por separado; el motor de BD nunca interpreta el input del usuario como SQL. Esto previene quote-escape y stacked queries independientemente del contenido del input.

Adicionalmente:
- `x-role` se valida contra un enum estricto (`vet | recepcion | admin`).
- `x-vet-id` se valida como entero positivo antes de usarse en `set_config`.
- El flujo de escritura (vacunas, citas) usa schemas Zod con tipos numericos estrictos, eliminando la superficie de inyeccion en los campos del body.

No se usa SQL dinamico con `EXECUTE` en ningun procedure, por lo que no aplica la mitigacion de `quote_literal` / `format()` de PostgreSQL.

No se usa `SECURITY DEFINER` en ningun objeto. No fue necesario elevar privilegios porque cada rol de aplicacion tiene los permisos exactos que necesita, y la logica de negocio corre con el rol correcto desde el inicio de cada transaccion.

---

## Capa de cache — Redis

La vista `v_mascotas_vacunacion_pendiente` es la consulta mas costosa del sistema (CROSS JOIN entre mascotas e inventario de vacunas). Se cachea en Redis con las siguientes decisiones:

**Key:** diferenciada por rol y por vet_id.
- Admin: `vacunacion_pendiente:admin`
- Vet: `vacunacion_pendiente:vet:{vet_id}`
- Recepcion: `vacunacion_pendiente:recepcion`

Esto garantiza que el cache de un vet no filtre datos de otro vet, y que los roles con distintos conjuntos de datos no compartan entradas de cache.

**TTL:** 60 segundos. Suficiente para absorber consultas repetidas al dashboard sin mantener datos obsoletos por mas de un minuto.

**Invalidacion:** activa por prefijo. Cuando se aplica una vacuna (`POST /vacunas/aplicar`), el backend ejecuta `deleteByPrefix('vacunacion_pendiente:')`, eliminando todas las variantes de cache sin necesidad de conocer cuales existen. El sistema sirve datos frescos en la siguiente consulta aunque el TTL no haya expirado.

La invalidacion se ejecuta en un bloque `try/catch` separado para que un fallo de Redis no bloquee la respuesta de negocio.

---

## Justificacion tecnica del endpoint de citas

El procedure `sp_agendar_cita` esta definido correctamente en BD y funciona en psql directo. La API ejecuta un INSERT parametrizado equivalente porque la resolucion del parametro `OUT` mediante `CALL` con el driver `pg` de Node resulto inestable en este stack durante las pruebas de integracion.

En terminos de seguridad el comportamiento es equivalente: no se expone SQL libre, el trigger `trg_historial_cita` se dispara igualmente al insertar en `citas`, y todas las politicas RLS de escritura aplican sobre el INSERT de la misma forma que aplicarian sobre el CALL al procedure.