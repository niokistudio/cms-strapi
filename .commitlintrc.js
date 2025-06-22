module.exports = {
    extends: ['@commitlint/config-conventional'],
    rules: {
        'type-enum': [
            2,
            'always',
            [
                'feat',     // Nueva funcionalidad
                'fix',      // Corrección de bug
                'docs',     // Documentación
                'style',    // Formato, espacios, etc.
                'refactor', // Refactorización
                'perf',     // Mejora de rendimiento
                'test',     // Tests
                'build',    // Sistema de build
                'ci',       // Integración continua
                'chore',    // Tareas de mantenimiento
                'revert',   // Revertir cambios
            ],
        ],
        'type-case': [2, 'always', 'lower-case'],
        'type-empty': [2, 'never'],
        'scope-case': [2, 'always', 'lower-case'],
        'subject-case': [2, 'never', ['sentence-case', 'start-case', 'pascal-case', 'upper-case']],
        'subject-empty': [2, 'never'],
        'subject-full-stop': [2, 'never', '.'],
        'header-max-length': [2, 'always', 100],
    },
};
