# Etapa base
FROM node:20-slim as base

# Instalación de dependencias del sistema
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Configuración del directorio de trabajo
WORKDIR /opt/app

# Creación del usuario no privilegiado
RUN groupadd -r strapi && useradd -r -g strapi -m -d /home/strapi strapi

# Etapa de desarrollo
FROM base as development

# Variables de entorno para desarrollo
ENV NODE_ENV=development

# Copia de archivos de dependencias
COPY cms/package*.json ./

# Instalación de dependencias incluyendo devDependencies
RUN npm ci

# Cambio de propietario y permisos
RUN chown -R strapi:strapi /opt/app
USER strapi

# Exposición del puerto
EXPOSE 1337

# Comando por defecto para desarrollo con hot-reload
CMD ["npm", "run", "dev"]

# Etapa de construcción para producción
FROM base as builder

# Variables de entorno para construcción
ENV NODE_ENV=production

# Copia de archivos de dependencias
COPY cms/package*.json ./

# Instalación solo de dependencias de producción
RUN npm ci --only=production && npm cache clean --force

# Copia del código fuente
COPY cms/ ./

# Construcción de la aplicación
RUN npm run build

# Etapa de producción
FROM node:20-slim as production

# Instalación de dependencias mínimas del sistema
RUN apt-get update && apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

# Variables de entorno para producción
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=1024"

# Configuración del directorio de trabajo
WORKDIR /opt/app

# Creación del usuario no privilegiado
RUN groupadd -r strapi && useradd -r -g strapi -m -d /home/strapi strapi

# Copia de la aplicación construida desde la etapa builder
COPY --from=builder --chown=strapi:strapi /opt/app .

# Configuración de permisos
RUN chown -R strapi:strapi /opt/app

# Cambio al usuario no privilegiado
USER strapi

# Exposición del puerto
EXPOSE 1337

# Verificación de salud
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:1337/_health || exit 1

# Comando por defecto para producción
CMD ["npm", "start"]
