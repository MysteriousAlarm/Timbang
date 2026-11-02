module.exports = {
  rootDir: __dirname,
  testEnvironment: 'node',
  testMatch: ['**/*.test.js'],
  testTimeout: 20000,
  setupFiles: ['<rootDir>/setup.js'],
};
