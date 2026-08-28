// PM2 process definition for the D-Customer Portal static server.
// Start:  pm2 start ecosystem.config.cjs && pm2 save
// Other web apps get their own ecosystem file / entry alongside this one.
module.exports = {
  apps: [
    {
      name: 'customer-portal',
      script: 'server.mjs',
      cwd: __dirname,
      instances: 1,
      autorestart: true,
      env: {
        PORT: 5001,
      },
    },
  ],
};
