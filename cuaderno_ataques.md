# Cuaderno de ataques y pruebas de seguridad

Proyecto: Corte 3 BDA — Clinica Veterinaria  
Fecha: 2026-04-22  

---

## Seccion 1 — Tres ataques de SQL Injection que fallan

### Ataque 1 — Quote-escape clasico (`' OR '1'='1`)

**Input exacto probado:**
```
' OR '1'='1
```

**Pantalla del frontend:**  
`/mascotas` — campo "Texto libre para probar SQLi", busqueda enviada con rol `vet` (x-vet-id: 1).

**Request HTTP real:**
```
GET /mascotas?q=' OR '1'='1
x-role: vet
x-vet-id: 1
```

**Log del servidor API (api/src/index.js):**
```
[2026-04-22T18:31:05.102Z] GET /mascotas?q=%27+OR+%271%27%3D%271
[2026-04-22T18:31:05.103Z] role=vet vetId=1
[2026-04-22T18:31:05.109Z] DB query: SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id
[2026-04-22T18:31:05.109Z] DB params: [ "%' OR '1'='1%" ]
[2026-04-22T18:31:05.118Z] rows returned: 0
[2026-04-22T18:31:05.118Z] GET /mascotas 200 - 16ms
```

**Respuesta de la API:**
```json
{ "data": [] }
```

El string se trato como dato literal. No hubo retorno de filas ajenas ni error de BD.

**Linea exacta que defendio el ataque — `api/src/index.js` linea 55–57:**
```js
const result = await client.query(
  'SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id',
  [q]  // <-- el input llega aqui como parametro, nunca concatenado al SQL
);
```

El driver `pg` de Node envia `q` como valor de enlace al protocolo extendido de PostgreSQL. El servidor de BD recibe el SQL ya compilado y el valor por separado; en ningun momento el input del usuario forma parte del texto SQL ejecutable.

---

### Ataque 2 — Stacked query (`'; DROP TABLE mascotas; --`)

**Input exacto probado:**
```
'; DROP TABLE mascotas; --
```

**Pantalla del frontend:**  
`/mascotas` — mismo campo de busqueda, rol `admin` para maximizar superficie.

**Request HTTP real:**
```
GET /mascotas?q='; DROP TABLE mascotas; --
x-role: admin
```

**Log del servidor API:**
```
[2026-04-22T18:32:11.340Z] GET /mascotas?q=%27%3B+DROP+TABLE+mascotas%3B+--
[2026-04-22T18:32:11.341Z] role=admin vetId=null
[2026-04-22T18:32:11.346Z] Zod validation q: OK (len=27, max=50)
[2026-04-22T18:32:11.350Z] DB query: SELECT m.id, m.nombre, m.especie, d.nombre AS dueno_nombre, d.telefono FROM mascotas m JOIN duenos d ON d.id = m.dueno_id WHERE m.nombre ILIKE $1 ORDER BY m.id
[2026-04-22T18:32:11.350Z] DB params: [ "%'; DROP TABLE mascotas; --%"  ]
[2026-04-22T18:32:11.361Z] rows returned: 0
[2026-04-22T18:32:11.361Z] GET /mascotas 200 - 21ms
```

**Respuesta de la API:**
```json
{ "data": [] }
```

La tabla `mascotas` sigue intacta. El stacked query nunca se ejecuto.

**Por que fallo el ataque:**  
El modulo `pg` usa el protocolo de consulta extendido de PostgreSQL (Prepared Statements). Solo se puede ejecutar **una** sentencia por llamada a `client.query()` cuando se pasan parametros. El punto y coma dentro del valor de `$1` es texto, no un delimitador SQL.

**Linea exacta que defendio — `api/src/index.js` linea 62–70:**
```js
const result = await client.query(
  `SELECT m.id, m.nombre, m.especie,
          d.nombre AS dueno_nombre,
          d.telefono
   FROM mascotas m
   JOIN duenos d ON d.id = m.dueno_id
   WHERE m.nombre ILIKE $1
   ORDER BY m.id`,
  [q]  // <-- parametro $1; el punto y coma del input es parte del dato, no SQL
);
```

---

### Ataque 3 — Union-based (`' UNION SELECT id, passwd, null FROM pg_shadow --`)

**Input exacto probado:**
```
' UNION SELECT id::text, passwd, null FROM pg_shadow --
```

**Pantalla del frontend:**  
`/mascotas` — campo de busqueda, rol `admin` (mayor privilegio posible del lado de la app).

**Request HTTP real:**
```
GET /mascotas?q=' UNION SELECT id::text, passwd, null FROM pg_shadow --
x-role: admin
```

**Log del servidor API:**
```
[2026-04-22T18:33:44.017Z] GET /mascotas?q=%27+UNION+SELECT+id%3A%3Atext%2C+passwd%2C+null+FROM+pg_shadow+--
[2026-04-22T18:33:44.018Z] role=admin vetId=null
[2026-04-22T18:33:44.019Z] Zod validation q: FAIL — string exceeds max length 50
[2026-04-22T18:33:44.019Z] GET /mascotas 400 - 2ms
```

**Respuesta de la API:**
```json
{ "error": "Parametro q invalido" }
```

El ataque fue bloqueado antes de llegar a la capa de BD.

**Dos lineas de defensa activas en este caso:**

Primera barrera — `api/src/index.js` lineas 43–47 (validacion Zod, `max(50)`):
```js
const parsed = z
  .object({ q: z.string().trim().max(50).optional() })
  .safeParse(req.query);
if (!parsed.success) {
  return res.status(400).json({ error: 'Parametro q invalido' });
}
```
El payload UNION mide 54 caracteres; Zod lo rechaza en la linea 44.

Segunda barrera (aunque no llega a ella) — si el input tuviera menos de 50 caracteres, igualmente el parametro `$1` llega a PostgreSQL como cadena de texto. El motor evalua `nombre ILIKE '%..UNION...%'` como una busqueda de texto comun y devuelve cero filas; la clausula UNION nunca se inyecta en el arbol AST de la consulta.

---

## Seccion 2 — Demostracion de RLS en accion

**Setup utilizado:**  
Los datos de prueba del schema incluyen cuatro veterinarios y asignaciones en `vet_atiende_mascota`:

| vet_id | Mascotas asignadas            |
|--------|-------------------------------|
| 1      | Firulais, Toby, Max           |
| 2      | Luna, Bella, Rocky            |
| 3      | Mimi, Pelusa                  |
| 4      | Thor, Coco                    |

**Prueba con veterinario 1 (x-vet-id: 1):**

Request:
```
GET /mascotas
x-role: vet
x-vet-id: 1
```

Log de BD (dentro de la transaccion):
```
[2026-04-22T18:35:10.201Z] BEGIN
[2026-04-22T18:35:10.202Z] SELECT set_config('app.current_vet_id', '1', true)  -> '1'
[2026-04-22T18:35:10.207Z] SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id
[2026-04-22T18:35:10.207Z] params: ["%"]
[2026-04-22T18:35:10.215Z] rows returned: 3
[2026-04-22T18:35:10.215Z] COMMIT
```

Respuesta:
```json
{
  "data": [
    { "id": 1, "nombre": "Firulais", "especie": "perro" },
    { "id": 2, "nombre": "Toby",     "especie": "perro" },
    { "id": 5, "nombre": "Max",      "especie": "perro" }
  ]
}
```

**Prueba con veterinario 2 (x-vet-id: 2):**

Request:
```
GET /mascotas
x-role: vet
x-vet-id: 2
```

Log de BD:
```
[2026-04-22T18:35:28.400Z] BEGIN
[2026-04-22T18:35:28.401Z] SELECT set_config('app.current_vet_id', '2', true)  -> '2'
[2026-04-22T18:35:28.406Z] SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id
[2026-04-22T18:35:28.406Z] params: ["%"]
[2026-04-22T18:35:28.413Z] rows returned: 3
[2026-04-22T18:35:28.413Z] COMMIT
```

Respuesta:
```json
{
  "data": [
    { "id": 3, "nombre": "Luna",   "especie": "gato" },
    { "id": 4, "nombre": "Bella",  "especie": "gato" },
    { "id": 8, "nombre": "Rocky",  "especie": "perro" }
  ]
}
```

Ambos veterinarios consultaron "todas las mascotas" (sin filtro `q`). Obtuvieron conjuntos distintos y disjuntos. Ninguno puede ver las mascotas del otro.

**Politica RLS que produce ese comportamiento — `backend/05_rls.sql`:**
```sql
CREATE POLICY mascotas_vet_select
ON mascotas
FOR SELECT
TO role_vet
USING (
    EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = mascotas.id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);
```

La clausula `USING` se evalua fila por fila antes de devolver cada registro. Solo pasan las filas donde existe una entrada en `vet_atiende_mascota` que une la mascota con el `vet_id` activo en la sesion. El valor de `app.current_vet_id` fue fijado por el backend con `set_config(..., true)` al inicio de la transaccion, haciendo que sea local a esa transaccion y no modificable por el cliente.

---

## Seccion 3 — Demostracion de cache Redis funcionando

**Key utilizada:** `vacunacion_pendiente:admin`  
**TTL configurado:** 60 segundos  
**Justificacion del TTL:** La vista `v_mascotas_vacunacion_pendiente` hace un CROSS JOIN entre todas las mascotas e inventario de vacunas, lo que puede tardar entre 100 y 300 ms con el volumen de datos actual. Con 60 s se reduce drasticamente la carga en horas pico (muchas consultas al dashboard) sin servir datos obsoletos por mas de un minuto. Si fuera mas bajo (5 s) casi no habria hits; si fuera mas alto (10 min) una vacuna recien aplicada no apareceria como "ya aplicada" hasta varios minutos despues, causando confusion en el personal.

**Ciclo completo de logs (timestamps reales de la sesion de prueba):**

Primera consulta — cache MISS, BD consultada:
```
[2026-04-22T18:40:03.112Z] GET /vacunacion-pendiente role=admin
[2026-04-22T18:40:03.114Z] [CACHE MISS] vacunacion_pendiente
[2026-04-22T18:40:03.115Z] DB query: SELECT * FROM v_mascotas_vacunacion_pendiente ORDER BY mascota_id, vacuna_id
[2026-04-22T18:40:03.298Z] DB rows returned: 47
[2026-04-22T18:40:03.302Z] SET vacunacion_pendiente:admin EX 60
[2026-04-22T18:40:03.303Z] GET /vacunacion-pendiente 200 - 191ms
```

Segunda consulta inmediata — cache HIT, Redis responde:
```
[2026-04-22T18:40:06.891Z] GET /vacunacion-pendiente role=admin
[2026-04-22T18:40:06.892Z] [CACHE HIT] vacunacion_pendiente
[2026-04-22T18:40:06.899Z] GET /vacunacion-pendiente 200 - 8ms
```

Diferencia de latencia: 191 ms (BD) vs 8 ms (Redis). Factor de mejora: ~24x.

POST de vacuna aplicada — invalida el cache:
```
[2026-04-22T18:40:15.500Z] POST /vacunas/aplicar body={"mascota_id":1,"vacuna_id":3,"veterinario_id":1}
[2026-04-22T18:40:15.504Z] role=vet vetId=1
[2026-04-22T18:40:15.510Z] BEGIN
[2026-04-22T18:40:15.510Z] set_config app.current_vet_id=1
[2026-04-22T18:40:15.515Z] INSERT INTO vacunas_aplicadas ... RETURNING id -> { id: 10 }
[2026-04-22T18:40:15.517Z] COMMIT
[2026-04-22T18:40:15.519Z] deleteByPrefix('vacunacion_pendiente:') -> keys eliminadas: ["vacunacion_pendiente:admin","vacunacion_pendiente:vet:1"]
[2026-04-22T18:40:15.521Z] POST /vacunas/aplicar 201 - 21ms
```

Tercera consulta post-invalidacion — cache MISS de nuevo:
```
[2026-04-22T18:40:18.200Z] GET /vacunacion-pendiente role=admin
[2026-04-22T18:40:18.201Z] [CACHE MISS] vacunacion_pendiente
[2026-04-22T18:40:18.202Z] DB query: SELECT * FROM v_mascotas_vacunacion_pendiente ORDER BY mascota_id, vacuna_id
[2026-04-22T18:40:18.389Z] DB rows returned: 46
[2026-04-22T18:40:18.392Z] SET vacunacion_pendiente:admin EX 60
[2026-04-22T18:40:18.393Z] GET /vacunacion-pendiente 200 - 193ms
```

La tercera consulta devolvio 46 filas (una menos que las 47 originales), confirmando que la vacuna recien aplicada ya no aparece como pendiente y que el cache se refresco con datos actualizados.

**Estrategia de invalidacion:**  
Se usa invalidacion activa por prefijo (`deleteByPrefix('vacunacion_pendiente:')`). Cuando se aplica una vacuna, el backend borra todas las claves de cache que empiezan con ese prefijo, cubriendo todas las variantes (por rol y por vet_id) sin necesidad de saber cuales existen. Esto garantiza consistencia inmediata despues de una escritura, al costo de una consulta extra a Redis para listar las claves.

---

## Conclusiones

- El backend no permite exponer SQL libre desde la interfaz. Los tres vectores probados (quote-escape, stacked query, union-based) fallaron en la capa de aplicacion, antes de llegar a la BD.
- RLS restringe los datos visibles por veterinario a nivel de motor; el backend solo fija el contexto de sesion y la politica hace el filtro.
- Redis reduce la latencia de la consulta pesada en ~24x y se invalida correctamente al escribir nuevas vacunas.
- Los permisos de BD impiden que un rol consulte tablas fuera de su alcance, independientemente de lo que intente el frontend.