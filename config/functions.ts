import type { Core } from '@strapi/strapi';

export default {
  /**
   * An asynchronous register function that runs before
   * your application is initialized.
   *
   * This gives you an opportunity to extend code.
   */
  register({ strapi }: { strapi: Core.Strapi }) {
    // Registrar extensiones personalizadas
    console.log('🚀 Registrando extensiones personalizadas...');

    // Ejemplo: Extender el controlador de usuarios
    strapi.controllers['plugin::users-permissions.user'] = {
      ...strapi.controllers['plugin::users-permissions.user'],
      
      // Método personalizado para obtener perfil extendido
      async getProfile(ctx) {
        const { id } = ctx.state.user;
        
        try {
          const user = await strapi
            .query('plugin::users-permissions.user')
            .findOne({
              where: { id },
              populate: ['role'],
            });

          if (!user) {
            return ctx.notFound('Usuario no encontrado');
          }

          // Remover información sensible
          delete user.password;
          delete user.resetPasswordToken;
          delete user.confirmationToken;

          ctx.send({ user });
        } catch (error) {
          console.error('Error obteniendo perfil:', error);
          ctx.internalServerError('Error interno del servidor');
        }
      },
    };

    // Ejemplo: Registrar webhook personalizado
    strapi.server.routes([
      {
        method: 'GET',
        path: '/api/users/profile',
        handler: 'plugin::users-permissions.user.getProfile',
        config: {
          middlewares: ['plugin::users-permissions.rateLimit'],
          policies: ['plugin::users-permissions.permissions'],
        },
      },
    ]);

    console.log('✅ Extensiones registradas correctamente');
  },

  /**
   * An asynchronous bootstrap function that runs before
   * your application gets started.
   *
   * This gives you an opportunity to set up your data model,
   * run jobs, or perform some special logic.
   */
  async bootstrap({ strapi }: { strapi: Core.Strapi }) {
    console.log('🏁 Iniciando bootstrap de la aplicación...');

    try {
      // Configurar roles y permisos por defecto
      await setupDefaultRolesAndPermissions(strapi);

      // Configurar webhooks por defecto
      await setupDefaultWebhooks(strapi);

      // Configurar configuraciones de i18n
      await setupI18nConfig(strapi);

      // Configurar tareas programadas
      await setupScheduledJobs(strapi);

      // Verificar configuración de la aplicación
      await verifyApplicationConfig(strapi);

      console.log('✅ Bootstrap completado exitosamente');
    } catch (error) {
      console.error('❌ Error durante el bootstrap:', error);
      // No lanzar el error para evitar que la aplicación no inicie
    }
  },
};

/**
 * Configurar roles y permisos por defecto
 */
async function setupDefaultRolesAndPermissions(strapi: Core.Strapi) {
  console.log('🔐 Configurando roles y permisos por defecto...');

  try {
    // Verificar que existan los roles básicos
    const publicRole = await strapi
      .query('plugin::users-permissions.role')
      .findOne({ where: { type: 'public' } });

    const authenticatedRole = await strapi
      .query('plugin::users-permissions.role')
      .findOne({ where: { type: 'authenticated' } });

    if (!publicRole) {
      await strapi
        .query('plugin::users-permissions.role')
        .create({
          data: {
            name: 'Public',
            description: 'Default role given to unauthenticated users.',
            type: 'public',
          },
        });
      console.log('✅ Rol público creado');
    }

    if (!authenticatedRole) {
      await strapi
        .query('plugin::users-permissions.role')
        .create({
          data: {
            name: 'Authenticated',
            description: 'Default role given to authenticated users.',
            type: 'authenticated',
          },
        });
      console.log('✅ Rol autenticado creado');
    }

    console.log('✅ Roles y permisos configurados');
  } catch (error) {
    console.error('❌ Error configurando roles:', error);
  }
}

/**
 * Configurar webhooks por defecto
 */
async function setupDefaultWebhooks(strapi: Core.Strapi) {
  console.log('🔗 Configurando webhooks por defecto...');

  try {
    // Webhook para notificaciones de contenido
    const existingWebhook = await strapi
      .query('webhook')
      .findOne({ where: { name: 'Content Notifications' } });

    if (!existingWebhook && process.env.WEBHOOK_URL) {
      await strapi
        .query('webhook')
        .create({
          data: {
            name: 'Content Notifications',
            url: process.env.WEBHOOK_URL,
            headers: {
              'Authorization': `Bearer ${process.env.WEBHOOK_TOKEN || 'default-token'}`,
              'Content-Type': 'application/json',
            },
            events: [
              'entry.create',
              'entry.update',
              'entry.delete',
              'entry.publish',
              'entry.unpublish',
            ],
            enabled: true,
          },
        });
      console.log('✅ Webhook de notificaciones creado');
    }

    console.log('✅ Webhooks configurados');
  } catch (error) {
    console.error('❌ Error configurando webhooks:', error);
  }
}

/**
 * Configurar i18n
 */
async function setupI18nConfig(strapi: Core.Strapi) {
  console.log('🌍 Configurando internacionalización...');

  try {
    if (strapi.plugins.i18n) {
      // Verificar idioma por defecto (español)
      const defaultLocale = await strapi
        .query('plugin::i18n.locale')
        .findOne({ where: { code: 'es' } });

      if (!defaultLocale) {
        await strapi
          .query('plugin::i18n.locale')
          .create({
            data: {
              name: 'Spanish (es)',
              code: 'es',
              isDefault: true,
            },
          });
        console.log('✅ Idioma español configurado como predeterminado');
      }

      // Verificar idioma inglés
      const englishLocale = await strapi
        .query('plugin::i18n.locale')
        .findOne({ where: { code: 'en' } });

      if (!englishLocale) {
        await strapi
          .query('plugin::i18n.locale')
          .create({
            data: {
              name: 'English (en)',
              code: 'en',
              isDefault: false,
            },
          });
        console.log('✅ Idioma inglés configurado');
      }
    }

    console.log('✅ Internacionalización configurada');
  } catch (error) {
    console.error('❌ Error configurando i18n:', error);
  }
}

/**
 * Configurar tareas programadas
 */
async function setupScheduledJobs(strapi: Core.Strapi) {
  console.log('⏰ Configurando tareas programadas...');

  try {
    // Ejemplo: Limpiar tokens expirados cada hora
    const cleanupInterval = setInterval(async () => {
      try {
        const expiredTokens = await strapi
          .query('plugin::users-permissions.user')
          .findMany({
            where: {
              resetPasswordToken: { $ne: null },
              // Tokens más antiguos a 24 horas
              updatedAt: { $lt: new Date(Date.now() - 24 * 60 * 60 * 1000) },
            },
          });

        if (expiredTokens.length > 0) {
          await strapi
            .query('plugin::users-permissions.user')
            .updateMany({
              where: {
                id: { $in: expiredTokens.map(token => token.id) },
              },
              data: {
                resetPasswordToken: null,
              },
            });
          
          console.log(`🧹 ${expiredTokens.length} tokens expirados limpiados`);
        }
      } catch (error) {
        console.error('❌ Error limpiando tokens:', error);
      }
    }, 60 * 60 * 1000); // Cada hora

    // Guardar referencia para poder limpiar más tarde
    strapi.scheduledJobs = strapi.scheduledJobs || [];
    strapi.scheduledJobs.push(cleanupInterval);

    console.log('✅ Tareas programadas configuradas');
  } catch (error) {
    console.error('❌ Error configurando tareas programadas:', error);
  }
}

/**
 * Verificar configuración de la aplicación
 */
async function verifyApplicationConfig(strapi: Core.Strapi) {
  console.log('🔍 Verificando configuración de la aplicación...');

  try {
    // Verificar conexión a la base de datos
    await strapi.db.query('plugin::users-permissions.role').findMany({
      limit: 1,
    });
    console.log('✅ Conexión a base de datos verificada');

    // Verificar configuración de uploads
    if (process.env.NODE_ENV === 'production' && process.env.UPLOAD_PROVIDER === 'local') {
      console.warn('⚠️  En producción se recomienda usar un proveedor de almacenamiento externo (AWS S3)');
    }

    // Verificar configuración de SMTP
    if (!process.env.SMTP_HOST && process.env.NODE_ENV === 'production') {
      console.warn('⚠️  SMTP no configurado para producción');
    }

    // Verificar configuración de seguridad
    if (process.env.NODE_ENV === 'production') {
      const requiredSecrets = ['APP_KEYS', 'JWT_SECRET', 'ADMIN_JWT_SECRET'];
      for (const secret of requiredSecrets) {
        if (!process.env[secret]) {
          console.warn(`⚠️  Variable de entorno requerida faltante: ${secret}`);
        }
      }
    }

    console.log('✅ Verificación de configuración completada');
  } catch (error) {
    console.error('❌ Error verificando configuración:', error);
  }
}
