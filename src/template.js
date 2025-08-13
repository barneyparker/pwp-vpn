import fs from 'fs';

const template = fs.readFileSync(new URL('./template.html', import.meta.url), 'utf8');

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

  return { statusCode: cfg.error === false ? 200 : 400, headers: { 'Content-Type': 'text/html' }, body };
}