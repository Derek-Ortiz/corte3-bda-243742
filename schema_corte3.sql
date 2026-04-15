-- =============================================================
-- ACTIVIDAD DE EVALUACION · CORTE 3
-- Base de Datos Avanzadas · UP Chiapas · Abril 2026
-- Mtro. Ramses Alejandro Camas Najera
-- Schema: Sistema de Clinica Veterinaria (extendido para Corte 3)
--
-- Diferencias vs el schema del Corte 2:
-- 1. Nueva tabla vet_atiende_mascota (relacion N:M) base para RLS
-- 2. Datos de prueba con asignaciones explicitas vet ↔ mascota
-- 3. Mas mascotas y vacunas para demos de RLS
--
-- Instrucciones:
-- 1. Crear una base de datos limpia: CREATE DATABASE clinica_vet;
-- 2. Conectarse a ella: \c clinica_vet
-- 3. Ejecutar este archivo: \i schema_corte3.sql
-- 4. NO modificar este archivo. Tu solucion va en archivos aparte.
-- =============================================================

DROP TABLE IF EXISTS alertas CASCADE;
DROP TABLE IF EXISTS historial_movimientos CASCADE;
DROP TABLE IF EXISTS vacunas_aplicadas CASCADE;
DROP TABLE IF EXISTS inventario_vacunas CASCADE;
DROP TABLE IF EXISTS citas CASCADE;
DROP TABLE IF EXISTS vet_atiende_mascota CASCADE;
DROP TABLE IF EXISTS mascotas CASCADE;
DROP TABLE IF EXISTS veterinarios CASCADE;
DROP TABLE IF EXISTS duenos CASCADE;

-- =============================================================
-- TABLAS
-- =============================================================

CREATE TABLE duenos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20),
    email VARCHAR(100)
);

CREATE TABLE veterinarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) NOT NULL UNIQUE,
    -- Dias de descanso del veterinario, separados por coma.
    -- Ejemplos: 'lunes,jueves' 'domingo' '' (trabaja todos los dias)
    dias_descanso VARCHAR(50) DEFAULT '',
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE mascotas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    especie VARCHAR(30) NOT NULL,
    fecha_nacimiento DATE,
    dueno_id INT NOT NULL REFERENCES duenos(id)
);

-- ------------------------------------------------------------
-- Tabla NUEVA en Corte 3:
-- Registra que veterinario(s) atiende(n) a cada mascota.
-- Una mascota puede tener historial con varios vets.
-- Un vet puede atender muchas mascotas.
-- Esta tabla es la base de la politica RLS sobre mascotas.
-- ------------------------------------------------------------
CREATE TABLE vet_atiende_mascota (
    id SERIAL PRIMARY KEY,
    vet_id INT NOT NULL REFERENCES veterinarios(id),
    mascota_id INT NOT NULL REFERENCES mascotas(id),
    fecha_inicio_atencion DATE NOT NULL DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT TRUE,
    UNIQUE (vet_id, mascota_id)
);

CREATE INDEX idx_vam_vet ON vet_atiende_mascota(vet_id);
CREATE INDEX idx_vam_mascota ON vet_atiende_mascota(mascota_id);

CREATE TABLE citas (
    id SERIAL PRIMARY KEY,
    mascota_id INT NOT NULL REFERENCES mascotas(id),
    veterinario_id INT NOT NULL REFERENCES veterinarios(id),
    fecha_hora TIMESTAMP NOT NULL,
    motivo TEXT,
    costo NUMERIC(10, 2),
    estado VARCHAR(20) DEFAULT 'AGENDADA'
        CHECK (estado IN ('AGENDADA', 'COMPLETADA', 'CANCELADA'))
);

CREATE TABLE inventario_vacunas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    stock_actual INT NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo INT NOT NULL DEFAULT 5,
    costo_unitario NUMERIC(10, 2) NOT NULL
);

CREATE TABLE vacunas_aplicadas (
    id SERIAL PRIMARY KEY,
    mascota_id INT NOT NULL REFERENCES mascotas(id),
    vacuna_id INT NOT NULL REFERENCES inventario_vacunas(id),
    veterinario_id INT NOT NULL REFERENCES veterinarios(id),
    fecha_aplicacion DATE NOT NULL DEFAULT CURRENT_DATE,
    costo_cobrado NUMERIC(10, 2)
);

CREATE TABLE historial_movimientos (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(30) NOT NULL,
    referencia_id INT,
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT NOW()
);

CREATE TABLE alertas (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(30) NOT NULL,
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT NOW()
);

-- =============================================================
-- DATOS DE PRUEBA
-- =============================================================

-- Duenos
INSERT INTO duenos (nombre, telefono, email) VALUES
    ('Maria Gonzalez Perez', '961-512-3401', 'maria.gonzalez@correo.mx'),
    ('Carlos Hernandez Ruiz', '961-512-3402', 'carlos.hernandez@correo.mx'),
    ('Lucia Martinez Lopez', '961-512-3403', 'lucia.martinez@correo.mx'),
    ('Diego Ramirez Solis', '961-512-3404', 'diego.ramirez@correo.mx'),
    ('Ana Patricia Vazquez', '961-512-3405', NULL),
    ('Roberto Cruz Dominguez', '961-512-3406', 'roberto.cruz@correo.mx'),
    ('Valentina Ortiz Reyes', '961-512-3407', 'valentina.ortiz@correo.mx');

-- Veterinarios
-- Dr. Lopez: descansa lunes y jueves
-- Dra. Garcia: descansa solo domingo
-- Dr. Mendez: trabaja todos los dias
-- Dra. Sanchez: INACTIVA
INSERT INTO veterinarios (nombre, cedula, dias_descanso, activo) VALUES
    ('Dr. Fernando Lopez Castro', 'VET-2018-001', 'lunes,jueves', TRUE),
    ('Dra. Sofia Garcia Velasco', 'VET-2019-014', 'domingo', TRUE),
    ('Dr. Andres Mendez Bravo', 'VET-2021-027', '', TRUE),
    ('Dra. Monica Sanchez Aguilar', 'VET-2017-008', 'lunes', FALSE);

-- Mascotas
INSERT INTO mascotas (nombre, especie, fecha_nacimiento, dueno_id) VALUES
    ('Firulais', 'perro', '2019-03-15', 1),
    ('Misifu', 'gato', '2020-07-22', 2),
    ('Rocky', 'perro', '2018-11-08', 3),
    ('Luna', 'gato', '2022-05-30', 4),
    ('Toby', 'perro', '2017-02-14', 1),
    ('Pelusa', 'conejo', '2023-09-01', 5),
    ('Max', 'perro', '2021-04-18', 6),
    ('Coco', 'gato', '2024-08-12', 7),
    ('Dante', 'perro', '2016-12-03', 2),
    ('Mango', 'gato', '2023-01-20', 3);

-- ------------------------------------------------------------
-- ASIGNACIONES vet ↔ mascota (clave para RLS)
-- ------------------------------------------------------------
-- Distribucion disenada para que RLS sea visualmente demostrable:
-- Dr. Lopez (vet_id = 1): Firulais(1), Toby(5), Max(7)
-- Dra. Garcia (vet_id = 2): Misifu(2), Luna(4), Dante(9)
-- Dr. Mendez (vet_id = 3): Rocky(3), Pelusa(6), Coco(8), Mango(10)
-- Dra. Sanchez (vet_id = 4): ninguna (esta inactiva)
--
-- Una mascota tiene UN vet primario. Cuando vet_id=1 hace SELECT *
-- FROM mascotas debe ver solo {Firulais, Toby, Max}. Cuando admin
-- consulta debe ver las 10. Esto es lo que hay que demostrar en el
-- cuaderno de ataques (Seccion 2).
-- ------------------------------------------------------------
INSERT INTO vet_atiende_mascota (vet_id, mascota_id, fecha_inicio_atencion) VALUES
    (1, 1, '2024-01-15'), -- Lopez atiende a Firulais
    (1, 5, '2024-03-20'), -- Lopez atiende a Toby
    (1, 7, '2025-02-10'), -- Lopez atiende a Max
    (2, 2, '2024-02-08'), -- Garcia atiende a Misifu
    (2, 4, '2024-06-12'), -- Garcia atiende a Luna
    (2, 9, '2024-09-01'), -- Garcia atiende a Dante
    (3, 3, '2024-04-22'), -- Mendez atiende a Rocky
    (3, 6, '2024-11-05'), -- Mendez atiende a Pelusa
    (3, 8, '2025-01-18'), -- Mendez atiende a Coco
    (3, 10, '2025-03-30'); -- Mendez atiende a Mango

-- Inventario de vacunas
INSERT INTO inventario_vacunas (nombre, stock_actual, stock_minimo, costo_unitario) VALUES
    ('Antirrabica canina', 25, 10, 350.00),
    ('Quintuple felina', 18, 8, 480.00),
    ('Parvovirus canino', 12, 5, 290.00),
    ('Triple felina', 7, 8, 410.00),
    ('Bordetella canina', 20, 10, 270.00),
    ('Leucemia felina', 4, 5, 520.00);

-- Citas historicas y futuras (mismo set que recuperacion)
INSERT INTO citas (mascota_id, veterinario_id, fecha_hora, motivo, costo, estado) VALUES
    (1, 1, '2025-09-15 10:00:00', 'Revision general', 450.00, 'COMPLETADA'),
    (1, 2, '2025-11-20 11:00:00', 'Vacunacion anual', 350.00, 'COMPLETADA'),
    (2, 2, '2025-10-05 09:30:00', 'Limpieza dental', 780.00, 'COMPLETADA'),
    (3, 1, '2025-08-10 16:00:00', 'Curacion de herida', 620.00, 'COMPLETADA'),
    (4, 3, '2026-01-12 12:00:00', 'Esterilizacion', 1850.00, 'COMPLETADA'),
    (5, 1, '2025-06-22 10:30:00', 'Revision cojera', 550.00, 'COMPLETADA'),
    (7, 2, '2026-02-08 14:00:00', 'Vacunacion multiple', 650.00, 'COMPLETADA'),
    (9, 3, '2026-03-01 11:30:00', 'Geriatria', 820.00, 'COMPLETADA'),
    (1, 1, '2026-04-25 10:00:00', 'Revision seguimiento', 500.00, 'AGENDADA'),
    (4, 2, '2026-04-27 09:00:00', 'Control postoperatorio', 400.00, 'AGENDADA'),
    (3, 1, '2025-12-15 15:00:00', 'Revision cancelada', 550.00, 'CANCELADA');

-- Vacunas aplicadas (mismo set que recuperacion)
INSERT INTO vacunas_aplicadas (mascota_id, vacuna_id, veterinario_id, fecha_aplicacion, costo_cobrado) VALUES
    (1, 1, 1, '2024-09-15', 350.00),
    (1, 3, 1, '2025-09-15', 290.00),
    (2, 2, 2, '2024-08-22', 480.00),
    (2, 4, 2, '2025-08-22', 410.00),
    (3, 1, 1, '2024-04-10', 350.00),
    (3, 3, 1, '2024-10-10', 290.00),
    (4, 4, 3, '2026-01-12', 410.00),
    (7, 2, 2, '2026-02-08', 480.00),
    (9, 1, 3, '2024-12-01', 350.00);

-- =============================================================
-- VERIFICACION DE CARGA
-- =============================================================
DO $$
DECLARE
    v_duenos INT;
    v_vets INT;
    v_mascotas INT;
    v_asign INT;
    v_citas INT;
    v_vacunas INT;
BEGIN
    SELECT COUNT(*) INTO v_duenos FROM duenos;
    SELECT COUNT(*) INTO v_vets FROM veterinarios;
    SELECT COUNT(*) INTO v_mascotas FROM mascotas;
    SELECT COUNT(*) INTO v_asign FROM vet_atiende_mascota;
    SELECT COUNT(*) INTO v_citas FROM citas;
    SELECT COUNT(*) INTO v_vacunas FROM vacunas_aplicadas;

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Schema Corte 3 cargado correctamente.';
    RAISE NOTICE ' Duenos: % Veterinarios: %', v_duenos, v_vets;
    RAISE NOTICE ' Mascotas: % Asignaciones vet-mascota: %', v_mascotas, v_asign;
    RAISE NOTICE ' Citas: % Vacunas aplicadas: %', v_citas, v_vacunas;
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Asignaciones vet -> mascotas (para RLS):';
    RAISE NOTICE ' vet_id=1 (Dr. Lopez): Firulais, Toby, Max';
    RAISE NOTICE ' vet_id=2 (Dra. Garcia): Misifu, Luna, Dante';
    RAISE NOTICE ' vet_id=3 (Dr. Mendez): Rocky, Pelusa, Coco, Mango';
    RAISE NOTICE ' vet_id=4 (Dra. Sanchez): ninguna (inactiva)';
    RAISE NOTICE '=================================================';
END $$;

-- =============================================================
-- NOTAS PARA TU IMPLEMENTACION
-- =============================================================
-- Este schema te deja listas las tablas, datos y relaciones.
-- El resto lo construyes tu con base en lo que viste en clase y en la
-- documentacion oficial de PostgreSQL y Redis.
--
-- Puntos a resolver (sin orden obligatorio):
-- 1. Crear los roles necesarios con permisos finos usando GRANT y REVOKE.
-- 2. Habilitar RLS en las tablas sensibles y disenar las politicas.
-- 3. Hardening del procedure sp_agendar_cita y de toda query que toque input.
-- 4. Cache Redis sobre v_mascotas_vacunacion_pendiente.
--    Decide key, TTL y estrategia de invalidacion.
-- Documenta en el README que decisiones tomaste y por que.
-- =============================================================
