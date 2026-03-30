module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
  extends: ['eslint:recommended', 'google'],
  rules: {
    'max-len': ['error', {code: 120}],
    'require-jsdoc': 'off',
  },
};
