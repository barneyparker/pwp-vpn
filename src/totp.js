import { createHmac } from 'crypto';

/**
 * Decode a base32 (RFC4648, no padding) string into a Buffer.
 * @param {string} str - Base32 encoded string (A-Z2-7, optional padding)
 * @returns {Buffer} Decoded bytes
 */
export function base32Decode(str) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0;
  let value = 0;
  const bytes = [];
  for (let i = 0; i < str.length; i++) {
    const idx = alphabet.indexOf(str[i].toUpperCase());
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((value >>> bits) & 0xff);
    }
  }
  return Buffer.from(bytes);
}

/**
 * Generate a 6-digit TOTP code for a Base32 secret.
 * @param {string} secret - Base32 secret string
 * @param {number} [window=0] - Time-step offset (e.g. -1, 0, +1)
 * @returns {string} 6-digit TOTP code (zero-padded)
 */
export function generateTOTP(secret, window = 0) {
  const key = base32Decode(secret.replace(/=+$/, ''));
  const epoch = Math.floor(Date.now() / 1000);
  const counter = Math.floor(epoch / 30) + window;
  const buf = Buffer.alloc(8);
  buf.writeUInt32BE(Math.floor(counter / 0x100000000), 0);
  buf.writeUInt32BE(counter & 0xffffffff, 4);
  const hmac = createHmac('sha1', key).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  const code = (hmac.readUInt32BE(offset) & 0x7fffffff) % 1000000;
  return code.toString().padStart(6, '0');
}

/**
 * Validate a TOTP token against a secret. Accepts a +-1 window to allow
 * for small clock skew.
 * @param {string} secret - Base32 secret string
 * @param {string|number} token - TOTP token provided by user
 * @returns {boolean} true if valid
 */
export function validateTOTP(secret, token) {
  const t = String(token).padStart(6, '0');
  for (let w = -1; w <= 1; w++) {
    if (t === generateTOTP(secret, w)) return true;
  }
  return false;
}

/**
 * Encode a Buffer into base32 (RFC4648, no padding)
 * @param {Buffer} buf
 * @returns {string}
 */
export function base32Encode(buf) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0;
  let value = 0;
  let output = '';
  for (let i = 0; i < buf.length; i++) {
    value = (value << 8) | buf[i];
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      output += alphabet[(value >>> bits) & 31];
    }
  }
  if (bits > 0) output += alphabet[(value << (5 - bits)) & 31];
  return output;
}
