// index.js
const axios = require('axios');
const { ManagedIdentityCredential } = require('@azure/identity');

module.exports = async function (context, req) {
  context.log('get-customer invoked');

  const customerId = (req.query.id) || (req.body && req.body.id);
  if (!customerId) {
    context.res = { status: 400, body: { error: 'missing id' } };
    return;
  }

  try {
    const d365Base = process.env.D365_API_BASEURL || 'https://d365.example.com';
    const scope = process.env.D365_SCOPE || `${new URL(d365Base).origin}/.default`;

    // Acquire token using Managed Identity
    const credential = new ManagedIdentityCredential();
    const tokenResponse = await credential.getToken(scope);
    const token = tokenResponse?.token;

    const response = await axios.get(`${d365Base}/data/CustomersV3?cross-company=true&$filter=AccountNumber eq '${customerId}'`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    context.res = {
      status: 200,
      body: response.data
    };
  } catch (err) {
    context.log.error('error calling D365', err.message);
    context.res = { status: 502, body: { error: 'upstream error', details: err.message } };
  }
};
