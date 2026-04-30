const express = require("express");

const app = express();
const PORT = 3000;

// Simple metrics endpoint
app.get("/metrics", (req, res) => {
  res.set("Content-Type", "text/plain");

  const uptime = process.uptime();

  res.send(`
# HELP app_uptime_seconds Uptime of the application
# TYPE app_uptime_seconds counter
app_uptime_seconds ${uptime}

# HELP app_random_metric Random number
# TYPE app_random_metric gauge
app_random_metric ${Math.random()}
`);
});

app.get("/", (req, res) => {
  res.send("App is running");
});

app.listen(PORT, () => {
  console.log(`App running on port ${PORT}`);
});
