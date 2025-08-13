// test-creds.js
// Test TOTP and password verification locally without external libs

import { validateTOTP } from './totp.js';
import { verifyPassword, getUser } from './user.js';

if (process.argv.length < 5) {
  console.error('Usage: node test-creds.js <username> <password> <totpCode>');
  process.exit(2);
}

const [, , username, password, totpCode] = process.argv;
const user = getUser(username);
if (!user) {
  console.error('Unknown user:', username);
  process.exit(2);
}

const passOk = verifyPassword(password, user.salt, user.passwordHash);
const totpOk = validateTOTP(user.totpSecret, totpCode);

console.log('User:', username);
console.log('Password valid:', passOk);
console.log('TOTP valid:', totpOk);
