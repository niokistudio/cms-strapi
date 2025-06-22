// tests/setup.ts - Configuración global para Jest y tests de Strapi

import Strapi from '@strapi/strapi';

let instance: Strapi;

/**
 * Configuración global para tests
 */
beforeAll(async () => {
  if (!instance) {
    instance = await Strapi({
      // Configuración específica para testing
      env: {
        database: {
          client: 'better-sqlite3',
          connection: {
            filename: '.tmp/test.db',
          },
          useNullAsDefault: true,
        },
        server: {
          host: '127.0.0.1',
          port: 0, // Puerto aleatorio para evitar conflictos
        },
        admin: {
          auth: {
            secret: 'test-secret',
          },
        },
      },
      distDir: './dist',
      autoReload: false,
      serveAdminPanel: false,
    }).load();
  }

  global.strapi = instance;
});

/**
 * Limpieza después de todos los tests
 */
afterAll(async () => {
  if (instance) {
    await instance.destroy();
  }
});

/**
 * Configuración para cada test individual
 */
beforeEach(async () => {
  // Limpiar la base de datos antes de cada test
  if (global.strapi && global.strapi.db) {
    await global.strapi.db.query('plugin::users-permissions.user').deleteMany({});
    await global.strapi.db.query('plugin::users-permissions.role').deleteMany({});
  }
});

/**
 * Variables globales para TypeScript
 */
declare global {
  var strapi: Strapi;
}

export {};
