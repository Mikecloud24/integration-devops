// index.js
const axios = require('axios');

module.exports = async function (context, req) {
  context.log('get-customer invoked');

  const customerId = (req.query.id) || (req.body && req.body.id);
  if (!customerId) {
    context.res = { status: 400, body: { error: 'missing id' } };
    return;
  }

  // Example: call D365 API with managed identity. Here i used placeholder token flow.
  // In production, use 'ManagedIdentityCredential' from @azure/identity to get token and pass in Authorization header.
  try {
    const d365Base = process.env.D365_API_BASEURL || 'https://d365.example.com';
    // placeholder: real code obtains token
    const response = await axios.get(`${d365Base}/data/CustomersV3?cross-company=true&$filter=AccountNumber eq '${customerId}'`);
    context.res = {
      status: 200,
      body: response.data
    };
  } catch (err) {
    context.log.error('error calling D365', err.message);
    context.res = { status: 502, body: { error: 'upstream error', details: err.message } };
  }
};
