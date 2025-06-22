// tests/load/api-load.js - Tests de carga con k6

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Métricas personalizadas
export const errorRate = new Rate('errors');

// Configuración del test
export const options = {
    stages: [
        { duration: '30s', target: 10 },   // Ramp up a 10 usuarios
        { duration: '1m', target: 20 },    // Mantener 20 usuarios
        { duration: '30s', target: 50 },   // Pico de 50 usuarios
        { duration: '1m', target: 50 },    // Mantener pico
        { duration: '30s', target: 0 },    // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% de requests < 500ms
        http_req_failed: ['rate<0.1'],    // Error rate < 10%
        errors: ['rate<0.1'],
    },
};

// URL base de la API
const BASE_URL = __ENV.BASE_URL || 'http://localhost:1337';

// Datos de prueba
const testUsers = [
    { email: 'user1@test.com', password: 'TestPassword123!' },
    { email: 'user2@test.com', password: 'TestPassword123!' },
    { email: 'user3@test.com', password: 'TestPassword123!' },
];

/**
 * Setup: Ejecutar antes de iniciar el test
 */
export function setup() {
    console.log('Iniciando setup del test de carga...');

    // Verificar que la API esté disponible
    const healthCheck = http.get(`${BASE_URL}/_health`);
    check(healthCheck, {
        'API está disponible': (r) => r.status === 200,
    });

    // Crear usuarios de prueba
    const createdUsers = [];

    for (const userData of testUsers) {
        const registerResponse = http.post(`${BASE_URL}/api/auth/local/register`, {
            username: userData.email.split('@')[0],
            email: userData.email,
            password: userData.password,
        });

        if (registerResponse.status === 200) {
            const user = JSON.parse(registerResponse.body);
            createdUsers.push({
                id: user.user.id,
                email: userData.email,
                password: userData.password,
                jwt: user.jwt,
            });
        }
    }

    console.log(`${createdUsers.length} usuarios de prueba creados`);
    return { users: createdUsers };
}

/**
 * Test principal
 */
export default function (data) {
    const user = data.users[Math.floor(Math.random() * data.users.length)];

    // Test 1: Health check
    testHealthCheck();

    // Test 2: Autenticación
    const authToken = testAuthentication(user);

    // Test 3: API pública
    testPublicEndpoints();

    // Test 4: API autenticada
    if (authToken) {
        testAuthenticatedEndpoints(authToken);
    }

    // Test 5: Operaciones CRUD
    if (authToken) {
        testCrudOperations(authToken);
    }

    sleep(1);
}

/**
 * Test de health check
 */
function testHealthCheck() {
    const response = http.get(`${BASE_URL}/_health`);

    const success = check(response, {
        'Health check status 200': (r) => r.status === 200,
        'Health check response time < 100ms': (r) => r.timings.duration < 100,
    });

    errorRate.add(!success);
}

/**
 * Test de autenticación
 */
function testAuthentication(user) {
    const loginData = {
        identifier: user.email,
        password: user.password,
    };

    const response = http.post(`${BASE_URL}/api/auth/local`, loginData, {
        headers: { 'Content-Type': 'application/json' },
    });

    const success = check(response, {
        'Login status 200': (r) => r.status === 200,
        'Login response time < 300ms': (r) => r.timings.duration < 300,
        'Login returns JWT': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.jwt !== undefined;
            } catch (e) {
                return false;
            }
        },
    });

    errorRate.add(!success);

    if (success && response.status === 200) {
        try {
            const body = JSON.parse(response.body);
            return body.jwt;
        } catch (e) {
            return null;
        }
    }

    return null;
}

/**
 * Test de endpoints públicos
 */
function testPublicEndpoints() {
    // Test del endpoint de documentación
    const docsResponse = http.get(`${BASE_URL}/documentation`);
    check(docsResponse, {
        'Docs accessible': (r) => r.status === 200 || r.status === 404, // 404 es OK si no está habilitado
    });

    // Test de endpoints de API públicos
    const apiResponse = http.get(`${BASE_URL}/api`);
    check(apiResponse, {
        'API root accessible': (r) => r.status === 200 || r.status === 404,
    });
}

/**
 * Test de endpoints autenticados
 */
function testAuthenticatedEndpoints(token) {
    const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
    };

    // Test del perfil de usuario
    const profileResponse = http.get(`${BASE_URL}/api/users/me`, { headers });

    const success = check(profileResponse, {
        'Profile status 200': (r) => r.status === 200,
        'Profile response time < 200ms': (r) => r.timings.duration < 200,
        'Profile returns user data': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.id !== undefined;
            } catch (e) {
                return false;
            }
        },
    });

    errorRate.add(!success);
}

/**
 * Test de operaciones CRUD
 */
function testCrudOperations(token) {
    const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
    };

    // Intentar obtener una lista de contenido (si existe algún content type)
    const contentTypes = ['articles', 'posts', 'pages', 'blogs'];

    for (const contentType of contentTypes) {
        const listResponse = http.get(`${BASE_URL}/api/${contentType}`, { headers });

        if (listResponse.status === 200) {
            check(listResponse, {
                [`${contentType} list accessible`]: (r) => r.status === 200,
                [`${contentType} response time < 300ms`]: (r) => r.timings.duration < 300,
            });

            // Si podemos obtener la lista, intentar crear contenido
            const createData = {
                data: {
                    title: `Test ${contentType} ${Date.now()}`,
                    content: 'Contenido de prueba para test de carga',
                    published: false,
                },
            };

            const createResponse = http.post(`${BASE_URL}/api/${contentType}`, JSON.stringify(createData), { headers });

            check(createResponse, {
                [`${contentType} create status acceptable`]: (r) => r.status === 200 || r.status === 201 || r.status === 403,
            });

            break; // Solo probar con el primer content type que funcione
        }
    }
}

/**
 * Teardown: Ejecutar después del test
 */
export function teardown(data) {
    console.log('Ejecutando teardown del test de carga...');

    // Limpiar usuarios de prueba creados
    if (data.users) {
        for (const user of data.users) {
            if (user.jwt) {
                const deleteResponse = http.del(`${BASE_URL}/api/users/${user.id}`, null, {
                    headers: { 'Authorization': `Bearer ${user.jwt}` },
                });

                if (deleteResponse.status === 200) {
                    console.log(`Usuario ${user.email} eliminado`);
                }
            }
        }
    }

    console.log('Teardown completado');
}
