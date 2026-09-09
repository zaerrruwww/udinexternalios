const app = require('./index');

module.exports = (req, res) => {
  if (req.query && req.query.all) {
    const subpath = Array.isArray(req.query.all) ? req.query.all.join('/') : req.query.all;
    const queryIndex = (req.url || '').indexOf('?');
    const queryString = queryIndex !== -1 ? req.url.slice(queryIndex) : '';
    req.url = '/' + subpath + queryString;
  }
  return app(req, res);
};
