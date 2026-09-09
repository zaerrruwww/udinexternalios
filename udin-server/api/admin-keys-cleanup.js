const app = require('./index');
module.exports = (req, res) => {
  const queryIndex = (req.url || '').indexOf('?');
  const query = queryIndex !== -1 ? req.url.slice(queryIndex) : '';
  req.url = '/api/admin/keys/cleanup-expired' + query;
  return app(req, res);
};
