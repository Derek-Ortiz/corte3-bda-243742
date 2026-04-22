# Corte 3 BDA - Clinica Veterinaria

Proyecto full-stack con seguridad en PostgreSQL (roles, RLS, hardening SQLi) y cache con Redis.

## Estructura
- backend/ (procedures, triggers, views, roles, RLS)
- api/ (Express + pg + Redis)
- frontend/ (Next.js + TS)
- schema_corte3.sql
- docker-compose.yml

## Flujo principal de la interfaz
- /login: seleccion de rol y vet_id
- /mascotas: busqueda para probar RLS y SQLi
- /vacunacion: consulta cacheada, aplicacion de vacuna y registro de cita

## Configuracion rapida (Docker)
1) Copia el archivo .env.example a .env y ajusta passwords.
2) Levanta servicios:
   docker compose up -d
3) API: http://localhost:4000
4) Frontend: http://localhost:3000

## Variables de entorno
- .env (raiz): credenciales de Postgres para roles de la app
- api/.env (opcional si no usas Docker): valores equivalentes a api/.env.example
- frontend/.env (opcional si no usas Docker): NEXT_PUBLIC_API_BASE

## Documento de decisiones (6 preguntas)

1) Politica RLS en mascotas
Clausula:
  EXISTS (
    SELECT 1
    FROM vet_atiende_mascota vam
    WHERE vam.mascota_id = mascotas.id
      AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
  )
Explicacion: solo permite al rol vet ver las mascotas asociadas a su vet_id en la tabla puente.

2) Riesgo al identificar veterinario en RLS y mitigacion
Riesgo: si un atacante puede falsificar el vet_id del contexto de sesion, puede ver mascotas ajenas.
Mitigacion: el backend fija app.current_vet_id en cada transaccion y nunca acepta SQL directo del cliente; en un sistema real, el vet_id debe venir de una sesion autenticada (JWT o session server-side), no de headers libres.

3) SECURITY DEFINER
No se uso. No fue necesario elevar privilegios porque cada rol de aplicacion tiene permisos minimos y la logica se ejecuta con el rol correcto.

4) TTL de Redis
TTL = 60 segundos (CACHE_TTL_SECONDS). Es suficiente para reducir carga en la vista pesada y aun asi refrescar datos con frecuencia. Si es muy bajo, casi no hay hits; si es muy alto, se sirven datos obsoletos.

5) Linea exacta que defiende input antes de la BD
Endpoint critico: GET /mascotas. La linea con parametros preparados es en api/src/index.js linea 56:
  client.query('SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id', [q])
Protege contra SQLi porque el driver envia el valor como dato y no como SQL ejecutable.

Endpoint de registro: POST /citas/agendar usa un INSERT parametrizado con la misma validacion de negocio que el procedure sp_agendar_cita. El motivo es tecnico: la resolucion del procedure con el driver de Node no era estable en este stack, asi que se conserva el procedure en BD y la API ejecuta la ruta equivalente de forma segura.

6) Si el rol vet solo tuviera SELECT en mascotas, que se rompe
- No puede agendar citas (INSERT en citas)
- No puede aplicar vacunas (INSERT en vacunas_aplicadas)
- No puede consultar la vista de vacunacion pendiente (SELECT en v_mascotas_vacunacion_pendiente)

## Notas
- cuaderno_ataques.md lo completaras despues.
- Para ejecutar 04_roles_y_permisos.sql con passwords, el init en Docker usa variables de entorno.
