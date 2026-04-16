-- Vista: mascotas con vacunas pendientes

CREATE OR REPLACE VIEW v_mascotas_vacunacion_pendiente AS
SELECT
    m.id AS mascota_id,
    m.nombre AS mascota_nombre,
    m.especie,
    d.nombre AS dueno_nombre,
    d.telefono,
    iv.id AS vacuna_id,
    iv.nombre AS vacuna_nombre
FROM mascotas m
JOIN duenos d ON d.id = m.dueno_id
CROSS JOIN inventario_vacunas iv
LEFT JOIN vacunas_aplicadas va
    ON va.mascota_id = m.id
   AND va.vacuna_id = iv.id
WHERE va.id IS NULL;
