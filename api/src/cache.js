const { createClient } = require('redis');
const { config } = require('./config');

const client = createClient({ url: config.redis.url });

client.on('error', (err) => {
  console.error('[REDIS ERROR]', err.message);
});

async function initRedis() {
  if (!client.isOpen) {
    await client.connect();
  }
}

async function getCache(key) {
  return client.get(key);
}

async function setCache(key, value, ttlSeconds) {
  await client.set(key, value, { EX: ttlSeconds });
}

async function deleteByPrefix(prefix) {
  const keys = await client.keys(`${prefix}*`);
  if (keys.length > 0) {
    await client.del(keys);
  }
}

module.exports = {
  initRedis,
  getCache,
  setCache,
  deleteByPrefix
};
