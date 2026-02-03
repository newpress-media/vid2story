module.exports = {
  apps: [{
    name: 'vid2story',
    script: './dist/server.js',
    instances: 1,
    exec_mode: 'cluster',
    autorestart: true,
    watch: false,
    max_memory_restart: '4G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      LD_LIBRARY_PATH: '/usr/local/cuda-13.0/lib64:' + (process.env.LD_LIBRARY_PATH || ''),
      PATH: '/usr/local/cuda-13.0/bin:' + (process.env.PATH || '/usr/local/bin:/usr/bin:/bin')
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true,
    merge_logs: true,
    max_restarts: 10,
    min_uptime: '10s',
    listen_timeout: 10000,
    kill_timeout: 5000,
    wait_ready: true,
    // Restart on high memory usage
    max_memory_restart: '4G',
    // Exponential backoff restart delay
    exp_backoff_restart_delay: 100,
    // Restart at specific times for maintenance
    cron_restart: '0 4 * * *', // Restart at 4 AM daily
  }]
};
