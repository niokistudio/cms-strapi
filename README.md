# CMS Strapi 5 - Plantilla DevOps

Plantilla completa para proyectos Strapi 5 con PostgreSQL, Docker y configuración para AWS ECS/Kubernetes.

## 🚀 Inicio Rápido

### Prerrequisitos
- Docker y Docker Compose
- Node.js 18+ (para desarrollo local)
- Make (opcional, facilita comandos)

### Configuración Inicial

1. **Clona y configura el proyecto:**
   ```bash
   git clone <repository-url> cms-strapi
   cd cms-strapi
   ```

2. **Configura variables de entorno:**
   ```bash
   cp .env.example .env
   # Edita .env con tus valores específicos
   ```

3. **Inicia el proyecto:**
   ```bash
   make setup    # Configura el proyecto inicial
   make start    # Inicia todos los servicios
   ```

4. **Accede a las interfaces:**
   - Strapi Admin: http://localhost:1337/admin
   - API: http://localhost:1337/api
   - Adminer (DB): http://localhost:8080

## 📁 Estructura del Proyecto

```
cms-strapi/
├── cms/                    # Código fuente de Strapi
│   ├── src/
│   │   ├── api/           # Controladores y rutas
│   │   ├── components/    # Componentes reutilizables
│   │   ├── extensions/    # Extensiones de plugins
│   │   ├── middlewares/   # Middlewares personalizados
│   │   └── policies/      # Políticas de autorización
│   ├── config/            # Configuraciones de Strapi
│   │   ├── env/           # Configuraciones por entorno
│   │   ├── database.ts    # Configuración de base de datos
│   │   └── plugins.ts     # Configuración de plugins
│   └── package.json
├── ci/                    # Configuración CI/CD
├── scripts/               # Scripts de utilidades
├── tests/                 # Tests automatizados
├── uploads/               # Archivos subidos (desarrollo)
├── backups/               # Backups de base de datos
├── docker-compose.yml     # Servicios Docker
├── Dockerfile            # Imagen Docker de Strapi
├── Makefile              # Comandos automatizados
└── .env.example          # Variables de entorno de ejemplo
```

## 🛠️ Comandos Disponibles

### Make Commands
```bash
make setup      # Configuración inicial completa
make start      # Inicia todos los servicios
make stop       # Detiene todos los servicios
make restart    # Reinicia todos los servicios
make logs       # Muestra logs de todos los servicios
make shell      # Accede al contenedor de Strapi
make migrate    # Ejecuta migraciones de base de datos
make seed       # Carga datos de prueba
make backup-db  # Crea backup de la base de datos
make restore-db # Restaura backup de base de datos
make clean      # Limpia contenedores e imágenes
```

### npm/yarn Scripts (dentro de cms/)
```bash
npm run setup           # Instalación y build inicial
npm run dev            # Desarrollo con hot-reload
npm run build          # Build para producción
npm run start          # Inicio en modo producción
npm run lint           # Análisis de código
npm run test           # Ejecuta tests
npm run strapi:console # Consola interactiva de Strapi
```

## 🔧 Configuración de Desarrollo

### Crear un Content Type

1. **Vía Admin Panel:**
   - Accede a http://localhost:1337/admin
   - Ve a Content-Type Builder
   - Crea tu nuevo content type

2. **Vía CLI:**
   ```bash
   make shell
   npm run strapi generate
   ```

### Crear un Plugin Personalizado

```bash
make shell
cd /opt/app
npm run strapi generate:plugin mi-plugin
```

### Configurar Roles y Permisos

```javascript
// cms/config/plugins.ts
export default {
  'users-permissions': {
    config: {
      jwtSecret: env('JWT_SECRET'),
      register: {
        allowedFields: ['firstname', 'lastname', 'phone'],
      },
    },
  },
};
```

### Internacionalización (i18n)

El proyecto incluye soporte para múltiples idiomas:

```javascript
// cms/config/plugins.ts
export default {
  i18n: {
    enabled: true,
    config: {
      defaultLocale: 'es',
      locales: ['es', 'en'],
    },
  },
};
```

## 🔐 Configuración de Seguridad

### Variables de Entorno Críticas

```bash
# Generar claves seguras
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# En .env
APP_KEYS="key1,key2,key3,key4"
JWT_SECRET="tu-jwt-secret"
ADMIN_JWT_SECRET="tu-admin-jwt-secret"
```

### Rate Limiting

```javascript
// cms/config/middlewares.ts
export default [
  // ... otros middlewares
  {
    name: 'strapi::rate-limit',
    config: {
      max: 100,
      duration: 60000,
    },
  },
];
```

### CORS Configuration

```javascript
// cms/config/middlewares.ts
export default [
  {
    name: 'strapi::cors',
    config: {
      origin: process.env.FRONTEND_URL?.split(',') || ['http://localhost:3000'],
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
      headers: ['Content-Type', 'Authorization', 'Origin', 'Accept'],
    },
  },
];
```

## 🗄️ Base de Datos

### Migraciones

```bash
# Aplicar migraciones
make migrate

# Crear migración personalizada
make shell
npm run strapi:ts
```

### Backups

```bash
# Backup manual
make backup-db

# Backup automático (configurado en docker-compose)
# Se ejecuta diariamente a las 2 AM
```

### Seeds/Datos de Prueba

```bash
# Cargar datos de prueba
make seed

# Crear seed personalizado
# Edita scripts/seed.js
```

## 📦 Plugins del Marketplace

### Instalación de Plugins

```bash
# Plugin de Upload a S3
npm install @strapi/provider-upload-aws-s3

# Plugin de GraphQL
npm install @strapi/plugin-graphql

# Plugin de SSO
npm install strapi-plugin-oidc
```

### Configuración de Plugins

```javascript
// cms/config/plugins.ts
export default {
  // Upload a S3 (producción)
  upload: {
    config: {
      provider: process.env.UPLOAD_PROVIDER || 'local',
      providerOptions: {
        s3Options: {
          accessKeyId: env('AWS_ACCESS_KEY_ID'),
          secretAccessKey: env('AWS_SECRET_ACCESS_KEY'),
          region: env('AWS_REGION'),
          params: {
            Bucket: env('AWS_S3_BUCKET'),
          },
        },
      },
    },
  },
  
  // GraphQL
  graphql: {
    config: {
      endpoint: '/graphql',
      shadowCRUD: true,
      playgroundAlways: false,
      depthLimit: 7,
    },
  },
};
```

## 🚀 Despliegue

### Desarrollo
```bash
docker-compose up -d
```

### Producción con Docker

```bash
# Build de imagen de producción
docker build --target production -t cms-strapi:latest .

# Despliegue con variables de entorno de producción
docker run -d \
  --name cms-strapi-prod \
  -p 1337:1337 \
  --env-file .env.production \
  cms-strapi:latest
```

### AWS ECS Fargate

```json
// ecs-task-definition.json
{
  "family": "cms-strapi",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [{
    "name": "strapi",
    "image": "your-registry/cms-strapi:latest",
    "portMappings": [{
      "containerPort": 1337,
      "protocol": "tcp"
    }],
    "environment": [
      {"name": "NODE_ENV", "value": "production"},
      {"name": "DATABASE_SSL", "value": "true"}
    ],
    "secrets": [
      {"name": "DATABASE_PASSWORD", "valueFrom": "arn:aws:secretsmanager:..."}
    ]
  }]
}
```

### Kubernetes

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cms-strapi
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cms-strapi
  template:
    metadata:
      labels:
        app: cms-strapi
    spec:
      containers:
      - name: strapi
        image: your-registry/cms-strapi:latest
        ports:
        - containerPort: 1337
        env:
        - name: NODE_ENV
          value: "production"
        envFrom:
        - secretRef:
            name: strapi-secrets
```

## 🧪 Testing

### Tests Unitarios

```bash
# Ejecutar todos los tests
npm test

# Tests con coverage
npm run test:coverage

# Tests en modo watch
npm run test:watch
```

### Tests de API

```javascript
// tests/api/auth.test.js
describe('Authentication API', () => {
  test('should register a new user', async () => {
    const response = await request(strapi.server.httpServer)
      .post('/api/auth/local/register')
      .send({
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123'
      });
    
    expect(response.status).toBe(200);
    expect(response.body.user).toBeDefined();
  });
});
```

### Pruebas de Carga

```bash
# Con k6
k6 run tests/load/api-load.js

# Con Artillery
artillery run tests/load/api-artillery.yml
```

## 📊 Observabilidad

### Logging

```javascript
// cms/config/logger.ts
export default {
  transports: [
    new winston.transports.Console({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.json(),
    }),
  ],
};
```

### Monitoreo

```javascript
// cms/config/middlewares.ts
export default [
  // Health check endpoint
  {
    name: 'strapi::health',
    config: {
      enabled: true,
    },
  },
];
```

### Métricas con Prometheus

```javascript
// cms/src/middlewares/metrics.ts
export default () => {
  return async (ctx, next) => {
    const start = Date.now();
    await next();
    const duration = Date.now() - start;
    
    // Enviar métricas a Prometheus
    httpRequestDuration.observe(
      { method: ctx.method, route: ctx.route?.path || 'unknown' },
      duration / 1000
    );
  };
};
```

## 🔄 Actualizaciones

### Actualizar Strapi

```bash
# Verificar versiones disponibles
npm outdated "@strapi/*"

# Actualizar a última versión menor
npm update "@strapi/*"

# Actualizar a nueva versión mayor (cuidado!)
npm install @strapi/strapi@latest
npm run build

# Ejecutar migraciones si es necesario
npm run strapi:migrate
```

### Migración de Versión Mayor

1. **Backup completo:**
   ```bash
   make backup-db
   cp -r cms cms-backup
   ```

2. **Revisar changelog de Strapi**

3. **Actualizar dependencias:**
   ```bash
   npm install @strapi/strapi@5.x.x
   ```

4. **Ejecutar codemods si están disponibles:**
   ```bash
   npx @strapi/codemods
   ```

5. **Testing exhaustivo**

## ❓ FAQ

### ¿Cómo resetear la contraseña de admin?

```bash
make shell
npm run strapi admin:reset-user-password --email=admin@example.com
```

### ¿Cómo habilitar modo debug?

```bash
# En .env
LOG_LEVEL=debug
NODE_ENV=development
```

### ¿Cómo configurar HTTPS en desarrollo?

```bash
# Usar proxy reverso con nginx o configurar certificados SSL
# Ver documentación en docs/ssl-setup.md
```

### ¿Cómo escalar horizontalmente?

```bash
# Con Docker Swarm
docker service create --replicas 3 cms-strapi:latest

# Con Kubernetes
kubectl scale deployment cms-strapi --replicas=3
```

### ¿Cómo configurar cache Redis?

```javascript
// cms/config/database.ts
export default {
  connection: {
    // ... configuración PostgreSQL
  },
  pool: {
    min: 2,
    max: 10,
  },
  // Configuración de cache
  cache: {
    provider: 'redis',
    options: {
      host: process.env.REDIS_HOST || 'localhost',
      port: process.env.REDIS_PORT || 6379,
    },
  },
};
```

## 🤝 Contribución

1. Fork del proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver `LICENSE` para más detalles.

## 🆘 Soporte

- **Documentación oficial**: [Strapi 5 Documentation](https://strapi.io/documentation)
- **Issues del proyecto**: [GitHub Issues](link-to-issues)
- **Discord de Strapi**: [Strapi Discord](https://discord.strapi.io)

---

**Nota**: Esta plantilla está optimizada para Strapi 5.16.0+. Para versiones anteriores, revisa las ramas correspondientes del repositorio.
