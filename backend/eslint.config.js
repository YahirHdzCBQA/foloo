import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['dist/**', 'cdk.out/**', '.env.*/**', 'eslint.config.js'] },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
);
