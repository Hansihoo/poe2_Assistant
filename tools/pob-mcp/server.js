#!/usr/bin/env node
"use strict";

const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..", "..");
const defaultRuntime = path.join(repoRoot, "runtime", "Path{space}of{space}Building-PoE2.exe");
const defaultBridge = path.join(repoRoot, "src", "LaunchMcpBridge.lua");
const defaultCache = path.join(repoRoot, "src", "poe_api_response.json");
const defaultStatWeightsCmd = path.join(repoRoot, "PathOfBuilding-PoE2-StatWeights.cmd");
const defaultStatWeightsLauncher = path.join(repoRoot, "src", "LaunchStatWeights.lua");
const defaultWorkDir = process.env.POB2_WORK_DIR || path.join(repoRoot, "work");
const defaultStatWeightOutputDir = path.join(defaultWorkDir, "stat-weight-reports");

const SERVER_INFO = {
  name: "pob2-mcp",
  version: "0.1.0",
};

const DEFAULT_TIMEOUT_MS = Number(process.env.POB_MCP_TIMEOUT_MS || 120000);

const TOOLS = [
  {
    name: "pob_import_current",
    description:
      "Import the current character through existing PoB import routines. By default this uses the local cached poe_api_response.json. Live OAuth import is intentionally not used by this MCP v1.",
    inputSchema: {
      type: "object",
      properties: {
        source: {
          type: "string",
          enum: ["cached_json", "xml", "live"],
          default: "cached_json",
        },
        inputPath: {
          type: "string",
          description: "Path to cached character JSON or a PoB XML build.",
        },
        includePassives: { type: "boolean", default: true },
        includeItemsAndSkills: { type: "boolean", default: true },
        sections: {
          type: "array",
          items: { type: "string" },
          description:
            "State sections to return after import, for example metadata, equipment, skills, calcs, sidebar, warnings, config, schemas.",
        },
        stats: {
          type: "array",
          items: { type: "string" },
          description: "Specific PoB output stat keys to return.",
        },
        mainSocketGroup: {
          type: "integer",
          description: "Optional PoB skill group index to select before calculations.",
        },
        activeSkill: {
          type: "integer",
          description: "Optional active skill index inside mainSocketGroup.",
        },
        mainSkillName: {
          type: "string",
          description: "Optional skill/group name to select before calculations, for example Whirling Assault.",
        },
        includeRawItems: { type: "boolean", default: false },
      },
    },
  },
  {
    name: "pob_get_state",
    description:
      "Load a build and return selected PoB-managed state such as equipment, skill groups, config inputs, sidebar stats, warnings, and calculation outputs.",
    inputSchema: {
      type: "object",
      properties: {
        source: {
          type: "string",
          enum: ["cached_json", "xml", "none"],
          default: "cached_json",
        },
        inputPath: {
          type: "string",
          description: "Path to cached character JSON or PoB XML. Defaults to src/poe_api_response.json for cached_json.",
        },
        sections: {
          type: "array",
          items: { type: "string" },
          default: ["metadata", "equipment", "skills", "calcs", "sidebar", "warnings"],
        },
        stats: {
          type: "array",
          items: { type: "string" },
          description: "PoB output stat keys, including child paths such as MainHand.Accuracy.",
        },
        mainSocketGroup: {
          type: "integer",
          description: "Optional PoB skill group index to select before calculations.",
        },
        activeSkill: {
          type: "integer",
          description: "Optional active skill index inside mainSocketGroup.",
        },
        mainSkillName: {
          type: "string",
          description: "Optional skill/group name to select before calculations, for example Whirling Assault.",
        },
        skillCalcs: {
          type: "object",
          description:
            "When sections includes skillCalcs, optionally pass targets [{socketGroup, activeSkill}] and includeSidebar/maxTargets.",
        },
        includeRawItems: { type: "boolean", default: false },
        includeHiddenSlots: { type: "boolean", default: false },
      },
    },
  },
  {
    name: "pob_simulate_changes",
    description:
      "Load a build, apply temporary item/config/skill changes through existing PoB APIs, rebuild output, and return baseline/new/diff values. The source build is not saved.",
    inputSchema: {
      type: "object",
      required: ["changes"],
      properties: {
        source: {
          type: "string",
          enum: ["cached_json", "xml"],
          default: "cached_json",
        },
        inputPath: { type: "string" },
        changes: {
          type: "array",
          items: {
            type: "object",
            properties: {
              domain: { type: "string", enum: ["items", "config", "skills"] },
              action: { type: "string" },
              slot: { type: "string" },
              raw: { type: "string" },
              var: { type: "string" },
              value: {},
              socketGroup: { type: "integer" },
              activeSkill: { type: "integer" },
            },
          },
        },
        sections: {
          type: "array",
          items: { type: "string" },
          default: ["metadata", "equipment", "calcs", "sidebar", "warnings"],
        },
        stats: { type: "array", items: { type: "string" } },
        mainSocketGroup: {
          type: "integer",
          description: "Optional PoB skill group index for the baseline before applying changes.",
        },
        activeSkill: {
          type: "integer",
          description: "Optional active skill index inside mainSocketGroup for the baseline.",
        },
        mainSkillName: {
          type: "string",
          description: "Optional skill/group name for the baseline before applying changes.",
        },
        includeRawItems: { type: "boolean", default: false },
      },
    },
  },
  {
    name: "pob_set_state",
    description:
      "Apply changes through PoB APIs. mode=sandbox behaves like pob_simulate_changes. mode=commit writes an XML only when outputPath is explicitly supplied.",
    inputSchema: {
      type: "object",
      required: ["changes"],
      properties: {
        mode: { type: "string", enum: ["sandbox", "commit"], default: "sandbox" },
        source: {
          type: "string",
          enum: ["cached_json", "xml"],
          default: "cached_json",
        },
        inputPath: { type: "string" },
        outputPath: {
          type: "string",
          description: "Required for mode=commit. The MCP will write the resulting PoB XML here.",
        },
        changes: {
          type: "array",
          items: { type: "object" },
        },
        sections: {
          type: "array",
          items: { type: "string" },
          default: ["metadata", "equipment", "calcs", "sidebar", "warnings"],
        },
        stats: { type: "array", items: { type: "string" } },
      },
    },
  },
  {
    name: "pob_stat_weights",
    description:
      "Run the existing StatWeightReport launcher and return latest PoB stat weights. This wraps existing PoB code and calibration hooks.",
    inputSchema: {
      type: "object",
      properties: {
        inputPath: {
          type: "string",
          description: "Cached character JSON. Defaults to src/poe_api_response.json.",
        },
        outputDir: {
          type: "string",
          description: "Directory for latest.json/latest.md. Defaults to work/stat-weight-reports.",
        },
        mainSkill: { type: "string" },
        dpsMetric: { type: "string", default: "CombinedDPS" },
        calibrationPath: { type: "string" },
        timeoutMs: { type: "integer" },
      },
    },
  },
];

function makeTempPaths() {
  const tmpRoot = process.env.POB_MCP_TMP_DIR || path.join(defaultWorkDir, "mcp", "tmp");
  fs.mkdirSync(tmpRoot, { recursive: true });
  const dir = fs.mkdtempSync(path.join(tmpRoot, "pob-mcp-"));
  return {
    dir,
    requestPath: path.join(dir, "request.json"),
    outputPath: path.join(dir, "output.json"),
  };
}

function fileStat(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return {
      path: filePath,
      size: stat.size,
      mtime: stat.mtime.toISOString(),
    };
  } catch (err) {
    return {
      path: filePath,
      error: String(err && err.message ? err.message : err),
    };
  }
}

function spawnWithTimeout(command, args, options, timeoutMs) {
  return new Promise((resolve) => {
    const child = childProcess.spawn(command, args, {
      ...options,
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      try {
        child.kill();
      } catch (_) {
        // Ignore kill failures; exit/close will still report what happened.
      }
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({
        ok: false,
        error: String(err && err.message ? err.message : err),
        stdout,
        stderr,
        timedOut,
      });
    });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      resolve({
        ok: !timedOut && code === 0,
        code,
        signal,
        stdout,
        stderr,
        timedOut,
      });
    });
  });
}

function normalizeArgs(args = {}) {
  const normalized = { ...args };
  if (!normalized.inputPath && (!normalized.source || normalized.source === "cached_json")) {
    normalized.inputPath = defaultCache;
  }
  return normalized;
}

async function runBridge(tool, args = {}) {
  if (tool === "pob_stat_weights") {
    return runStatWeights(args);
  }

  const runtimePath = process.env.POB_MCP_RUNTIME || defaultRuntime;
  const bridgePath = process.env.POB_MCP_BRIDGE || defaultBridge;
  const normalizedArgs = normalizeArgs(args);
  const temp = makeTempPaths();
  const request = {
    tool,
    args: normalizedArgs,
    requestedAt: new Date().toISOString(),
    inputFile: normalizedArgs.inputPath ? fileStat(normalizedArgs.inputPath) : null,
  };

  fs.writeFileSync(temp.requestPath, JSON.stringify(request, null, 2), "utf8");

  const env = {
    ...process.env,
    POB_MCP_REQUEST: temp.requestPath,
    POB_MCP_OUTPUT: temp.outputPath,
  };
  const timeoutMs = Number(normalizedArgs.timeoutMs || DEFAULT_TIMEOUT_MS);
  const proc = await spawnWithTimeout(runtimePath, [bridgePath], { cwd: repoRoot, env }, timeoutMs);

  let output = null;
  let parseError = null;
  if (fs.existsSync(temp.outputPath)) {
    try {
      output = JSON.parse(fs.readFileSync(temp.outputPath, "utf8"));
    } catch (err) {
      parseError = String(err && err.message ? err.message : err);
    }
  }

  const result = output || {
    ok: false,
    error: parseError || "PoB MCP bridge did not write an output file.",
  };
  result.runner = {
    runtimePath,
    bridgePath,
    requestPath: temp.requestPath,
    outputPath: temp.outputPath,
    exitCode: proc.code,
    signal: proc.signal,
    timedOut: proc.timedOut,
    stdout: proc.stdout ? proc.stdout.slice(-4000) : "",
    stderr: proc.stderr ? proc.stderr.slice(-4000) : "",
  };
  if (!proc.ok && result.ok !== false) {
    result.ok = false;
    result.warning = `PoB runtime exited with code ${proc.code}`;
  }
  return result;
}

async function runStatWeights(args = {}) {
  const runtimePath = process.env.POB_MCP_RUNTIME || defaultRuntime;
  const launcherPath = process.env.POB_STAT_WEIGHTS_LAUNCHER || defaultStatWeightsLauncher;
  const outputDir = args.outputDir || process.env.POB_STAT_OUTPUT_DIR || defaultStatWeightOutputDir;
  const inputPath = args.inputPath || defaultCache;
  fs.mkdirSync(outputDir, { recursive: true });
  const env = {
    ...process.env,
    POB_STAT_INPUT: inputPath,
    POB_STAT_OUTPUT_DIR: outputDir,
  };
  if (args.mainSkill) env.POB_STAT_MAIN_SKILL = String(args.mainSkill);
  if (args.dpsMetric) env.POB_STAT_DPS_METRIC = String(args.dpsMetric);
  if (args.calibrationPath) env.POB_STAT_CALIBRATION = String(args.calibrationPath);

  const timeoutMs = Number(args.timeoutMs || 180000);
  const proc = await spawnWithTimeout(runtimePath, [launcherPath], { cwd: repoRoot, env }, timeoutMs);
  const latestJsonPath = path.join(outputDir, "latest.json");
  const latestMarkdownPath = path.join(outputDir, "latest.md");
  let report = null;
  let readError = null;
  try {
    report = JSON.parse(fs.readFileSync(latestJsonPath, "utf8"));
  } catch (err) {
    readError = String(err && err.message ? err.message : err);
  }

  return {
    ok: proc.ok && !!report,
    generatedAt: new Date().toISOString(),
    inputFile: fileStat(inputPath),
    outputDir,
    latestJsonPath,
    latestMarkdownPath,
    readError,
    report,
    runner: {
      cmdPath: defaultStatWeightsCmd,
      runtimePath,
      launcherPath,
      exitCode: proc.code,
      signal: proc.signal,
      timedOut: proc.timedOut,
      stdout: proc.stdout ? proc.stdout.slice(-4000) : "",
      stderr: proc.stderr ? proc.stderr.slice(-4000) : "",
    },
  };
}

function respond(id, result) {
  process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id, result }) + "\n");
}

function respondError(id, code, message, data) {
  process.stdout.write(
    JSON.stringify({
      jsonrpc: "2.0",
      id,
      error: {
        code,
        message,
        ...(data === undefined ? {} : { data }),
      },
    }) + "\n"
  );
}

function textResult(payload, isError = false) {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(payload, null, 2),
      },
    ],
    isError,
  };
}

async function handleRequest(message) {
  const id = message.id;
  const method = message.method;

  if (!method) {
    if (id !== undefined) respondError(id, -32600, "Invalid request");
    return;
  }

  if (id === undefined && method.startsWith("notifications/")) {
    return;
  }

  if (method === "initialize") {
    respond(id, {
      protocolVersion: message.params && message.params.protocolVersion ? message.params.protocolVersion : "2024-11-05",
      capabilities: {
        tools: {
          listChanged: false,
        },
        resources: {},
        prompts: {},
      },
      serverInfo: SERVER_INFO,
    });
    return;
  }

  if (method === "ping") {
    respond(id, {});
    return;
  }

  if (method === "tools/list") {
    respond(id, { tools: TOOLS });
    return;
  }

  if (method === "resources/list") {
    respond(id, { resources: [] });
    return;
  }

  if (method === "prompts/list") {
    respond(id, { prompts: [] });
    return;
  }

  if (method === "logging/setLevel") {
    respond(id, {});
    return;
  }

  if (method === "tools/call") {
    const params = message.params || {};
    const tool = TOOLS.find((entry) => entry.name === params.name);
    if (!tool) {
      respondError(id, -32602, `Unknown tool: ${params.name}`);
      return;
    }
    try {
      const payload = await runBridge(params.name, params.arguments || {});
      respond(id, textResult(payload, payload.ok === false));
    } catch (err) {
      respond(id, textResult({ ok: false, error: String(err && err.message ? err.message : err) }, true));
    }
    return;
  }

  respondError(id, -32601, `Method not found: ${method}`);
}

let buffer = "";
let pendingRequests = 0;
let stdinEnded = false;

function maybeExit() {
  if (stdinEnded && pendingRequests === 0) {
    process.exit(0);
  }
}

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  while (true) {
    const newline = buffer.indexOf("\n");
    if (newline < 0) break;
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    let message;
    try {
      message = JSON.parse(line);
    } catch (err) {
      respondError(null, -32700, "Parse error", String(err && err.message ? err.message : err));
      continue;
    }
    pendingRequests += 1;
    handleRequest(message)
      .catch((err) => {
        if (message.id !== undefined) {
          respondError(message.id, -32603, "Internal error", String(err && err.message ? err.message : err));
        }
      })
      .finally(() => {
        pendingRequests -= 1;
        maybeExit();
      });
  }
});

process.stdin.on("end", () => {
  stdinEnded = true;
  maybeExit();
});
