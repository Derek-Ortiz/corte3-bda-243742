# Corte 3 BDA - Clinica Veterinaria

Proyecto full-stack con seguridad en PostgreSQL (roles, RLS, hardening SQLi) y cache con Redis.

## Estructura

```
corte3-bda/
├── README.md                    # Documento de decisiones (6 preguntas)
├── cuaderno_ataques.md          # Tres ataques SQLi + demo RLS + demo Redis
├── schema_corte3.sql            # Schema base (sin modificar)
├── backend/
│   ├── 01_procedures.sql        # sp_agendar_cita, fn_total_facturado
│   ├── 02_triggers.sql          # trg_historial_cita
│   ├── 03_views.sql             # v_mascotas_vacunacion_pendiente
│   ├── 04_roles_y_permisos.sql  # GRANT / REVOKE por rol
│   └── 05_rls.sql               # Politicas RLS en mascotas, citas, vacunas_aplicadas
├── api/                         # Express + pg + Redis (Node.js)
├── frontend/                    # Next.js + TypeScript
└── docker-compose.yml           # PostgreSQL 16 + Redis 7 + API + Frontend
```

## Flujo principal de la interfaz

- `/login` — seleccion de rol (vet / recepcion / admin) y vet_id
- `/mascotas` — busqueda con campo libre para probar RLS y SQLi
- `/vacunacion` — listado cacheado, formulario de vacuna y registro de cita

## Configuracion rapida (Docker)

1. Copia `.env.example` a `.env` en la raiz y ajusta passwords.
2. Levanta todos los servicios:
   ```
   docker compose up -d
   ```
3. API disponible en `http://localhost:4000`
4. Frontend en `http://localhost:3000`

## Variables de entorno

- `.env` (raiz): credenciales de Postgres para los tres roles de aplicacion
- `api/.env` (opcional sin Docker): equivalente a `api/.env.example`
- `frontend/.env` (opcional sin Docker): `NEXT_PUBLIC_API_BASE`

---

## Documento de decisiones (6 preguntas)

### 1. Politica RLS aplicada a la tabla mascotas

Clausula exacta (`backend/05_rls.sql`):

```sql
CREATE POLICY mascotas_vet_select
ON mascotas FOR SELECT TO role_vet
USING (
    EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = mascotas.id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);
```

Lo que hace: antes de devolver cada fila de `mascotas`, PostgreSQL verifica que exista una entrada en la tabla puente `vet_atiende_mascota` que enlace esa mascota con el `vet_id` activo en la sesion. Si no existe esa entrada, la fila no se devuelve. El veterinario nunca ve mascotas que no atiende, aunque ejecute `SELECT * FROM mascotas` sin filtros.

---

### 2. Vector de ataque al identificar al veterinario en RLS y mitigacion

La estrategia usa `current_setting('app.current_vet_id', true)`, que es un parametro de sesion fijado por el backend con `set_config(...)` al inicio de cada transaccion.

**Vector de ataque posible:** si el `vet_id` llega al backend desde un header HTTP sin autenticar (`x-vet-id`), un atacante puede enviar cualquier numero en ese header y suplantar a otro veterinario. El header no tiene firma ni esta protegido por un token.

**Mitigacion implementada:** el backend valida que `x-vet-id` sea un entero positivo (Zod), y el valor se fija con `set_config(..., true)` donde el tercer argumento `true` hace que la variable sea local a la transaccion actual: se descarta al hacer `COMMIT` o `ROLLBACK`, por lo que no persiste entre conexiones del pool. En un sistema real, el `vet_id` deberia extraerse de un JWT firmado por el servidor, nunca del cliente directamente.

---

### 3. SECURITY DEFINER

No se uso en ningun procedure ni funcion. No fue necesario elevar privilegios porque cada rol de aplicacion (`app_vet`, `app_recepcion`, `app_admin`) tiene exactamente los permisos que necesita para ejecutar sus operaciones. La logica de negocio corre con el rol correcto en cada transaccion, sin necesidad de elevar al owner de la funcion.

---

### 4. TTL del cache Redis y justificacion

**TTL elegido: 60 segundos** (variable `CACHE_TTL_SECONDS` en el entorno).

La vista `v_mascotas_vacunacion_pendiente` hace un CROSS JOIN entre mascotas e inventario de vacunas, tardando entre 100 y 300 ms con el volumen actual. Con 60 s se absorbe la carga de las consultas repetidas al dashboard sin servir datos obsoletos por mas de un minuto.

- Si fuera demasiado bajo (5 s): casi ninguna consulta encontraria cache calido; la mejora de latencia seria marginal y el cache no tendria utilidad practica.
- Si fuera demasiado alto (10 min o mas): una vacuna recien aplicada seguiria apareciendo como pendiente durante varios minutos, causando confusion en el personal. El sistema ya tiene invalidacion activa al escribir vacunas, asi que el TTL es un respaldo, no la unica defensa contra datos obsoletos.

---

### 5. Linea exacta que defiende input del usuario antes de la BD

**Endpoint critico: `GET /mascotas`**

Primera barrera — validacion Zod (`api/src/index.js` lineas 43–47):
```js
const parsed = z
  .object({ q: z.string().trim().max(120).optional() })
  .safeParse(req.query);
if (!parsed.success) {
  return res.status(400).json({ error: 'Parametro q invalido' });
}
```
Rechaza cualquier input mayor a 120 caracteres antes de llegar a la BD. El input sigue llegando parametrizado, por lo que sigue sin poder ejecutarse como SQL.

Segunda barrera — consulta parametrizada (`api/src/index.js` linea 55–57):
```js
const result = await client.query(
  'SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id',
  [q]
);
```
El driver `pg` envia `q` como valor de enlace mediante el protocolo extendido de PostgreSQL. El servidor de BD recibe el texto SQL precompilado y el valor por separado; el input del usuario nunca forma parte del texto SQL ejecutable, independientemente de su contenido.

---

### 6. Si se revocan todos los permisos de role_vet excepto SELECT en mascotas, que se rompe

Tres operaciones que dejan de funcionar:

1. **Agendar citas** — requiere `INSERT` en `citas`. Sin ese permiso, `POST /citas/agendar` falla con `permission denied for table citas`.

2. **Aplicar vacunas** — requiere `INSERT` en `vacunas_aplicadas`. Sin ese permiso, `POST /vacunas/aplicar` falla con `permission denied for table vacunas_aplicadas`.

3. **Consultar vacunacion pendiente** — requiere `SELECT` en `duenos` e `inventario_vacunas` (tablas subyacentes de la vista) ademas de `SELECT` en la propia vista. Sin esos permisos, `GET /vacunacion-pendiente` falla con `permission denied for table duenos`.

---

## Permisos por rol (resumen)

| Tabla / Objeto                   | role_vet              | role_recepcion        | role_admin            |
|----------------------------------|-----------------------|-----------------------|-----------------------|
| mascotas                         | SELECT (filtrado RLS) | SELECT (todo)         | ALL                   |
| duenos                           | SELECT                | SELECT                | SELECT                |
| veterinarios                     | —                     | SELECT                | SELECT                |
| citas                            | SELECT/INSERT/UPDATE (RLS) | SELECT/INSERT/UPDATE | ALL               |
| vacunas_aplicadas                | SELECT/INSERT (RLS)   | —                     | ALL                   |
| inventario_vacunas               | SELECT                | —                     | ALL                   |
| vet_atiende_mascota              | SELECT                | —                     | ALL                   |
| historial_movimientos            | —                     | —                     | ALL                   |
| alertas                          | —                     | —                     | ALL                   |
| v_mascotas_vacunacion_pendiente  | SELECT                | SELECT                | SELECT                |

---
