// tests/policies/custom-policy.test.ts - Test para una policy personalizada

describe('Custom Policy', () => {
  let policy: any;

  beforeAll(() => {
    // Cargar la policy desde Strapi
    policy = global.strapi.policy('global::custom-policy');
  });

  describe('isOwner policy', () => {
    let mockCtx: any;
    let mockNext: jest.Mock;
    let testUser: any;

    beforeEach(() => {
      mockNext = jest.fn();
      testUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
      };

      mockCtx = {
        state: {
          user: testUser,
        },
        params: {
          id: '1',
        },
        request: {
          body: {},
        },
        throw: jest.fn(),
      };
    });

    it('should allow access when user is owner', async () => {
      // Simular que el usuario es propietario del recurso
      mockCtx.params.id = testUser.id.toString();

      await policy(mockCtx, mockNext);

      expect(mockNext).toHaveBeenCalled();
      expect(mockCtx.throw).not.toHaveBeenCalled();
    });

    it('should deny access when user is not owner', async () => {
      // Simular que el usuario NO es propietario del recurso
      mockCtx.params.id = '999';

      await policy(mockCtx, mockNext);

      expect(mockNext).not.toHaveBeenCalled();
      expect(mockCtx.throw).toHaveBeenCalledWith(403, 'Forbidden');
    });

    it('should deny access when user is not authenticated', async () => {
      // Usuario no autenticado
      mockCtx.state.user = null;

      await policy(mockCtx, mockNext);

      expect(mockNext).not.toHaveBeenCalled();
      expect(mockCtx.throw).toHaveBeenCalledWith(401, 'Unauthorized');
    });

    it('should handle missing params gracefully', async () => {
      // ID faltante en params
      mockCtx.params = {};

      await policy(mockCtx, mockNext);

      expect(mockNext).not.toHaveBeenCalled();
      expect(mockCtx.throw).toHaveBeenCalledWith(400, 'Bad Request');
    });
  });

  describe('rateLimit policy', () => {
    let rateLimitPolicy: any;
    let mockCtx: any;
    let mockNext: jest.Mock;

    beforeEach(() => {
      rateLimitPolicy = global.strapi.policy('global::rate-limit');
      mockNext = jest.fn();
      
      mockCtx = {
        request: {
          ip: '127.0.0.1',
          headers: {
            'user-agent': 'test-agent',
          },
        },
        throw: jest.fn(),
      };
    });

    it('should allow request within rate limit', async () => {
      await rateLimitPolicy(mockCtx, mockNext);

      expect(mockNext).toHaveBeenCalled();
      expect(mockCtx.throw).not.toHaveBeenCalled();
    });

    it('should block request when rate limit exceeded', async () => {
      // Simular múltiples requests para superar el límite
      for (let i = 0; i < 101; i++) {
        await rateLimitPolicy(mockCtx, jest.fn());
      }

      await rateLimitPolicy(mockCtx, mockNext);

      expect(mockNext).not.toHaveBeenCalled();
      expect(mockCtx.throw).toHaveBeenCalledWith(429, 'Too Many Requests');
    });
  });
});
