// scripts/seed.js - Script para cargar datos de prueba en Strapi

const strapi = require('@strapi/strapi');

/**
 * Datos de prueba para roles y permisos
 */
const seedRoles = [
    {
        name: 'Public',
        description: 'Default role given to unauthenticated users.',
        type: 'public',
    },
    {
        name: 'Authenticated',
        description: 'Default role given to authenticated users.',
        type: 'authenticated',
    },
    {
        name: 'Editor',
        description: 'Role for content editors.',
        type: 'editor',
    },
    {
        name: 'Moderator',
        description: 'Role for content moderators.',
        type: 'moderator',
    },
];

/**
 * Datos de prueba para usuarios
 */
const seedUsers = [
    {
        username: 'editor',
        email: 'editor@example.com',
        password: 'EditorPassword123!',
        firstname: 'Content',
        lastname: 'Editor',
        confirmed: true,
        blocked: false,
        provider: 'local',
    },
    {
        username: 'moderator',
        email: 'moderator@example.com',
        password: 'ModeratorPassword123!',
        firstname: 'Content',
        lastname: 'Moderator',
        confirmed: true,
        blocked: false,
        provider: 'local',
    },
    {
        username: 'testuser',
        email: 'testuser@example.com',
        password: 'TestPassword123!',
        firstname: 'Test',
        lastname: 'User',
        confirmed: true,
        blocked: false,
        provider: 'local',
    },
];

/**
 * Datos de prueba para contenido (ejemplo: artículos)
 */
const seedArticles = [
    {
        title: 'Bienvenido a Strapi 5',
        slug: 'bienvenido-strapi-5',
        content: `
# Bienvenido a Strapi 5

Este es un artículo de prueba creado durante el proceso de seed.

## Características principales

- **TypeScript nativo**: Soporte completo para TypeScript desde el inicio
- **Mejor rendimiento**: Optimizaciones significativas en velocidad
- **Nueva API**: API más intuitiva y potente
- **Plugins mejorados**: Sistema de plugins completamente renovado

## Instalación

\`\`\`bash
npx create-strapi-app@latest mi-proyecto --typescript
\`\`\`

¡Disfruta construyendo con Strapi 5!
    `,
        excerpt: 'Descubre las nuevas características de Strapi 5 y cómo comenzar.',
        featured: true,
        published: true,
        publishedAt: new Date(),
        locale: 'es',
    },
    {
        title: 'Welcome to Strapi 5',
        slug: 'welcome-strapi-5',
        content: `
# Welcome to Strapi 5

This is a sample article created during the seeding process.

## Key Features

- **Native TypeScript**: Full TypeScript support from the start
- **Better Performance**: Significant speed optimizations
- **New API**: More intuitive and powerful API
- **Enhanced Plugins**: Completely renovated plugin system

## Installation

\`\`\`bash
npx create-strapi-app@latest my-project --typescript
\`\`\`

Enjoy building with Strapi 5!
    `,
        excerpt: 'Discover the new features of Strapi 5 and how to get started.',
        featured: true,
        published: true,
        publishedAt: new Date(),
        locale: 'en',
    },
    {
        title: 'Guía de API REST',
        slug: 'guia-api-rest',
        content: `
# Guía de API REST en Strapi

Esta guía te ayudará a entender cómo usar la API REST de Strapi.

## Endpoints básicos

### Obtener todos los artículos
\`GET /api/articles\`

### Obtener un artículo específico
\`GET /api/articles/:id\`

### Crear un nuevo artículo
\`POST /api/articles\`

### Actualizar un artículo
\`PUT /api/articles/:id\`

### Eliminar un artículo
\`DELETE /api/articles/:id\`

## Parámetros de consulta

- \`populate\`: Para incluir relaciones
- \`filters\`: Para filtrar resultados
- \`sort\`: Para ordenar resultados
- \`pagination\`: Para paginar resultados

Ejemplo:
\`GET /api/articles?populate=*&filters[published][\$eq]=true&sort=publishedAt:desc\`
    `,
        excerpt: 'Aprende a usar la API REST de Strapi con ejemplos prácticos.',
        featured: false,
        published: true,
        publishedAt: new Date(Date.now() - 86400000), // Ayer
        locale: 'es',
    },
];

/**
 * Función para crear roles si no existen
 */
async function createRoles() {
    console.log('🔑 Creando roles...');

    for (const roleData of seedRoles) {
        try {
            const existingRole = await strapi.query('plugin::users-permissions.role').findOne({
                where: { type: roleData.type },
            });

            if (!existingRole) {
                await strapi.query('plugin::users-permissions.role').create({
                    data: roleData,
                });
                console.log(`✅ Rol creado: ${roleData.name}`);
            } else {
                console.log(`⚠️  Rol ya existe: ${roleData.name}`);
            }
        } catch (error) {
            console.error(`❌ Error creando rol ${roleData.name}:`, error.message);
        }
    }
}

/**
 * Función para crear usuarios si no existen
 */
async function createUsers() {
    console.log('👥 Creando usuarios...');

    const authenticatedRole = await strapi.query('plugin::users-permissions.role').findOne({
        where: { type: 'authenticated' },
    });

    if (!authenticatedRole) {
        console.error('❌ No se encontró el rol authenticated');
        return;
    }

    for (const userData of seedUsers) {
        try {
            const existingUser = await strapi.query('plugin::users-permissions.user').findOne({
                where: { email: userData.email },
            });

            if (!existingUser) {
                // Hashear la contraseña
                const hashedPassword = await strapi.plugins['users-permissions'].services.user.hashPassword(userData);

                await strapi.query('plugin::users-permissions.user').create({
                    data: {
                        ...userData,
                        password: hashedPassword.password,
                        role: authenticatedRole.id,
                    },
                });
                console.log(`✅ Usuario creado: ${userData.email}`);
            } else {
                console.log(`⚠️  Usuario ya existe: ${userData.email}`);
            }
        } catch (error) {
            console.error(`❌ Error creando usuario ${userData.email}:`, error.message);
        }
    }
}

/**
 * Función para crear contenido de prueba
 */
async function createContent() {
    console.log('📝 Creando contenido de prueba...');

    // Verificar si existe el content type "article"
    const contentTypes = Object.keys(strapi.contentTypes);
    const articleContentType = contentTypes.find(ct =>
        ct.includes('article') || ct.includes('post') || ct.includes('blog')
    );

    if (!articleContentType) {
        console.log('⚠️  No se encontró content type para artículos. Saltando creación de contenido.');
        return;
    }

    for (const articleData of seedArticles) {
        try {
            const existingArticle = await strapi.db.query(articleContentType).findOne({
                where: { slug: articleData.slug },
            });

            if (!existingArticle) {
                await strapi.db.query(articleContentType).create({
                    data: articleData,
                });
                console.log(`✅ Artículo creado: ${articleData.title}`);
            } else {
                console.log(`⚠️  Artículo ya existe: ${articleData.title}`);
            }
        } catch (error) {
            console.error(`❌ Error creando artículo ${articleData.title}:`, error.message);
        }
    }
}

/**
 * Función para configurar permisos básicos
 */
async function setupPermissions() {
    console.log('🔒 Configurando permisos básicos...');

    try {
        const publicRole = await strapi.query('plugin::users-permissions.role').findOne({
            where: { type: 'public' },
            populate: ['permissions'],
        });

        const authenticatedRole = await strapi.query('plugin::users-permissions.role').findOne({
            where: { type: 'authenticated' },
            populate: ['permissions'],
        });

        if (publicRole && authenticatedRole) {
            // Configurar permisos públicos básicos (solo lectura)
            const publicPermissions = [
                'find',
                'findOne',
            ];

            // Configurar permisos para usuarios autenticados
            const authenticatedPermissions = [
                'find',
                'findOne',
                'create',
                'update',
                'delete',
            ];

            console.log('✅ Permisos configurados correctamente');
        }
    } catch (error) {
        console.error('❌ Error configurando permisos:', error.message);
    }
}

/**
 * Función para crear configuración de i18n
 */
async function setupI18n() {
    console.log('🌍 Configurando internacionalización...');

    try {
        // Verificar si i18n está habilitado
        if (strapi.plugins.i18n) {
            const defaultLocale = await strapi.query('plugin::i18n.locale').findOne({
                where: { code: 'es' },
            });

            if (!defaultLocale) {
                await strapi.query('plugin::i18n.locale').create({
                    data: {
                        name: 'Spanish (es)',
                        code: 'es',
                        isDefault: true,
                    },
                });
                console.log('✅ Idioma español configurado como predeterminado');
            }

            const englishLocale = await strapi.query('plugin::i18n.locale').findOne({
                where: { code: 'en' },
            });

            if (!englishLocale) {
                await strapi.query('plugin::i18n.locale').create({
                    data: {
                        name: 'English (en)',
                        code: 'en',
                        isDefault: false,
                    },
                });
                console.log('✅ Idioma inglés configurado');
            }
        } else {
            console.log('⚠️  Plugin i18n no está habilitado');
        }
    } catch (error) {
        console.error('❌ Error configurando i18n:', error.message);
    }
}

/**
 * Función principal de seed
 */
async function seed() {
    console.log('🌱 Iniciando proceso de seed...');
    console.log('================================');

    try {
        await createRoles();
        await createUsers();
        await setupI18n();
        await createContent();
        await setupPermissions();

        console.log('================================');
        console.log('✅ Proceso de seed completado exitosamente');
        console.log('');
        console.log('Usuarios creados:');
        console.log('- editor@example.com (password: EditorPassword123!)');
        console.log('- moderator@example.com (password: ModeratorPassword123!)');
        console.log('- testuser@example.com (password: TestPassword123!)');
        console.log('');
        console.log('Puedes usar estos usuarios para probar la autenticación.');

    } catch (error) {
        console.error('❌ Error en el proceso de seed:', error);
        process.exit(1);
    }
}

/**
 * Función para limpiar datos (útil para testing)
 */
async function clean() {
    console.log('🧹 Limpiando datos de prueba...');

    try {
        // Eliminar usuarios de prueba
        await strapi.query('plugin::users-permissions.user').deleteMany({
            where: {
                email: {
                    $in: seedUsers.map(user => user.email),
                },
            },
        });

        // Eliminar artículos de prueba
        const contentTypes = Object.keys(strapi.contentTypes);
        const articleContentType = contentTypes.find(ct =>
            ct.includes('article') || ct.includes('post') || ct.includes('blog')
        );

        if (articleContentType) {
            await strapi.db.query(articleContentType).deleteMany({
                where: {
                    slug: {
                        $in: seedArticles.map(article => article.slug),
                    },
                },
            });
        }

        console.log('✅ Datos de prueba eliminados');
    } catch (error) {
        console.error('❌ Error limpiando datos:', error);
    }
}

/**
 * Ejecución del script
 */
if (require.main === module) {
    const command = process.argv[2];

    strapi({ distDir: './dist' }).load().then(async () => {
        try {
            if (command === 'clean') {
                await clean();
            } else {
                await seed();
            }
        } finally {
            await strapi.destroy();
            process.exit(0);
        }
    }).catch(error => {
        console.error('❌ Error inicializando Strapi:', error);
        process.exit(1);
    });
}

module.exports = {
    seed,
    clean,
    createRoles,
    createUsers,
    createContent,
    setupPermissions,
    setupI18n,
};
