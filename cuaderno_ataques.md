# Cuaderno de ataques y pruebas de seguridad

## 1. SQL injection en mascotas
Prueba:
- `GET /mascotas?q=' OR 1=1 --`

Resultado:
- No hubo bypass de filtros.
- La API utiliza consultas parametrizadas.
- En la prueba con rol `vet`, el resultado no se expandio a registros ajenos.

## 2. RLS con rol vet
Prueba SQL directa:
- `SET app.current_vet_id='1';`
- `SELECT COUNT(*) FROM mascotas;`
- `SELECT array_agg(nombre ORDER BY id) FROM mascotas;`

Resultado:
- El rol `app_vet` solo vio 3 mascotas: Firulais, Toby y Max.
- Esto coincide con la asignacion definida en `vet_atiende_mascota`.

## 3. Acceso a tablas restringidas
Prueba SQL directa:
- `SELECT COUNT(*) FROM duenos;` con `app_vet`

Resultado:
- Error esperado: `permission denied for table duenos`.
- Confirma que los permisos son finos y no excesivos.

## 4. Cache Redis
Prueba:
- Dos llamadas a `GET /vacunacion-pendiente` como `admin`.

Resultado:
- Primera llamada: `MISS`.
- Segunda llamada: `HIT`.
- La cache se invalida despues de aplicar una vacuna.

## 5. Escritura segura
Prueba:
- `POST /vacunas/aplicar`
- `POST /citas/agendar`

Resultado:
- Ambas rutas respondieron `201`.
- La insercion de vacuna mantiene la logica de negocio y la invalidacion de cache.
- La cita queda persistida en la tabla `citas`.

## 6. Conclusiones
- El backend no permite exponer SQL libre desde la interfaz.
- RLS restringe los datos visibles por veterinario.
- Los permisos de BD impiden que un rol consulte tablas fuera de su alcance.
- Redis acelera la vista de vacunacion sin romper consistencia funcional.
