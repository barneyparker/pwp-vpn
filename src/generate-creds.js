// generate-creds.js
// Node.js script to generate a PBKDF2 password hash and a TOTP base32 secret
// No external libraries used

import { randomBytes, pbkdf2Sync } from 'crypto';
import { base32Encode } from './totp.js';

/**
 * @typedef {Object} GeneratedCreds
 * @property {string} salt - hex-encoded salt
 * @property {string} passwordHash - hex-encoded PBKDF2 derived key
 * @property {string} totpSecret - Base32 TOTP secret
 */

/**
 * Generate PBKDF2-SHA256 salt/hash and a random base32 secret.
 * @param {string} password
 * @returns {GeneratedCreds}
 */
function generate(password) {
  const salt = randomBytes(16);
  const hash = pbkdf2Sync(password, salt, 100000, 32, 'sha256');
  const totpSecret = base32Encode(randomBytes(10));
  return {
    salt: salt.toString('hex'),
    passwordHash: hash.toString('hex'),
    totpSecret
  };
}

if (process.argv.length < 3) {
  console.error('Usage: node generate-creds.js <password>');
  process.exit(2);
}

const password = process.argv[2];
const out = generate(password);
console.log(JSON.stringify(out, null, 2));
