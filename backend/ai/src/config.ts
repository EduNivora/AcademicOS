import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().default('0.0.0.0'),
  PORT: z.coerce.number().int().positive().default(8787),
  DATABASE_URL: z.string().min(1),
  DATABASE_SSL: z.enum(['true', 'false']).default('false'),
  GOOGLE_OAUTH_CLIENT_ID: z.string().min(1),
  OPENAI_API_KEY: z.string().min(1),
  OPENAI_MODEL: z.string().default('gpt-4.1-mini'),
  OPENAI_TIMEOUT_MS: z.coerce.number().int().positive().default(45000),
  OPENAI_MAX_OUTPUT_TOKENS: z.coerce.number().int().positive().max(8192).default(1800),
  SYSTEM_PROMPT_FILE: z.string().optional(),
  ALLOWED_ORIGINS: z.string().default(''),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(20),
  RATE_LIMIT_WINDOW: z.string().default('1 minute'),
  MAX_USER_MESSAGE_CHARS: z.coerce.number().int().positive().default(12000),
  MAX_CONTEXT_MESSAGES: z.coerce.number().int().positive().max(40).default(20),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  throw new Error(`Invalid AI gateway configuration: ${parsed.error.issues.map(i => i.path.join('.') + ': ' + i.message).join('; ')}`);
}

export const config = {
  ...parsed.data,
  databaseSsl: parsed.data.DATABASE_SSL === 'true' ? { rejectUnauthorized: true } : false,
  allowedOrigins: parsed.data.ALLOWED_ORIGINS.split(',').map(x => x.trim()).filter(Boolean),
};

const defaultPromptPath = new URL('../prompts/academic-system.md', import.meta.url);
export async function loadSystemPrompt(): Promise<string> {
  const path = config.SYSTEM_PROMPT_FILE
    ? resolve(config.SYSTEM_PROMPT_FILE)
    : defaultPromptPath;
  const prompt = await readFile(path, 'utf8');
  if (!prompt.trim()) throw new Error('System prompt is empty.');
  return prompt;
}