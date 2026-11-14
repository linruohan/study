import { randomBytes, scryptSync, createHash, timingSafeEqual } from 'node:crypto';

/// 密码与令牌的工具：scrypt 存哈希，会话 token 只存 sha256 摘要。

const SCRYPT_KEYLEN = 64;

export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString('hex');
  const hash = scryptSync(password, salt, SCRYPT_KEYLEN).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const parts = stored.split('$');
  if (parts.length !== 3 || parts[0] !== 'scrypt') {
    return false;
  }
  const [, salt, expected] = parts;
  const actual = scryptSync(password, salt, SCRYPT_KEYLEN);
  const expectedBuf = Buffer.from(expected, 'hex');
  if (expectedBuf.length !== actual.length) {
    return false;
  }
  return timingSafeEqual(actual, expectedBuf);
}

export function newSessionToken(): string {
  return randomBytes(32).toString('hex');
}

export function tokenDigest(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
