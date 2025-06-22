import type { Config } from '@strapi/strapi';

const config: Config = {
  connection: {
    client: 'postgres',
    connection: {
      host: process.env.DATABASE_HOST || 'localhost',
      port: parseInt(process.env.DATABASE_PORT || '5432', 10),
      database: process.env.DATABASE_NAME || 'strapi',
      user: process.env.DATABASE_USERNAME || 'strapi',
      password: process.env.DATABASE_PASSWORD || 'strapi',
      ssl: process.env.NODE_ENV === 'production' ? {
        rejectUnauthorized: false
      } : false,
      schema: 'public',
    },
    debug: process.env.NODE_ENV === 'development',
    acquireConnectionTimeout: 60000,
    pool: {
      min: 2,
      max: 10,
      acquireTimeoutMillis: 60000,
      createTimeoutMillis: 30000,
      destroyTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      reapIntervalMillis: 1000,
      createRetryIntervalMillis: 200,
    },
  },
  settings: {
    forceMigration: process.env.NODE_ENV === 'development',
    runMigrations: true,
  },
};

export default config;
