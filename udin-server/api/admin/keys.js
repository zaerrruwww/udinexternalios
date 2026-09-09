const app = require('../index');
module.exports = (req, res) => {
  if (!req.url || req.url === '/' || req.url.startsWith('/?')) {
    const queryIndex = (req.url || '').indexOf('?');
    const query = queryIndex !== -1 ? req.url.slice(queryIndex) : '';
    req.url = '/api/admin/keys' + query;
  }
  return app(req, res);
};
