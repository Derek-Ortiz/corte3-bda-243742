const express = require('express');
const { z } = require('zod');
const { config } = require('./config');
const { withDb } = require('./db');
const { initRedis, getCache, setCache, deleteByPrefix } = require('./cache');

const app = express();

app.use((req, res, next) => {
  const origin = req.header('origin');
  if (origin && origin === config.frontendOrigin) {
    res.header('Access-Control-Allow-Origin', origin);
    res.header('Vary', 'Origin');
  }

  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, x-role, x-vet-id');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }

  next();
});

app.use(express.json());

const roleSchema = z.enum(['vet', 'recepcion', 'admin']);

function getContext(req) {
  const roleRaw = req.header('x-role');
  const role = roleRaw ? roleRaw.toLowerCase() : '';
  const parsedRole = roleSchema.safeParse(role);
  if (!parsedRole.success) {
    return { error: 'x-role invalido (vet, recepcion, admin)' };
  }

  let vetId = null;
  if (role === 'vet') {
    const vetHeader = req.header('x-vet-id');
    const parsedVet = z.coerce.number().int().positive().safeParse(vetHeader);
    if (!parsedVet.success) {
      return { error: 'x-vet-id requerido para rol vet' };
    }
    vetId = parsedVet.data;
  }

  return { role, vetId };
}

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/mascotas', async (req, res, next) => {
  const ctx = getContext(req);
  if (ctx.error) {
    return res.status(400).json({ error: ctx.error });
  }

  const parsed = z
    .object({ q: z.string().trim().max(120).optional() })
    .safeParse(req.query);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Parametro q invalido' });
  }

  const q = parsed.data.q ? `%${parsed.data.q}%` : '%';

  try {
    const rows = await withDb(ctx.role, ctx.vetId, async (client) => {
      if (ctx.role === 'vet') {
        const result = await client.query(
          'SELECT id, nombre, especie FROM mascotas WHERE nombre ILIKE $1 ORDER BY id',
          [q]
        );
        return result.rows;
      }

      const result = await client.query(
        `SELECT m.id, m.nombre, m.especie,
                d.nombre AS dueno_nombre,
                d.telefono
         FROM mascotas m
         JOIN duenos d ON d.id = m.dueno_id
         WHERE m.nombre ILIKE $1
         ORDER BY m.id`,
        [q]
      );
      return result.rows;
    });

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
});

app.get('/vacunacion-pendiente', async (req, res, next) => {
  const ctx = getContext(req);
  if (ctx.error) {
    return res.status(400).json({ error: ctx.error });
  }

  const key =
    ctx.role === 'vet'
      ? `vacunacion_pendiente:vet:${ctx.vetId}`
      : `vacunacion_pendiente:${ctx.role}`;

  try {
    const cached = await getCache(key);
    if (cached) {
      console.log('[CACHE HIT] vacunacion_pendiente');
      return res.json({ data: JSON.parse(cached), cache: 'HIT' });
    }

    console.log('[CACHE MISS] vacunacion_pendiente');
    const rows = await withDb(ctx.role, ctx.vetId, async (client) => {
      const result = await client.query(
        'SELECT * FROM v_mascotas_vacunacion_pendiente ORDER BY mascota_id, vacuna_id'
      );
      return result.rows;
    });

    await setCache(key, JSON.stringify(rows), config.cacheTtlSeconds);
    res.json({ data: rows, cache: 'MISS' });
  } catch (err) {
    next(err);
  }
});

app.post('/vacunas/aplicar', async (req, res, next) => {
  const ctx = getContext(req);
  if (ctx.error) {
    return res.status(400).json({ error: ctx.error });
  }

  const schema = z.object({
    mascota_id: z.coerce.number().int().positive(),
    vacuna_id: z.coerce.number().int().positive(),
    veterinario_id: z.coerce.number().int().positive().optional(),
    costo_cobrado: z.coerce.number().min(0).optional()
  });

  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Body invalido' });
  }

  const payload = parsed.data;
  const vetId = ctx.role === 'vet' ? ctx.vetId : payload.veterinario_id;
  if (!vetId) {
    return res.status(400).json({ error: 'veterinario_id requerido' });
  }

  try {
    await withDb(ctx.role, ctx.vetId, async (client) => {
      const insert = await client.query(
        `INSERT INTO vacunas_aplicadas
         (mascota_id, vacuna_id, veterinario_id, costo_cobrado)
         VALUES ($1, $2, $3, $4)
         RETURNING id` ,
        [payload.mascota_id, payload.vacuna_id, vetId, payload.costo_cobrado || null]
      );
      return insert.rows[0];
    });

    try {
      await deleteByPrefix('vacunacion_pendiente:');
    } catch (cacheErr) {
      console.error('[CACHE INVALIDATION ERROR]', cacheErr.message);
    }

    res.status(201).json({ ok: true });
  } catch (err) {
    next(err);
  }
});

app.post('/citas/agendar', async (req, res, next) => {
  const ctx = getContext(req);
  if (ctx.error) {
    return res.status(400).json({ error: ctx.error });
  }

  const schema = z.object({
    mascota_id: z.coerce.number().int().positive(),
    veterinario_id: z.coerce.number().int().positive().optional(),
    fecha_hora: z.string().min(10),
    motivo: z.string().trim().min(3).max(500)
  });

  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Body invalido' });
  }

  const payload = parsed.data;
  const vetId = ctx.role === 'vet' ? ctx.vetId : payload.veterinario_id;
  if (!vetId) {
    return res.status(400).json({ error: 'veterinario_id requerido' });
  }

  try {
    await withDb(ctx.role, ctx.vetId, async (client) => {
      await client.query(
        `INSERT INTO citas
         (mascota_id, veterinario_id, fecha_hora, motivo)
         VALUES ($1, $2, $3::TIMESTAMP, $4)`,
        [payload.mascota_id, vetId, payload.fecha_hora, payload.motivo]
      );
      return null;
    });

    res.status(201).json({ ok: true });
  } catch (err) {
    next(err);
  }
});

app.use((err, req, res, next) => {
  console.error('[API ERROR]', err.message);
  res.status(500).json({ error: 'internal_server_error' });
});

initRedis()
  .then(() => {
    app.listen(config.port, () => {
      console.log(`API escuchando en http://localhost:${config.port}`);
    });
  })
  .catch((err) => {
    console.error('No se pudo iniciar Redis', err.message);
    process.exit(1);
  });
