import assert from 'node:assert/strict';
import test from 'node:test';
import { hashPassword, newSessionToken, tokenDigest, verifyPassword } from '../src/auth/auth.service.js';

test('密码哈希可以校验通过，错误密码不通过', () => {
  const stored = hashPassword('admin');
  assert.ok(stored.startsWith('scrypt$'), '哈希应带 scrypt 前缀');
  assert.ok(verifyPassword('admin', stored));
  assert.ok(!verifyPassword('wrong', stored));
});

test('同一密码两次哈希得到不同盐与密文，但仍可校验', () => {
  const a = hashPassword('same-password');
  const b = hashPassword('same-password');
  assert.notEqual(a, b, '盐应随机，密文不同');
  assert.ok(verifyPassword('same-password', a));
  assert.ok(verifyPassword('same-password', b));
});

test('坏格式的存储串校验直接返回 false，不抛错', () => {
  assert.equal(verifyPassword('x', ''), false);
  assert.equal(verifyPassword('x', 'plaintext'), false);
  assert.equal(verifyPassword('x', 'md5$abc$def'), false);
});

test('会话 token 随机且摘要稳定', () => {
  const a = newSessionToken();
  const b = newSessionToken();
  assert.notEqual(a, b);
  assert.equal(a.length, 64);
  assert.equal(tokenDigest(a), tokenDigest(a), '同一 token 摘要一致');
  assert.notEqual(tokenDigest(a), tokenDigest(b));
  assert.equal(tokenDigest(a).length, 64);
});
