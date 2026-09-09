module.exports = (req, res) => {
  res.json({
    status: 'online',
    service: 'UDIN EXTERNAL License Server',
    version: '2.4.0',
    developer: 'zaeruw',
    server_time: new Date().toISOString()
  });
};
