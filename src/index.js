import { AutoScalingClient, DescribeAutoScalingGroupsCommand, SetDesiredCapacityCommand } from '@aws-sdk/client-auto-scaling';
import { validateTOTP } from './totp.js';
import { getUser, verifyPassword } from './user.js';
import { renderStatusPage } from './template.js'
import { getLastReady } from './ssm.js';

const autoscaling = new AutoScalingClient({});

/**
 * Generate security headers for web responses
 * @param {string} contentType - The content type of the response
 * @returns {object} Headers object with security headers
 */
function getSecurityHeaders(contentType) {
  const headers = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block'
  };

  // Add HSTS for HTML content (assuming HTTPS deployment)
  if (contentType && contentType.includes('text/html')) {
    headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains';
  }

  // Add CSP for HTML content - allow inline styles/scripts for PWA functionality
  if (contentType && contentType.includes('text/html')) {
    headers['Content-Security-Policy'] = 
      "default-src 'self'; " +
      "style-src 'self' 'unsafe-inline'; " +
      "script-src 'self' 'unsafe-inline'; " +
      "img-src 'self' data:; " +
      "connect-src 'self'; " +
      "font-src 'self'; " +
      "manifest-src 'self'";
  }

  return headers;
}

/**
 * Lambda handler.
 * GET: returns HTML status page for the ASG.
 * POST: accepts JSON {username,password,mfa,desired} to update ASG desired capacity.
 * @param {object} event - API Gateway v2 Lambda event
 * @returns {Promise<{statusCode:number,headers?:Object,body:string,isBase64Encoded?:boolean}>}
 */
export const handler = async (event) => {
  // Serve manifest.json, sw.js, and icons for PWA support
  const staticFiles = {
    '/manifest.json': { path: './manifest.json', type: 'application/json', encoding: 'utf8' },
    '/sw.js': { path: './sw.js', type: 'application/javascript', encoding: 'utf8' },
    '/icons/icon-192.png': { path: './icons/icon-192.png', type: 'image/png', encoding: null },
    '/icons/icon-512.png': { path: './icons/icon-512.png', type: 'image/png', encoding: null },
    '/icons/apple-touch-icon.png': { path: './icons/apple-touch-icon.png', type: 'image/png', encoding: null },
    '/icons/favicon.ico': { path: './icons/favicon.ico', type: 'image/x-icon', encoding: null }
  };
  if (staticFiles[event.rawPath]) {
    const fs = await import('fs');
    try {
      const { path, type, encoding } = staticFiles[event.rawPath];
      const file = fs.readFileSync(new URL(path, import.meta.url), encoding || undefined);
      let body, isBase64Encoded = false;
      if (encoding) {
        body = file.toString();
      } else {
        body = file.toString('base64');
        isBase64Encoded = true;
      }
      const headers = { 
        'Content-Type': type,
        ...getSecurityHeaders(type)
      };
      
      return {
        statusCode: 200,
        headers,
        body,
        isBase64Encoded
      };
    } catch (e) {
      return { statusCode: 404, body: 'Not found' };
    }
  }
  console.log(JSON.stringify(event, null, 2));

  /** @type {import('./template.js').Status} */
  const cfg = {
    error: false,
    errorMsg: '',
    DesiredCapacity: 0,
    MinSize: 0,
    MaxSize: 0,
    Instances: [],
    username: '',
    password: '',
    lastReady: 'unknown'
  }

  // find the ASG so we can get useful info from it:
  const asgResp = await autoscaling.send(new DescribeAutoScalingGroupsCommand({ AutoScalingGroupNames: [process.env.ASG_NAME] }));
  const asg = asgResp.AutoScalingGroups && asgResp.AutoScalingGroups.length > 0 ? asgResp.AutoScalingGroups[0] : null;

  // get our "Last Ready" value
  try {
    cfg.lastReady = await getLastReady();
  } catch (e) {
    cfg.lastReady = 'unavailable';
  }

  // If there wasnt an ASG, just render the page
  if (!asg) {
    cfg.error = true
    cfg.errorMsg = 'ASG not found';
    return renderStatusPage(cfg);
  }

  // Populate cfg with ASG details
  cfg.DesiredCapacity = asg.DesiredCapacity;
  cfg.MinSize = asg.MinSize;
  cfg.MaxSize = asg.MaxSize;
  cfg.Instances = asg.Instances || [];

  if (event.requestContext.http.method === 'POST') {
    // Decode body if base64 encoded
    let rawBody = event.body || '';
    if (event.isBase64Encoded) {
      rawBody = Buffer.from(rawBody, 'base64').toString('utf8');
    }
    // Parse form-encoded body
    const body = {};
    for (const pair of rawBody.split('&')) {
      const [k, v] = pair.split('=');
      if (k) body[decodeURIComponent(k)] = decodeURIComponent(v || '');
    }

    // get the form parameters from the body
    const { username, password, mfa, desired } = body;

    // find our user
    const user = getUser(username);
    if (!user) {
      cfg.errorMsg = 'Invalid Username.';
      return await renderStatusPage(cfg);
    }

    const okPass = await verifyPassword(password, user.salt, user.passwordHash);
    if (!okPass) {
      cfg.error = true;
      cfg.errorMsg = 'Invalid Password.';
    }

    const okMfa = await validateTOTP(user.totpSecret, String(mfa));
    if (!okMfa) {
      cfg.error = true;
      cfg.errorMsg = 'Invalid MFA.';
    }

    if (!(parseInt(desired) === 0 || parseInt(desired) === 1)) {
      cfg.error = true;
      cfg.errorMsg = 'Desired must be 0 or 1. Got ' + desired;
    }

    if (!cfg.error) {
      await autoscaling.send(new SetDesiredCapacityCommand({ AutoScalingGroupName: process.env.ASG_NAME, DesiredCapacity: desired, HonorCooldown: false }));
      cfg.DesiredCapacity = parseInt(desired);
      // Redirect to GET after successful POST
      const redirectHeaders = {
        Location: event.rawPath || '/',
        ...getSecurityHeaders('')
      };
      return {
        statusCode: 303,
        headers: redirectHeaders,
        body: ''
      };
    }
  }

  // return our status
  return await renderStatusPage(cfg);
};
