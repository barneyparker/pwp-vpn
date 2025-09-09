import fs from 'fs';

const template = fs.readFileSync(new URL('./template.html', import.meta.url), 'utf8');

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
 * @typedef {object} Instance
 * @property {string} InstanceId
 * @property {string} LifecycleState
 * @property {string} HealthStatus
 */

/**
 * @typedef {object} Status
 * @property {boolean} error
 * @property {string} errorMsg
 * @property {number} DesiredCapacity
 * @property {number} MinSize
 * @property {number} MaxSize
 * @property {Instance[]} Instances
 * @property {string} username
 * @property {string} password
 * @property {string} lastReady
 */

function renderInstances(instances) {

  if (instances.length === 0) {
    return '<p>No instances found.</p>';
  }

  let html = '';
  instances.forEach(instance => {
    html += `
      <div class="instance-card">
        <div class="instance-title">${ instance.InstanceId }</div>
        <div class="instance-details">Status: ${ instance.LifecycleState } - ${ instance.HealthStatus }</div>
        <div class="instance-details">Template Name: ${ instance.LaunchTemplate.LaunchTemplateName }</div>
        <div class="instance-details">Template Version: ${ instance.LaunchTemplate.Version }</div>
        <div class="instance-details">Template Id: ${ instance.LaunchTemplate.LaunchTemplateId }</div>
        <div class="instance-details">Instance Type: ${ instance.InstanceType }</div>
        <div class="instance-details">Availability Zone: ${ instance.AvailabilityZone }</div>
      </div>
    `;
  });
  return html;
}

/**
 * @param {Status} cfg
 * @returns
 */
export const renderStatusPage = async (cfg) => {
  // Get the template
  let body = template;

  // ASG Name
  body = body.replace(/{{asgName}}/g, String(process.env.ASG_NAME || ''));

  // ASG Info
  body = body.replace(/{{desired}}/g, String(cfg.DesiredCapacity));
  body = body.replace(/{{min}}/g, String(cfg.MinSize));
  body = body.replace(/{{max}}/g, String(cfg.MaxSize));
  body = body.replace(/{{lastReady}}/g, String(cfg.lastReady));

  // Instances list
  let instancesHtml = renderInstances(cfg.Instances || []);
  body = body.replace(/{{instances}}/g, instancesHtml);

  // Error message
  if (cfg.error) {
    body = body.replace(/{{errorMsg}}/g, '<p class="errorMsg">' + cfg.errorMsg + '</p>');
  } else {
    body = body.replace(/{{errorMsg}}/g, '');
  }

  // Form values
  body = body.replace(/{{username}}/g, String(cfg.username));
  body = body.replace(/{{password}}/g, String(cfg.password));

  // Next desired
  body = body.replace(/{{nextDesired}}/g, String(cfg.DesiredCapacity === 0 ? 1 : 0));

  const headers = {
    'Content-Type': 'text/html',
    ...getSecurityHeaders('text/html')
  };

  return { statusCode: cfg.error === false ? 200 : 400, headers, body };
}