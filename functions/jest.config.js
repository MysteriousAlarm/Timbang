module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  // `jose` (pulled in by firebase-admin) ships ESM only; transpile it for Jest.
  transform: { '^.+\\.[tj]s$': ['ts-jest', { tsconfig: { allowJs: true }, diagnostics: { ignoreCodes: [151001] } }] },
  transformIgnorePatterns: ['node_modules/(?!jose/)'],
};
