import 'dotenv/config'
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'
import { fileURLToPath } from 'node:url'
import { BaiduClient } from './baiduClient.js'
import { MiniCPMClient } from './minicpmClient.js'
import { GlmClient } from './glmClient.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const distDir = path.join(__dirname, 'dist')

const PORT = 7860
const HOST = '0.0.0.0'

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.webmanifest': 'application/manifest+json',
}

function getContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase()
  return MIME_TYPES[ext] || 'application/octet-stream'
}

// === 百度 API 客户端单例 ===
const baiduClient = new BaiduClient()

// === MiniCPM-V API 客户端单例 ===
const minicpmClient = new MiniCPMClient()

// === GLM-4.6V-Flash API 客户端单例 ===
const glmClient = new GlmClient()

// === API 辅助函数 ===
function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload)
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  })
  res.end(body)
}

function readJsonBody(req, limitBytes = 10 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    req.on('data', (chunk) => {
      size += chunk.length
      if (size > limitBytes) {
        reject(new Error('请求体过大'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf-8')
      if (!raw) {
        resolve({})
        return
      }
      try {
        resolve(JSON.parse(raw))
      } catch (e) {
        reject(new Error('JSON 解析失败'))
      }
    })
    req.on('error', reject)
  })
}

// === 百度菜品识别 API 路由 ===
// 所有百度调用通过后端代理，API Key 不暴露到前端。
async function handleFoodRecognizeApi(req, res, urlPath) {
  // 健康检查
  if (urlPath === '/api/food-recognize/health' && req.method === 'GET') {
    sendJson(res, 200, {
      configured: baiduClient.isConfigured(),
      has_token: baiduClient.hasValidToken(),
    })
    return true
  }

  // 菜品识别
  if (urlPath === '/api/food-recognize' && req.method === 'POST') {
    try {
      const payload = await readJsonBody(req)
      const { image, topNum, filterThreshold } = payload
      if (!image || typeof image !== 'string') {
        sendJson(res, 400, {
          success: false,
          error: '缺少 image 字段（base64 字符串）',
          code: 'INVALID_IMAGE',
        })
        return true
      }

      const result = await baiduClient.recognizeFood(image, {
        topNum,
        filterThreshold,
      })
      sendJson(res, 200, {
        success: true,
        items: result.items ?? [],
        source: result.source ?? 'baidu',
        log_id: result.log_id,
      })
    } catch (err) {
      sendJson(res, 500, {
        success: false,
        error: err?.message ?? '识别失败',
        code: 'BAIDU_API_ERROR',
      })
    }
    return true
  }

  return false
}

// === MiniCPM-V 食物识别 API 路由 ===
async function handleMiniCPMApi(req, res, urlPath) {
  if (urlPath === '/api/minicpm/health' && req.method === 'GET') {
    sendJson(res, 200, {
      configured: minicpmClient.isConfigured(),
    })
    return true
  }

  if (urlPath === '/api/minicpm/recognize' && req.method === 'POST') {
    try {
      const payload = await readJsonBody(req)
      const { image, topNum } = payload
      if (!image || typeof image !== 'string') {
        sendJson(res, 400, {
          success: false,
          error: '缺少 image 字段（base64 字符串）',
          code: 'INVALID_IMAGE',
        })
        return true
      }

      const result = await minicpmClient.recognizeFood(image, { topNum })
      sendJson(res, 200, {
        success: true,
        items: result.items,
        source: 'minicpm',
        model: result.model,
        usage: result.usage,
      })
    } catch (err) {
      sendJson(res, 500, {
        success: false,
        error: err?.message ?? '识别失败',
        code: 'MINICPM_API_ERROR',
      })
    }
    return true
  }

  return false
}

// === GLM-4.6V-Flash 食物识别 API 路由 ===
async function handleGlmApi(req, res, urlPath) {
  if (urlPath === '/api/glm/health' && req.method === 'GET') {
    sendJson(res, 200, {
      configured: glmClient.isConfigured(),
      model: glmClient.model,
    })
    return true
  }

  if (urlPath === '/api/glm/recognize' && req.method === 'POST') {
    try {
      const payload = await readJsonBody(req)
      const { image, topNum, thinking } = payload
      if (!image || typeof image !== 'string') {
        sendJson(res, 400, {
          success: false,
          error: '缺少 image 字段（base64 字符串）',
          code: 'INVALID_IMAGE',
        })
        return true
      }

      console.log(
        `[GLM] 收到识别请求: 图片base64长度=${image.length}, topNum=${topNum}, thinking=${thinking}`
      )
      const t0 = Date.now()
      const result = await glmClient.recognizeFood(image, {
        topNum,
        thinking,
      })
      const elapsed = Date.now() - t0
      console.log(
        `[GLM] 识别完成: ${result.items.length} 个结果, 耗时=${elapsed}ms, model=${result.model}`
      )
      if (result.items.length > 0) {
        result.items.forEach((item, i) => {
          console.log(
            `  [${i + 1}] ${item.name} | 卡路里=${item.calorie}kcal/100g | 置信度=${item.confidence} | 类别=${item.category || 'N/A'}`
          )
        })
      }
      if (result.usage) {
        console.log(
          `[GLM] Token 用量: prompt=${result.usage.prompt_tokens}, completion=${result.usage.completion_tokens}, total=${result.usage.total_tokens}`
        )
      }
      sendJson(res, 200, {
        success: true,
        items: result.items,
        source: 'glm',
        model: result.model,
        usage: result.usage,
      })
    } catch (err) {
      console.error(`[GLM] 识别失败:`, err?.message ?? err)
      sendJson(res, 500, {
        success: false,
        error: err?.message ?? '识别失败',
        code: 'GLM_API_ERROR',
      })
    }
    return true
  }

  return false
}

const server = http.createServer(async (req, res) => {
  let urlPath = req.url.split('?')[0]
  const startTime = Date.now()

  // 原始 res.end 拦截，记录请求日志
  const originalEnd = res.end.bind(res)
  res.end = (chunk, encoding) => {
    const duration = Date.now() - startTime
    const status = res.statusCode
    const statusIcon = status >= 200 && status < 300 ? '✓' : '✗'
    console.log(
      `${statusIcon} ${req.method} ${urlPath} → ${status} (${duration}ms)`
    )
    return originalEnd(chunk, encoding)
  }

  // API 路由优先处理
  if (urlPath.startsWith('/api/')) {
    const handled = await handleFoodRecognizeApi(req, res, urlPath)
    if (handled) return
    const handledMiniCPM = await handleMiniCPMApi(req, res, urlPath)
    if (handledMiniCPM) return
    const handledGlm = await handleGlmApi(req, res, urlPath)
    if (handledGlm) return
  }

  if (urlPath === '/') {
    urlPath = '/index.html'
  }

  const filePath = path.join(distDir, urlPath)
  
  if (!filePath.startsWith(distDir)) {
    res.writeHead(403)
    res.end('Forbidden')
    return
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      const indexPath = path.join(distDir, 'index.html')
      fs.readFile(indexPath, (err, data) => {
        if (err) {
          res.writeHead(404)
          res.end('Not Found')
          return
        }
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
        res.end(data)
      })
      return
    }

    const contentType = getContentType(filePath)
    const cacheControl = urlPath.includes('/assets/') ? 'public, max-age=31536000, immutable' : 'no-cache'
    const acceptEncoding = req.headers['accept-encoding'] || ''
    const shouldGzip = acceptEncoding.includes('gzip') && (
      contentType.includes('javascript') ||
      contentType.includes('css') ||
      contentType.includes('html') ||
      contentType.includes('json') ||
      contentType.includes('svg')
    )

    if (shouldGzip) {
      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': cacheControl,
        'Content-Encoding': 'gzip',
        'Vary': 'Accept-Encoding'
      })
      fs.createReadStream(filePath).pipe(zlib.createGzip()).pipe(res)
    } else {
      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': cacheControl,
        'Content-Length': stats.size
      })
      fs.createReadStream(filePath).pipe(res)
    }
  })
})

server.listen(PORT, HOST, () => {
  console.log(`Server running at http://${HOST}:${PORT}`)
})
