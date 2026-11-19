import pg from 'pg';
import { config } from './config.js';

const { Pool } = pg;
export const pool = new Pool({
  connectionString: config.DATABASE_URL,
  ssl: config.databaseSsl,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

export async function checkDatabase(): Promise<void> {
  await pool.query('SELECT 1');
}

export async function closeDatabase(): Promise<void> {
  await pool.end();
}