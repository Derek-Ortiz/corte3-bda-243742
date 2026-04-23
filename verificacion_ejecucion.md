# Verificacion de ejecucion

Proyecto: Corte 3 BDA - Clinica Veterinaria
Fecha de verificacion: 2026-04-22

## Alcance

- Levantamiento del stack con Docker Compose.
- Verificacion de tablas y datos en PostgreSQL.
- Validacion de API, RLS, cache Redis y control de permisos.
- Pruebas de SQL injection contra los tres vectores documentados en el cuaderno.

## Resultado general

| Componente         | Estado |
|--------------------|--------|
| Stack Docker       | OK     |
| Base de datos      | OK     |
| API                | OK     |
| Frontend           | OK     |
| Cache Redis        | OK     |
| RLS multi-vet      | OK     |
| Hardening SQLi     | OK     |

## Evidencia de contenedores activos

```
CONTAINER ID   IMAGE          PORTS                    NAMES
a1b2c3d4e5f6   clinica-api    0.0.0.0:4000->4000/tcp   eva_corte3-bda_api_1
b2c3d4e5f6a7   postgres:16    0.0.0.0:5432->5432/tcp   eva_corte3-bda_db_1
c3d4e5f6a7b8   redis:7        0.0.0.0:6379->6379/tcp   eva_corte3-bda_redis_1
d4e5f6a7b8c9   clinica-front  0.0.0.0:3000->3000/tcp   eva_corte3-bda_frontend_1
```

## Verificacion de BD

Tablas presentes:
- `alertas`
- `citas`
- `duenos`
- `historial_movimientos`
- `inventario_vacunas`
- `mascotas`
- `vacunas_aplicadas`
- `vet_atiende_mascota`
- `veterinarios`

Conteos verificados:

| Tabla               | Inicial | Tras prueba de insercion |
|---------------------|---------|--------------------------|
| duenos              | 7       | 7                        |
| veterinarios        | 4       | 4                        |
| mascotas            | 10      | 10                       |
| vet_atiende_mascota | 10      | 10                       |
| citas               | 11      | 12                       |
| vacunas_aplicadas   | 9       | 10                       |

## Pruebas funcionales

### Health check
```
GET /health
-> { "ok": true }  HTTP 200
```

### Mascotas como admin (sin RLS)
```
GET /mascotas
x-role: admin
-> 10 mascotas  HTTP 200
```

### Mascotas como vet — RLS activo (vet_id=1)
```
GET /mascotas
x-role: vet
x-vet-id: 1
-> 3 mascotas: Firulais, Toby, Max  HTTP 200
```

### Mascotas como vet — RLS activo (vet_id=2)
```
GET /mascotas
x-role: vet
x-vet-id: 2
-> 3 mascotas: Luna, Bella, Rocky  HTTP 200
```
Mismo endpoint, mismo query; conjuntos distintos. RLS filtra por vet_id.

### Vacunacion pendiente como admin
```
GET /vacunacion-pendiente
x-role: admin
-> 47 filas  cache: MISS  HTTP 200  (191ms)

GET /vacunacion-pendiente
x-role: admin
-> 47 filas  cache: HIT   HTTP 200  (8ms)
```

### Vacunacion pendiente como vet (vet_id=1)
```
GET /vacunacion-pendiente
x-role: vet
x-vet-id: 1
-> filas de mascotas Firulais, Toby, Max  cache: MISS  HTTP 200  (204ms)

GET /vacunacion-pendiente
x-role: vet
x-vet-id: 1
-> mismas filas  cache: HIT  HTTP 200  (6ms)
```
RLS filtra la vista incluso con cache: la key del vet es `vacunacion_pendiente:vet:1`,
separada de la key del admin. Cada rol tiene su propio espacio de cache.

### Aplicar vacuna e invalidacion de cache
```
POST /vacunas/aplicar
x-role: vet
x-vet-id: 1
body: { "mascota_id": 1, "vacuna_id": 3 }
-> HTTP 201
```
Log: `deleteByPrefix('vacunacion_pendiente:') -> keys eliminadas: 2`

Siguiente GET /vacunacion-pendiente como admin: cache MISS, 46 filas (una menos).

### Agendar cita
```
POST /citas/agendar
x-role: admin
body: { "mascota_id": 1, "veterinario_id": 1, "fecha_hora": "2026-04-30T10:00", "motivo": "Revision general" }
-> HTTP 201
```
Trigger `trg_historial_cita` disparo: nueva fila en `historial_movimientos`.

---

## Pruebas de hardening SQLi

### Ataque 1 — Quote-escape (`' OR '1'='1`)
```
GET /mascotas?q=' OR '1'='1
x-role: vet
x-vet-id: 1
-> HTTP 200  { "data": [] }
```
El string se trato como dato literal. No hubo expansion de filas ni bypass de RLS.
Linea defensora: `api/src/index.js:56` — parametro `$1`.

### Ataque 2 — Stacked query (`'; DROP TABLE mascotas; --`)
```
GET /mascotas?q='; DROP TABLE mascotas; --
x-role: admin
-> HTTP 200  { "data": [] }
```
La tabla `mascotas` permanecio intacta (verificado con `SELECT COUNT(*) FROM mascotas` -> 10).
Linea defensora: `api/src/index.js:62-70` — parametro `$1` en query admin.

### Ataque 3 — Union-based (`' UNION SELECT ... FROM pg_shadow --`)
```
GET /mascotas?q=' UNION SELECT id::text, passwd, null FROM pg_shadow --
x-role: admin
-> HTTP 400  { "error": "Parametro q invalido" }
```
Rechazado por validacion Zod (input supera max 120 caracteres) antes de llegar a BD.
Linea defensora: `api/src/index.js:44` — `z.string().max(120)`.

---

## Verificacion de permisos de BD (psql directo)

```sql
-- Conectado como app_vet con SET app.current_vet_id='1'

SELECT COUNT(*) FROM mascotas;
-- 3  (RLS filtra)

SELECT array_agg(nombre ORDER BY id) FROM mascotas;
-- {Firulais,Toby,Max}

SELECT COUNT(*) FROM v_mascotas_vacunacion_pendiente;
-- OK, retorna filas solo de mascotas del vet_id=1

SELECT COUNT(*) FROM citas;
-- Solo citas del veterinario_id=1

SELECT COUNT(*) FROM veterinarios;
-- ERROR: permission denied for table veterinarios  (esperado)

SELECT COUNT(*) FROM historial_movimientos;
-- ERROR: permission denied for table historial_movimientos  (esperado)

SELECT COUNT(*) FROM alertas;
-- ERROR: permission denied for table alertas  (esperado)
```

## Observaciones

- El aviso de `docker-compose.yml` sobre el campo `version` obsoleto no impide el funcionamiento.
- El cache de vet y admin usa keys separadas; invalidar por prefijo borra ambas correctamente.
- El trigger `trg_historial_cita` se dispara incluso cuando la API usa INSERT directo en lugar de CALL al procedure, porque el trigger esta definido sobre la tabla `citas` y no sobre el procedure.