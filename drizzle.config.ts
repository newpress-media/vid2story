import type { Config } from 'drizzle-kit';

export default {
  schema: './src/models/schema.ts',
  out: './src/models/migrations',
  dialect: 'sqlite',
  dbCredentials: {
    url: process.env.DATABASE_PATH || 'data/sqlite.db'
  },
} satisfies Config; 