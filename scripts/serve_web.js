// Minimal static server for testing the web build locally: node scripts/serve_web.js [port]
// Open http://localhost:8060/ (on a phone on the same network use the PC's IP address).
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "build", "web");
const port = Number(process.argv[2] || 8060);
const types = {
  ".html": "text/html", ".js": "application/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
};

http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const file = path.join(root, url === "/" ? "index.html" : url);
  if (!file.startsWith(root) || !fs.existsSync(file)) {
    res.writeHead(404);
    res.end("not found");
    return;
  }
  res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
}).listen(port, () => console.log(`serving ${root} on http://localhost:${port}/`));
