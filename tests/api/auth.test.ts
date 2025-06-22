// tests/api/auth.test.ts - Tests para el sistema de autenticación

import request from 'supertest';

describe('Authentication API', () => {
  let app: any;

  beforeAll(() => {
    app = global.strapi.server.httpServer;
  });

  describe('POST /api/auth/local/register', () => {
    it('should register a new user successfully', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'TestPassword123!',
      };

      const response = await request(app)
        .post('/api/auth/local/register')
        .send(userData)
        .expect(200);

      expect(response.body.user).toBeDefined();
      expect(response.body.user.email).toBe(userData.email);
      expect(response.body.user.username).toBe(userData.username);
      expect(response.body.jwt).toBeDefined();
    });

    it('should fail with invalid email', async () => {
      const userData = {
        username: 'testuser2',
        email: 'invalid-email',
        password: 'TestPassword123!',
      };

      const response = await request(app)
        .post('/api/auth/local/register')
        .send(userData)
        .expect(400);

      expect(response.body.error).toBeDefined();
    });

    it('should fail with weak password', async () => {
      const userData = {
        username: 'testuser3',
        email: 'test3@example.com',
        password: '123',
      };

      const response = await request(app)
        .post('/api/auth/local/register')
        .send(userData)
        .expect(400);

      expect(response.body.error).toBeDefined();
    });
  });

  describe('POST /api/auth/local', () => {
    let testUser: any;

    beforeEach(async () => {
      // Crear usuario de prueba
      testUser = await global.strapi.plugins['users-permissions'].services.user.add({
        username: 'logintest',
        email: 'logintest@example.com',
        password: 'TestPassword123!',
        confirmed: true,
        blocked: false,
        provider: 'local',
        role: 1, // Authenticated role
      });
    });

    it('should login with valid credentials', async () => {
      const credentials = {
        identifier: 'logintest@example.com',
        password: 'TestPassword123!',
      };

      const response = await request(app)
        .post('/api/auth/local')
        .send(credentials)
        .expect(200);

      expect(response.body.user).toBeDefined();
      expect(response.body.user.email).toBe(credentials.identifier);
      expect(response.body.jwt).toBeDefined();
    });

    it('should fail with invalid credentials', async () => {
      const credentials = {
        identifier: 'logintest@example.com',
        password: 'WrongPassword',
      };

      const response = await request(app)
        .post('/api/auth/local')
        .send(credentials)
        .expect(400);

      expect(response.body.error).toBeDefined();
    });
  });

  describe('GET /api/users/me', () => {
    let authToken: string;
    let testUser: any;

    beforeEach(async () => {
      // Crear usuario y obtener token
      testUser = await global.strapi.plugins['users-permissions'].services.user.add({
        username: 'metest',
        email: 'metest@example.com',
        password: 'TestPassword123!',
        confirmed: true,
        blocked: false,
        provider: 'local',
        role: 1,
      });

      const loginResponse = await request(app)
        .post('/api/auth/local')
        .send({
          identifier: 'metest@example.com',
          password: 'TestPassword123!',
        });

      authToken = loginResponse.body.jwt;
    });

    it('should return user profile when authenticated', async () => {
      const response = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.id).toBe(testUser.id);
      expect(response.body.email).toBe('metest@example.com');
      expect(response.body.username).toBe('metest');
    });

    it('should fail without authentication token', async () => {
      const response = await request(app)
        .get('/api/users/me')
        .expect(401);

      expect(response.body.error).toBeDefined();
    });

    it('should fail with invalid token', async () => {
      const response = await request(app)
        .get('/api/users/me')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);

      expect(response.body.error).toBeDefined();
    });
  });
});
