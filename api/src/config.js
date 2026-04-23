const dotenv = require('dotenv');

dotenv.config();

function required(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing env var: ${name}`);
  }
  return value;
}

const config = {
  port: Number(process.env.PORT || 4000),
  frontendOrigin: process.env.FRONTEND_ORIGIN,
  cacheTtlSeconds: Number(process.env.CACHE_TTL_SECONDS || 60),
  db: {
    host: required('DB_HOST'),
    port: Number(process.env.DB_PORT),
    name: required('DB_NAME'),
    vetUser: required('DB_VET_USER'),
    vetPassword: required('DB_VET_PASSWORD'),
    recepUser: required('DB_RECEP_USER'),
    recepPassword: required('DB_RECEP_PASSWORD'),
    adminUser: required('DB_ADMIN_USER'),
    adminPassword: required('DB_ADMIN_PASSWORD')
  },
  redis: {
    url: required('REDIS_URL')
  }
};

module.exports = { config };
