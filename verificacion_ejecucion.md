# Verificacion de ejecucion

Proyecto: Corte 3 BDA - Clinica Veterinaria
Fecha de verificacion: 2026-04-22

## Alcance
- Levantamiento del stack con Docker Compose.
- Verificacion de tablas y datos en PostgreSQL.
- Validacion de API, RLS, cache Redis y control de permisos.

## Resultado general
- Stack Docker: OK
- Base de datos: OK
- API: OK
- Frontend: OK
- Cache Redis: OK
- Seguridad por capas: OK

## Evidencia de contenedores
- `api` en `0.0.0.0:4000`
- `db` en `0.0.0.0:5432`
- `frontend` en `0.0.0.0:3000`
- `redis` en `0.0.0.0:6379`

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
- `duenos`: 7
- `veterinarios`: 4
- `mascotas`: 10
- `vet_atiende_mascota`: 10
- `citas`: 11 inicialmente, 12 despues de la insercion de prueba
- `vacunas_aplicadas`: 9 inicialmente, 10 despues de la insercion de prueba

## Pruebas funcionales
- `GET /health`: OK, responde `{\"ok\":true}`.
- `GET /mascotas` como `admin`: OK, retorna 10 mascotas.
- `GET /mascotas` como `vet` con `x-vet-id=1`: OK, retorna 3 mascotas: Firulais, Toby, Max.
- `GET /mascotas?q=' OR 1=1 --` como `vet`: OK, no hubo bypass SQLi; el resultado no se expandio.
- `GET /vacunacion-pendiente`: OK, se observo `MISS` y luego `HIT`.
- `POST /vacunas/aplicar`: OK, responde `201` y obliga invalidacion de cache.
- `POST /citas/agendar`: OK, responde `201` y deja una cita nueva en BD.

## Observaciones
- El aviso de `docker-compose.yml` sobre `version` obsoleta no impidio el funcionamiento.
- La respuesta de cache puede no incluir campo explicito en todos los clientes, pero los logs de API muestran `CACHE MISS` y `CACHE HIT` correctamente.
