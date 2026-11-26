import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['dist/**', 'cdk.out/**', '.env.*/**', 'eslint.config.js'] },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    // The isolated Apple diagnostic runs in Node 22, not in a browser.
    files: ['scripts/apple-identity-probe/*.mjs'],
    languageOptions: {
      globals: {
        AbortSignal: 'readonly',
        Buffer: 'readonly',
        fetch: 'readonly',
        Response: 'readonly',
        URL: 'readonly',
        URLSearchParams: 'readonly',
      },
    },
  },
);
