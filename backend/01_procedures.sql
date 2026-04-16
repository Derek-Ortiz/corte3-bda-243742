-- Procedures and functions (Corte 2)

CREATE OR REPLACE PROCEDURE sp_agendar_cita(
    p_mascota_id INT,
    p_veterinario_id INT,
    p_fecha_hora TIMESTAMP,
    p_motivo TEXT,
    OUT p_cita_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM mascotas WHERE id = p_mascota_id) THEN
        RAISE EXCEPTION 'Mascota no existe: %', p_mascota_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM veterinarios
        WHERE id = p_veterinario_id AND activo IS TRUE
    ) THEN
        RAISE EXCEPTION 'Veterinario no existe o esta inactivo: %', p_veterinario_id;
    END IF;

    INSERT INTO citas (mascota_id, veterinario_id, fecha_hora, motivo)
    VALUES (p_mascota_id, p_veterinario_id, p_fecha_hora, p_motivo)
    RETURNING id INTO p_cita_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_total_facturado(
    p_mascota_id INT,
    p_anio INT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(costo), 0)
    INTO v_total
    FROM citas
    WHERE mascota_id = p_mascota_id
      AND estado = 'COMPLETADA'
      AND EXTRACT(YEAR FROM fecha_hora) = p_anio;

    RETURN v_total;
END;
$$;
