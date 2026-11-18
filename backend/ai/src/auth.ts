import { OAuth2Client } from 'google-auth-library';
import type { FastifyRequest } from 'fastify';
import { config } from './config.js';

const google = new OAuth2Client(config.GOOGLE_OAUTH_CLIENT_ID);

export type AuthenticatedUser = {
  id: string;
  email: string | null;
};

declare module 'fastify' {
  interface FastifyRequest {
    authenticatedUser: AuthenticatedUser | null;
  }
}

export async function authenticateGoogleIdToken(request: FastifyRequest): Promise<AuthenticatedUser> {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    const error = new Error('Authentication required.') as Error & { statusCode: number };
    error.statusCode = 401;
    throw error;
  }
  const token = header.slice(7).trim();
  if (!token || token.length > 8192) {
    const error = new Error('Invalid authentication token.') as Error & { statusCode: number };
    error.statusCode = 401;
    throw error;
  }

  try {
    const ticket = await google.verifyIdToken({
      idToken: token,
      audience: config.GOOGLE_OAUTH_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email_verified) throw new Error('Unverified identity.');
    return { id: payload.sub, email: payload.email ?? null };
  } catch {
    const error = new Error('Authentication token is invalid or expired.') as Error & { statusCode: number };
    error.statusCode = 401;
    throw error;
  }
}