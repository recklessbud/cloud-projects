const express = require('express');
const os = require('os');
const app = express();
const port = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        hostname: os.hostname(),
        uptime: process.uptime()
    });
});

// Main application endpoint
app.get("/", (req, res) => {
  const response = {
    message: "Hello from AWS Fargate!",
    container: {
      hostname: os.hostname(),
      platform: os.platform(),
      architecture: os.arch(),
      memory: `${Math.round(process.memoryUsage().rss / 1024 / 1024)} MB`,
      uptime: `${Math.round(process.uptime())} seconds`,
    },
    environment: {
      nodeVersion: process.version,
      port: port,
      timestamp: new Date().toISOString(),
    },
    request: {
      method: req.method,
      url: req.url,
      headers: req.headers["user-agent"],
      ip: req.ip,
    },
  };

  res.json(response);
});

// Metrics endpoint
app.get("/metrics", (req, res) => {
  const metrics = {
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    uptime: process.uptime(),
    timestamp: Date.now(),
  };
  res.json(metrics);
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Server running on port ${port}`);
  console.log(`Health check available at /health`);
  console.log(`Metrics available at /metrics`);
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully");
  process.exit(0);
});