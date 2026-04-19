const { Pool } = require('pg');
const { config } = require('./config');

const pools = {
  vet: new Pool({
    host: config.db.host,
    port: config.db.port,
    database: config.db.name,
    user: config.db.vetUser,
    password: config.db.vetPassword
  }),
  recepcion: new Pool({
    host: config.db.host,
    port: config.db.port,
    database: config.db.name,
    user: config.db.recepUser,
    password: config.db.recepPassword
  }),
  admin: new Pool({
    host: config.db.host,
    port: config.db.port,
    database: config.db.name,
    user: config.db.adminUser,
    password: config.db.adminPassword
  })
};

async function withDb(role, vetId, fn) {
  const pool = pools[role];
  if (!pool) {
    throw new Error(`Invalid role: ${role}`);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (role === 'vet') {
      await client.query('SELECT set_config($1, $2, true)', [
        'app.current_vet_id',
        String(vetId)
      ]);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { withDb };
