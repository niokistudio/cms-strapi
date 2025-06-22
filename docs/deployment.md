# ==================================================================
# DOCUMENTACIÓN DE DESPLIEGUE
# ==================================================================

## Despliegue en AWS ECS Fargate

### 1. Preparación del entorno

```bash
# Instalar AWS CLI
aws configure

# Crear repositorio ECR
aws ecr create-repository --repository-name cms-strapi

# Obtener URI de login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
```

### 2. Build y push de imagen

```bash
# Build de imagen de producción
docker build --target production -t cms-strapi:latest .

# Tag para ECR
docker tag cms-strapi:latest YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/cms-strapi:latest

# Push a ECR
docker push YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/cms-strapi:latest
```

### 3. Configurar RDS PostgreSQL

```bash
# Crear subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name cms-strapi-subnet-group \
  --db-subnet-group-description "Subnet group for CMS Strapi" \
  --subnet-ids subnet-xxx subnet-yyy

# Crear base de datos RDS
aws rds create-db-instance \
  --db-instance-identifier cms-strapi-prod \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username strapiuser \
  --master-user-password YOUR_SECURE_PASSWORD \
  --allocated-storage 20 \
  --db-name strapidb \
  --vpc-security-group-ids sg-xxx \
  --db-subnet-group-name cms-strapi-subnet-group \
  --backup-retention-period 7 \
  --storage-encrypted
```

### 4. Task Definition

```json
{
  "family": "cms-strapi",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::YOUR_ACCOUNT:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "strapi",
      "image": "YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/cms-strapi:latest",
      "portMappings": [
        {
          "containerPort": 1337,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {"name": "NODE_ENV", "value": "production"},
        {"name": "DATABASE_CLIENT", "value": "postgres"},
        {"name": "DATABASE_HOST", "value": "cms-strapi-prod.xxx.us-east-1.rds.amazonaws.com"},
        {"name": "DATABASE_PORT", "value": "5432"},
        {"name": "DATABASE_NAME", "value": "strapidb"},
        {"name": "DATABASE_SSL", "value": "true"}
      ],
      "secrets": [
        {"name": "DATABASE_USERNAME", "valueFrom": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT:secret:cms-strapi/db-username"},
        {"name": "DATABASE_PASSWORD", "valueFrom": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT:secret:cms-strapi/db-password"},
        {"name": "APP_KEYS", "valueFrom": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT:secret:cms-strapi/app-keys"},
        {"name": "JWT_SECRET", "valueFrom": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT:secret:cms-strapi/jwt-secret"},
        {"name": "ADMIN_JWT_SECRET", "valueFrom": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT:secret:cms-strapi/admin-jwt-secret"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/cms-strapi",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:1337/_health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### 5. Service Configuration

```bash
# Crear cluster ECS
aws ecs create-cluster --cluster-name cms-strapi-cluster

# Crear servicio
aws ecs create-service \
  --cluster cms-strapi-cluster \
  --service-name cms-strapi-service \
  --task-definition cms-strapi:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:YOUR_ACCOUNT:targetgroup/cms-strapi-tg,containerName=strapi,containerPort=1337
```

## Despliegue en Kubernetes

### 1. Namespace y ConfigMap

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cms-strapi

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: strapi-config
  namespace: cms-strapi
data:
  NODE_ENV: "production"
  DATABASE_CLIENT: "postgres"
  DATABASE_HOST: "postgres-service"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "strapidb"
  DATABASE_SSL: "false"
```

### 2. Secrets

```yaml
# k8s/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: strapi-secrets
  namespace: cms-strapi
type: Opaque
data:
  DATABASE_USERNAME: <base64-encoded>
  DATABASE_PASSWORD: <base64-encoded>
  APP_KEYS: <base64-encoded>
  JWT_SECRET: <base64-encoded>
  ADMIN_JWT_SECRET: <base64-encoded>
```

### 3. PostgreSQL Deployment

```yaml
# k8s/postgres.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: cms-strapi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: "strapidb"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: strapi-secrets
              key: DATABASE_USERNAME
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: strapi-secrets
              key: DATABASE_PASSWORD
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: cms-strapi
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
```

### 4. Strapi Deployment

```yaml
# k8s/strapi.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: strapi
  namespace: cms-strapi
spec:
  replicas: 2
  selector:
    matchLabels:
      app: strapi
  template:
    metadata:
      labels:
        app: strapi
    spec:
      containers:
      - name: strapi
        image: your-registry/cms-strapi:latest
        ports:
        - containerPort: 1337
        envFrom:
        - configMapRef:
            name: strapi-config
        - secretRef:
            name: strapi-secrets
        livenessProbe:
          httpGet:
            path: /_health
            port: 1337
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /_health
            port: 1337
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"

---
apiVersion: v1
kind: Service
metadata:
  name: strapi-service
  namespace: cms-strapi
spec:
  selector:
    app: strapi
  ports:
  - port: 80
    targetPort: 1337
  type: ClusterIP
```

### 5. Ingress

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: strapi-ingress
  namespace: cms-strapi
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - api.yourdomain.com
    secretName: strapi-tls
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: strapi-service
            port:
              number: 80
```

### 6. Horizontal Pod Autoscaler

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: strapi-hpa
  namespace: cms-strapi
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: strapi
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Comandos de Despliegue

```bash
# Aplicar todos los manifiestos
kubectl apply -f k8s/

# Verificar despliegue
kubectl get pods -n cms-strapi
kubectl get services -n cms-strapi
kubectl get ingress -n cms-strapi

# Ver logs
kubectl logs -f deployment/strapi -n cms-strapi

# Escalar manualmente
kubectl scale deployment strapi --replicas=3 -n cms-strapi
```

## Monitoreo y Observabilidad

### Prometheus y Grafana

```yaml
# k8s/monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: strapi-metrics
  namespace: cms-strapi
spec:
  selector:
    matchLabels:
      app: strapi
  endpoints:
  - port: http
    path: /metrics
```

### Logging con ELK Stack

```yaml
# k8s/filebeat.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: cms-strapi
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"

    output.elasticsearch:
      hosts: ["elasticsearch:9200"]
```
