const MAX_BODY_BYTES = 256 * 1024;

function setCors(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

function allowMethods(req, res, methods) {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return false;
  }
  if (!methods.includes(req.method)) {
    res.setHeader("Allow", [...methods, "OPTIONS"].join(", "));
    res.status(405).json({ success: false, message: "Method not allowed" });
    return false;
  }
  return true;
}

function boundedArray(value, name, max = 200) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > max) {
    const error = new Error(`${name} must be an array with at most ${max} items`);
    error.statusCode = 400;
    throw error;
  }
  return value;
}

function boundedLimit(value, fallback = 20, maximum = 50) {
  if (value === undefined || value === null || value === "") return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > maximum) {
    const error = new Error(`limit must be an integer between 1 and ${maximum}`);
    error.statusCode = 400;
    throw error;
  }
  return parsed;
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    let size = 0;
    let exceeded = false;
    req.on("data", (chunk) => {
      if (exceeded) return;
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        exceeded = true;
        body = "";
        return;
      }
      body += chunk.toString();
    });
    req.on("end", () => {
      if (exceeded) {
        const error = new Error("Request body too large");
        error.statusCode = 413;
        return reject(error);
      }
      if (!body) return resolve({});
      try {
        const parsed = JSON.parse(body);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error();
        resolve(parsed);
      } catch {
        const error = new Error("Request body must be a JSON object");
        error.statusCode = 400;
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function sendNodeJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
  res.end(JSON.stringify(data));
}

function toVercelRequest(req, body) {
  return { method: req.method, url: req.url, headers: req.headers, body };
}

function toVercelResponse(res) {
  return {
    statusCode: 200,
    setHeader(name, value) {
      res.setHeader(name, value);
      return this;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      sendNodeJson(res, this.statusCode, data);
      return this;
    },
    end() {
      res.statusCode = this.statusCode;
      res.end();
      return this;
    },
  };
}

module.exports = {
  allowMethods,
  boundedArray,
  boundedLimit,
  fetchWithTimeout,
  readJsonBody,
  sendNodeJson,
  setCors,
  toVercelRequest,
  toVercelResponse,
};
