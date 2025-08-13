import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const ssm = new SSMClient({});

export async function getLastReady() {
  try {
    const param = await ssm.send(new GetParameterCommand({ Name: '/pwp-vpn/last-ready' }));
    return param.Parameter?.Value || 'never';
  } catch (error) {
    console.error('Error fetching last ready time:', error);
    return 'unknown';
  }
}
