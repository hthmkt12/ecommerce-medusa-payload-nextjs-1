import type { Access } from 'payload'

/**
 * Requires a Payload-authenticated user on the request.
 *
 * Covers both auth paths:
 * - API key header (`Authorization: users API-Key <key>`) used by the
 *   Medusa backend when syncing content.
 * - Admin panel cookie sessions for manual editing.
 *
 * Anonymous requests are rejected. Never gate writes on query params:
 * they are trivially spoofable.
 */
export const isAuthenticated: Access = ({ req: { user } }) => Boolean(user)
