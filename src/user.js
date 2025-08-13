import { pbkdf2Sync } from 'crypto';

/**
 * @typedef {Object} User
 * @property {string} username
 * @property {string} passwordHash
 * @property {string} salt
 * @property {string} totpSecret
 */

/** @type {User[]} */
export const users = [
  {
    username: 'barney@barneyparker.com',
    passwordHash: '921c0bdd9abb1eff37584b6de2664051b5a06978746ce86c47ddd5878b6b5442',
    salt: '2f84b6708b7b95b50f098c2d2c661a3e',
    totpSecret: '5HLAZXUJA5GXDGDF'
  },
  {
    username: 'user2@example.com',
    passwordHash: 'REPLACE_WITH_HASH',
    salt: 'REPLACE_WITH_SALT',
    totpSecret: 'REPLACE_WITH_BASE32_SECRET'
  }
];

/**
 * Find a user by username (case-insensitive)
 * @param {string} username
 * @returns {User|undefined}
 */
export function getUser(username) {
  return users.find(u => u.username.toLowerCase() === username.toLowerCase());
}

/**
 * Verify password using PBKDF2-SHA256
 * @param {string} password
 * @param {string} saltHex
 * @param {string} hashHex
 * @returns {boolean}
 */
export function verifyPassword(password, saltHex, hashHex) {
  const salt = Buffer.from(saltHex, 'hex');
  const derived = pbkdf2Sync(password, salt, 100000, 32, 'sha256');
  return derived.toString('hex') === hashHex;
}
