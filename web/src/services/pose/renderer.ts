// ========== 渲染层：Canvas 骨架/卡通人物渲染 ==========
import type { AvatarMode, CartoonColor } from '../poseTypes'
import {
  NOSE, LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_ELBOW, RIGHT_ELBOW,
  LEFT_WRIST, RIGHT_WRIST, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE,
  LEFT_ANKLE, RIGHT_ANKLE,
} from '../poseTypes'

export class PoseRenderer {
  private canvasElement: HTMLCanvasElement | null = null
  private canvasCtx: CanvasRenderingContext2D | null = null
  private resizeObserver: ResizeObserver | null = null
  private videoElement: HTMLVideoElement | null = null
  private cameraFacing: 'user' | 'environment' = 'user'
  private avatarMode: AvatarMode = 'cartoon'
  private cartoonColor: CartoonColor = 'orange'
  private gender: 'male' | 'female' = 'male'
  private drawX: number = 0
  private drawY: number = 0
  private drawWidth: number = 0
  private drawHeight: number = 0

  constructor(canvas?: HTMLCanvasElement) {
    if (canvas) {
      this.canvasElement = canvas
      this.canvasCtx = canvas.getContext('2d')
      if (canvas.width === 0) {
        canvas.width = 640
      }
      if (canvas.height === 0) {
        canvas.height = 480
      }
    }
  }

  // ========== 配置 ==========

  setCanvas(canvas: HTMLCanvasElement): void {
    // 清理旧的 ResizeObserver
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }

    this.canvasElement = canvas
    this.canvasCtx = canvas.getContext('2d')
    this.resizeCanvas()

    // 监听 canvas 容器尺寸变化，自动调整内部分辨率
    if (typeof ResizeObserver !== 'undefined') {
      this.resizeObserver = new ResizeObserver(() => {
        this.resizeCanvas()
      })
      this.resizeObserver.observe(canvas)
    }
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.videoElement = video
  }

  getVideoElement(): HTMLVideoElement | null {
    return this.videoElement
  }

  setCameraFacing(facing: 'user' | 'environment'): void {
    this.cameraFacing = facing
  }

  getCameraFacing(): 'user' | 'environment' {
    return this.cameraFacing
  }

  setAvatarMode(mode: AvatarMode): void {
    this.avatarMode = mode
  }

  getAvatarMode(): AvatarMode {
    return this.avatarMode
  }

  setCartoonColor(color: CartoonColor): void {
    this.cartoonColor = color
  }

  getCartoonColor(): CartoonColor {
    return this.cartoonColor
  }

  setGender(gender: 'male' | 'female'): void {
    this.gender = gender
  }

  getGender(): 'male' | 'female' {
    return this.gender
  }

  resizeCanvas(): void {
    if (!this.canvasElement) return

    const rect = this.canvasElement.getBoundingClientRect()
    const dpr = window.devicePixelRatio || 1

    const newWidth = Math.round(rect.width * dpr)
    const newHeight = Math.round(rect.height * dpr)

    if (this.canvasElement.width !== newWidth || this.canvasElement.height !== newHeight) {
      this.canvasElement.width = newWidth
      this.canvasElement.height = newHeight
    }
  }

  capturePhoto(): string | null {
    if (!this.canvasElement) return null
    return this.canvasElement.toDataURL('image/png')
  }

  dispose(): void {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
  }

  // ========== 绘制 ==========

  drawBackground(results: any): void {
    if (!this.canvasElement || !this.canvasCtx) {
      return
    }

    const ctx = this.canvasCtx
    const canvasWidth = this.canvasElement.width
    const canvasHeight = this.canvasElement.height
    const dpr = window.devicePixelRatio || 1

    ctx.save()
    ctx.clearRect(0, 0, canvasWidth, canvasHeight)

    if (this.cameraFacing === 'user') {
      ctx.translate(canvasWidth, 0)
      ctx.scale(-1, 1)
    }

    if (this.avatarMode === 'real' && this.videoElement && this.videoElement.readyState >= 2) {
      ctx.drawImage(this.videoElement, 0, 0, canvasWidth, canvasHeight)
    } else {
      // 温暖渐变背景 - 告别恐怖深蓝
      const gradient = ctx.createLinearGradient(0, 0, 0, canvasHeight)
      gradient.addColorStop(0, '#FFF5E6')
      gradient.addColorStop(0.4, '#FFE8D6')
      gradient.addColorStop(1, '#FFD4B8')
      ctx.fillStyle = gradient
      ctx.fillRect(0, 0, canvasWidth, canvasHeight)

      // 柔和的装饰性圆点背景
      ctx.fillStyle = 'rgba(255, 159, 67, 0.06)'
      const dotSpacing = 50 * dpr
      for (let y = 0; y < canvasHeight; y += dotSpacing) {
        for (let x = 0; x < canvasWidth; x += dotSpacing) {
          ctx.beginPath()
          ctx.arc(x, y, 2 * dpr, 0, 2 * Math.PI)
          ctx.fill()
        }
      }
    }

    this.drawX = 0
    this.drawY = 0
    this.drawWidth = canvasWidth
    this.drawHeight = canvasHeight

    if (!results.poseLandmarks) {
      ctx.fillStyle = 'rgba(0, 0, 0, 0.5)'
      ctx.fillRect(0, 0, canvasWidth, canvasHeight)
      ctx.fillStyle = '#ffffff'
      ctx.font = `bold ${14 * dpr}px Arial`
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText('请将身体对准摄像头', Math.round(canvasWidth / 2), Math.round(canvasHeight / 2 - 8 * dpr))
      ctx.font = `${11 * dpr}px Arial`
      ctx.fillStyle = 'rgba(255, 255, 255, 0.7)'
      ctx.fillText('确保全身出现在画面中', Math.round(canvasWidth / 2), Math.round(canvasHeight / 2 + 14 * dpr))
      ctx.textAlign = 'left'
      ctx.textBaseline = 'alphabetic'
    }

    ctx.restore()
  }

  drawCharacter(results: any): void {
    if (!this.canvasElement || !this.canvasCtx || !results.poseLandmarks) {
      return
    }

    const ctx = this.canvasCtx
    const canvasWidth = this.canvasElement.width
    const landmarks = results.poseLandmarks
    const dpr = window.devicePixelRatio || 1

    ctx.save()

    if (this.cameraFacing === 'user') {
      ctx.translate(canvasWidth, 0)
      ctx.scale(-1, 1)
    }

    const mapX = (x: number) => this.drawX + x * this.drawWidth
    const mapY = (y: number) => this.drawY + y * this.drawHeight

    const isValid = (p: any) => p && p.visibility >= 0.5

    if (this.avatarMode === 'real') {
      this.drawSkeleton(ctx, landmarks, mapX, mapY, isValid, dpr)
    } else {
      this.drawCartoon(ctx, landmarks, mapX, mapY, isValid, dpr)
    }

    ctx.restore()
  }

  private drawSkeleton(
    ctx: CanvasRenderingContext2D,
    landmarks: any[],
    mapX: (x: number) => number,
    mapY: (y: number) => number,
    isValid: (p: any) => boolean,
    dpr: number
  ): void {
    const lineColorMap: Record<CartoonColor, { line: string; joint: string }> = {
      orange: { line: '#FF9F43', joint: '#FDDCB5' },
      mint: { line: '#55EFC4', joint: '#FDDCB5' },
      pink: { line: '#FF6B6B', joint: '#FFE0D0' },
      lavender: { line: '#A29BFE', joint: '#FDDCB5' },
    }
    const colors = lineColorMap[this.cartoonColor] || lineColorMap.orange

    const lineWidth = Math.max(3, 4 * dpr)
    const jointRadius = Math.max(4, 6 * dpr)

    ctx.strokeStyle = colors.line
    ctx.lineWidth = lineWidth
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'

    const connections = [
      [NOSE, LEFT_SHOULDER],
      [NOSE, RIGHT_SHOULDER],
      [LEFT_SHOULDER, RIGHT_SHOULDER],
      [LEFT_SHOULDER, LEFT_ELBOW],
      [RIGHT_SHOULDER, RIGHT_ELBOW],
      [LEFT_ELBOW, LEFT_WRIST],
      [RIGHT_ELBOW, RIGHT_WRIST],
      [LEFT_SHOULDER, LEFT_HIP],
      [RIGHT_SHOULDER, RIGHT_HIP],
      [LEFT_HIP, RIGHT_HIP],
      [LEFT_HIP, LEFT_KNEE],
      [RIGHT_HIP, RIGHT_KNEE],
      [LEFT_KNEE, LEFT_ANKLE],
      [RIGHT_KNEE, RIGHT_ANKLE],
    ]

    connections.forEach(([start, end]) => {
      const p1 = landmarks[start]
      const p2 = landmarks[end]
      if (isValid(p1) && isValid(p2)) {
        ctx.beginPath()
        ctx.moveTo(mapX(p1.x), mapY(p1.y))
        ctx.lineTo(mapX(p2.x), mapY(p2.y))
        ctx.stroke()
      }
    })

    ctx.fillStyle = colors.joint
    const jointIndices = [NOSE, LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_ELBOW, RIGHT_ELBOW, LEFT_WRIST, RIGHT_WRIST, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE]
    jointIndices.forEach((idx) => {
      const p = landmarks[idx]
      if (isValid(p)) {
        ctx.beginPath()
        ctx.arc(mapX(p.x), mapY(p.y), jointRadius, 0, 2 * Math.PI)
        ctx.fill()
      }
    })
  }

  private drawCartoon(
    ctx: CanvasRenderingContext2D,
    landmarks: any[],
    mapX: (x: number) => number,
    mapY: (y: number) => number,
    isValid: (p: any) => boolean,
    dpr: number
  ): void {
    const isMale = this.gender === 'male'

    // ========== 温暖可爱的配色方案（告别恐怖蓝白灰）==========
    // 核心原则：暖色肤色 + 柔和服饰 + 腮红点缀 + 立体渐变
    const palettes: Record<CartoonColor, {
      skin: string; skinLight: string; skinShadow: string; skinBlush: string;
      hair: string; hairHighlight: string;
      outfit: string; outfitLight: string; outfitDark: string;
      pants: string; pantsDark: string;
      shoe: string; shoeAccent: string;
      eye: string; eyeHighlight: string;
      outline: string;
    }> = {
      orange: {
        skin: '#FDDCB5', skinLight: '#FFE8D6', skinShadow: '#E8B896', skinBlush: '#FF8A80',
        hair: '#C8956C', hairHighlight: '#DBA87A',
        outfit: '#FF9F43', outfitLight: '#FFB976', outfitDark: '#E88A2A',
        pants: '#5D4037', pantsDark: '#4E342E',
        shoe: '#E88A2A', shoeAccent: '#FF9F43',
        eye: '#5D4037', eyeHighlight: '#FFFFFF',
        outline: '#8D6E63',
      },
      mint: {
        skin: '#FDDCB5', skinLight: '#FFE8D6', skinShadow: '#E8B896', skinBlush: '#FF8A80',
        hair: '#4A6741', hairHighlight: '#6B8F5B',
        outfit: '#55EFC4', outfitLight: '#81FFDB', outfitDark: '#00C9A7',
        pants: '#45B7AA', pantsDark: '#3A9E91',
        shoe: '#2D8F82', shoeAccent: '#55EFC4',
        eye: '#3E6B5E', eyeHighlight: '#FFFFFF',
        outline: '#6B8F5B',
      },
      pink: {
        skin: '#FFE0D0', skinLight: '#FFEBE5', skinShadow: '#F0C0A8', skinBlush: '#FF6B81',
        hair: '#8B4513', hairHighlight: '#A0522D',
        outfit: '#FF6B6B', outfitLight: '#FF8E8E', outfitDark: '#E85555',
        pants: '#C44569', pantsDark: '#A83858',
        shoe: '#E85555', shoeAccent: '#FF6B6B',
        eye: '#5D3A3A', eyeHighlight: '#FFFFFF',
        outline: '#C44569',
      },
      lavender: {
        skin: '#FDDCB5', skinLight: '#FFE8D6', skinShadow: '#E8B896', skinBlush: '#FF8A80',
        hair: '#6C5B7B', hairHighlight: '#8E7CA3',
        outfit: '#A29BFE', outfitLight: '#BDB6FF', outfitDark: '#7C73E6',
        pants: '#6C5CE7', pantsDark: '#5A4BD1',
        shoe: '#5A4BD1', shoeAccent: '#A29BFE',
        eye: '#5D4037', eyeHighlight: '#FFFFFF',
        outline: '#8E7CA3',
      },
    }

    const colors = palettes[this.cartoonColor] || palettes.orange

    const nose = landmarks[NOSE]
    const lShoulder = landmarks[LEFT_SHOULDER]
    const rShoulder = landmarks[RIGHT_SHOULDER]
    const lElbow = landmarks[LEFT_ELBOW]
    const rElbow = landmarks[RIGHT_ELBOW]
    const lWrist = landmarks[LEFT_WRIST]
    const rWrist = landmarks[RIGHT_WRIST]
    const lHip = landmarks[LEFT_HIP]
    const rHip = landmarks[RIGHT_HIP]
    const lKnee = landmarks[LEFT_KNEE]
    const rKnee = landmarks[RIGHT_KNEE]
    const lAnkle = landmarks[LEFT_ANKLE]
    const rAnkle = landmarks[RIGHT_ANKLE]

    const shoulderMid = {
      x: (lShoulder.x + rShoulder.x) / 2,
      y: (lShoulder.y + rShoulder.y) / 2,
    }
    const hipMid = {
      x: (lHip.x + rHip.x) / 2,
      y: (lHip.y + rHip.y) / 2,
    }

    const shoulderWidth = Math.abs(mapX(lShoulder.x) - mapX(rShoulder.x))
    // Q版比例：更大的头部、更粗的四肢
    const headR = Math.max(16 * dpr, shoulderWidth * 0.38)
    const limbWidth = Math.max(6 * dpr, shoulderWidth * 0.2)
    const torsoWidth = shoulderWidth * 1.0

    // ========== 辅助绘制函数 ==========

    // 圆润的四肢（使用渐变填充的粗线条 + 轮廓线，而非纯线条）
    const drawLimb = (p1: any, p2: any, color: string, w: number, outlineColor: string) => {
      if (!isValid(p1) || !isValid(p2)) return
      const x1 = mapX(p1.x), y1 = mapY(p1.y)
      const x2 = mapX(p2.x), y2 = mapY(p2.y)
      // 轮廓线（比填充稍宽）
      ctx.strokeStyle = outlineColor
      ctx.lineWidth = w + 2 * dpr
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.beginPath()
      ctx.moveTo(x1, y1)
      ctx.lineTo(x2, y2)
      ctx.stroke()
      // 主色填充
      ctx.strokeStyle = color
      ctx.lineWidth = w
      ctx.beginPath()
      ctx.moveTo(x1, y1)
      ctx.lineTo(x2, y2)
      ctx.stroke()
    }

    // 圆润关节（带轮廓）
    const drawJoint = (p: any, r: number, color: string) => {
      if (!isValid(p)) return
      const x = mapX(p.x), y = mapY(p.y)
      // 轮廓
      ctx.fillStyle = colors.outline
      ctx.beginPath()
      ctx.arc(x, y, r + 1 * dpr, 0, 2 * Math.PI)
      ctx.fill()
      // 主体
      ctx.fillStyle = color
      ctx.beginPath()
      ctx.arc(x, y, r, 0, 2 * Math.PI)
      ctx.fill()
    }

    // 圆润鞋子（带轮廓和高光）
    const drawShoe = (ankle: any) => {
      if (!isValid(ankle)) return
      const x = mapX(ankle.x), y = mapY(ankle.y) + limbWidth * 0.3
      const sw = limbWidth * 0.9, sh = limbWidth * 0.55
      // 轮廓
      ctx.fillStyle = colors.outline
      ctx.beginPath()
      ctx.ellipse(x, y, sw + 1 * dpr, sh + 1 * dpr, 0, 0, 2 * Math.PI)
      ctx.fill()
      // 鞋子主体
      ctx.fillStyle = colors.shoe
      ctx.beginPath()
      ctx.ellipse(x, y, sw, sh, 0, 0, 2 * Math.PI)
      ctx.fill()
      // 鞋子高光
      ctx.fillStyle = colors.shoeAccent
      ctx.beginPath()
      ctx.ellipse(x - sw * 0.2, y - sh * 0.2, sw * 0.4, sh * 0.25, -0.3, 0, 2 * Math.PI)
      ctx.fill()
    }

    // ========== 绘制腿部 ==========
    drawLimb(lHip, lKnee, colors.pants, limbWidth * 1.2, colors.outline)
    drawLimb(lKnee, lAnkle, colors.pantsDark, limbWidth * 1.1, colors.outline)
    drawLimb(rHip, rKnee, colors.pants, limbWidth * 1.2, colors.outline)
    drawLimb(rKnee, rAnkle, colors.pantsDark, limbWidth * 1.1, colors.outline)

    // 鞋子
    drawShoe(lAnkle)
    drawShoe(rAnkle)

    // ========== 绘制躯干（圆润的梯形 + 渐变 + 轮廓）==========
    if (isValid(lShoulder) && isValid(rShoulder) && isValid(lHip) && isValid(rHip)) {
      const sx = mapX(lShoulder.x), sy = mapY(lShoulder.y)
      const ex = mapX(rShoulder.x), ey = mapY(rShoulder.y)
      const lhx = mapX(lHip.x), lhy = mapY(lHip.y)
      const rhx = mapX(rHip.x), rhy = mapY(rHip.y)

      // 轮廓线
      const drawTorsoShape = (offset: number) => {
        ctx.beginPath()
        ctx.moveTo(sx - offset, sy - offset)
        ctx.lineTo(ex + offset, ey - offset)
        const waistOffset = torsoWidth * 0.08
        ctx.quadraticCurveTo(
          (ex + rhx) / 2 + waistOffset + offset, (ey + rhy) / 2 - offset,
          rhx + offset, rhy + offset
        )
        ctx.lineTo(lhx - offset, lhy + offset)
        ctx.quadraticCurveTo(
          (sx + lhx) / 2 - waistOffset - offset, (sy + lhy) / 2 - offset,
          sx - offset, sy - offset
        )
        ctx.closePath()
      }

      // 先画轮廓
      ctx.fillStyle = colors.outline
      drawTorsoShape(1.5 * dpr)
      ctx.fill()

      // 再画主体（渐变填充，增加立体感）
      const torsoGrad = ctx.createLinearGradient(
        mapX(shoulderMid.x), sy, mapX(hipMid.x), lhy
      )
      torsoGrad.addColorStop(0, colors.outfitLight)
      torsoGrad.addColorStop(0.5, colors.outfit)
      torsoGrad.addColorStop(1, colors.outfitDark)
      ctx.fillStyle = torsoGrad
      drawTorsoShape(0)
      ctx.fill()

      // 上衣装饰线（更柔和）
      ctx.strokeStyle = colors.outfitDark
      ctx.lineWidth = 1 * dpr
      ctx.globalAlpha = 0.3
      ctx.beginPath()
      ctx.moveTo(mapX(shoulderMid.x), mapY(shoulderMid.y))
      ctx.lineTo(mapX(hipMid.x), mapY(hipMid.y))
      ctx.stroke()
      ctx.globalAlpha = 1.0
    }

    // ========== 绘制手臂 ==========
    drawLimb(lShoulder, lElbow, colors.outfit, limbWidth * 1.1, colors.outline)
    drawLimb(lElbow, lWrist, colors.skin, limbWidth * 0.95, colors.skinShadow)
    drawLimb(rShoulder, rElbow, colors.outfit, limbWidth * 1.1, colors.outline)
    drawLimb(rElbow, rWrist, colors.skin, limbWidth * 0.95, colors.skinShadow)

    // 圆润手掌（带轮廓 + 高光）
    const drawHand = (wrist: any) => {
      if (!isValid(wrist)) return
      const x = mapX(wrist.x), y = mapY(wrist.y)
      const r = limbWidth * 0.6
      // 轮廓
      ctx.fillStyle = colors.skinShadow
      ctx.beginPath()
      ctx.arc(x, y, r + 1 * dpr, 0, 2 * Math.PI)
      ctx.fill()
      // 主体（渐变）
      const handGrad = ctx.createRadialGradient(
        x - r * 0.2, y - r * 0.2, r * 0.05,
        x, y, r
      )
      handGrad.addColorStop(0, colors.skinLight)
      handGrad.addColorStop(1, colors.skin)
      ctx.fillStyle = handGrad
      ctx.beginPath()
      ctx.arc(x, y, r, 0, 2 * Math.PI)
      ctx.fill()
    }
    drawHand(lWrist)
    drawHand(rWrist)

    // 关节
    drawJoint(lElbow, limbWidth * 0.5, colors.outfit)
    drawJoint(rElbow, limbWidth * 0.5, colors.outfit)
    drawJoint(lKnee, limbWidth * 0.55, colors.pants)

    // ========== 绘制头部（大圆头 + 渐变 + 腮红 + 大眼睛 + 微笑）==========
    if (isValid(nose)) {
      const hx = mapX(nose.x)
      const hy = mapY(nose.y)

      // --- 头发背景（女性长发在头后面）---
      if (!isMale) {
        ctx.fillStyle = colors.outline
        ctx.beginPath()
        ctx.ellipse(hx, hy + headR * 0.25, headR * 1.3, headR * 1.65, 0, 0, 2 * Math.PI)
        ctx.fill()
        ctx.fillStyle = colors.hair
        ctx.beginPath()
        ctx.ellipse(hx, hy + headR * 0.25, headR * 1.25, headR * 1.6, 0, 0, 2 * Math.PI)
        ctx.fill()
      }

      // --- 头部轮廓 ---
      ctx.fillStyle = colors.outline
      ctx.beginPath()
      ctx.arc(hx, hy, headR + 1.5 * dpr, 0, 2 * Math.PI)
      ctx.fill()

      // --- 头部主体（径向渐变，立体感）---
      const headGrad = ctx.createRadialGradient(
        hx - headR * 0.25, hy - headR * 0.25, headR * 0.02,
        hx, hy, headR
      )
      headGrad.addColorStop(0, colors.skinLight)
      headGrad.addColorStop(0.6, colors.skin)
      headGrad.addColorStop(1, colors.skinShadow)
      ctx.fillStyle = headGrad
      ctx.beginPath()
      ctx.arc(hx, hy, headR, 0, 2 * Math.PI)
      ctx.fill()

      // --- 头发 ---
      ctx.fillStyle = colors.hair
      if (isMale) {
        // 男性短发（圆润弧形）
        ctx.beginPath()
        ctx.arc(hx, hy - headR * 0.05, headR * 1.02, Math.PI * 1.0, Math.PI * 2.0, false)
        ctx.quadraticCurveTo(hx + headR * 1.1, hy - headR * 0.1, hx + headR * 0.85, hy + headR * 0.15)
        ctx.lineTo(hx + headR * 0.6, hy - headR * 0.35)
        ctx.lineTo(hx + headR * 0.3, hy + headR * 0.05)
        ctx.lineTo(hx, hy - headR * 0.55)
        ctx.lineTo(hx - headR * 0.3, hy + headR * 0.05)
        ctx.lineTo(hx - headR * 0.6, hy - headR * 0.35)
        ctx.lineTo(hx - headR * 0.85, hy + headR * 0.15)
        ctx.quadraticCurveTo(hx - headR * 1.1, hy - headR * 0.1, hx - headR * 1.02, hy - headR * 0.05)
        ctx.closePath()
        ctx.fill()
      } else {
        // 女性长发（更圆润的弧形）
        ctx.beginPath()
        ctx.arc(hx, hy - headR * 0.05, headR * 1.08, Math.PI * 0.95, Math.PI * 2.05, false)
        ctx.quadraticCurveTo(hx + headR * 1.2, hy + headR * 0.3, hx + headR * 0.7, hy + headR * 0.1)
        ctx.lineTo(hx + headR * 0.4, hy - headR * 0.15)
        ctx.lineTo(hx + headR * 0.15, hy + headR * 0.1)
        ctx.lineTo(hx, hy - headR * 0.3)
        ctx.lineTo(hx - headR * 0.15, hy + headR * 0.1)
        ctx.lineTo(hx - headR * 0.4, hy - headR * 0.15)
        ctx.lineTo(hx - headR * 0.7, hy + headR * 0.1)
        ctx.quadraticCurveTo(hx - headR * 1.2, hy + headR * 0.3, hx - headR * 1.08, hy - headR * 0.05)
        ctx.closePath()
        ctx.fill()
      }

      // --- 头发高光 ---
      ctx.fillStyle = colors.hairHighlight
      if (isMale) {
        ctx.beginPath()
        ctx.ellipse(hx - headR * 0.15, hy - headR * 0.55, headR * 0.3, headR * 0.12, -0.3, 0, 2 * Math.PI)
        ctx.fill()
      } else {
        ctx.beginPath()
        ctx.ellipse(hx - headR * 0.25, hy - headR * 0.45, headR * 0.35, headR * 0.1, -0.2, 0, 2 * Math.PI)
        ctx.fill()
      }

      // --- 大眼睛（Q版大眼 + 高光）---
      const eyeY = hy + headR * 0.08
      const eyeOffsetX = headR * 0.32
      const eyeR = headR * 0.16  // 比原来更大

      // 眼白（带轮廓）
      const drawEye = (ex: number, ey: number) => {
        // 轮廓
        ctx.fillStyle = colors.outline
        ctx.beginPath()
        ctx.ellipse(ex, ey, eyeR + 1 * dpr, eyeR * 1.15 + 1 * dpr, 0, 0, 2 * Math.PI)
        ctx.fill()
        // 眼白
        ctx.fillStyle = '#ffffff'
        ctx.beginPath()
        ctx.ellipse(ex, ey, eyeR, eyeR * 1.15, 0, 0, 2 * Math.PI)
        ctx.fill()
        // 瞳孔（更大更明显）
        ctx.fillStyle = colors.eye
        ctx.beginPath()
        ctx.arc(ex, ey + eyeR * 0.1, eyeR * 0.65, 0, 2 * Math.PI)
        ctx.fill()
        // 瞳孔内部深色
        ctx.fillStyle = '#2D1B1B'
        ctx.beginPath()
        ctx.arc(ex, ey + eyeR * 0.15, eyeR * 0.4, 0, 2 * Math.PI)
        ctx.fill()
        // 高光（双高光 - 增加灵动感）
        ctx.fillStyle = colors.eyeHighlight
        ctx.beginPath()
        ctx.arc(ex + eyeR * 0.25, ey - eyeR * 0.2, eyeR * 0.28, 0, 2 * Math.PI)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(ex - eyeR * 0.15, ey + eyeR * 0.3, eyeR * 0.15, 0, 2 * Math.PI)
        ctx.fill()
      }

      drawEye(hx - eyeOffsetX, eyeY)
      drawEye(hx + eyeOffsetX, eyeY)

      // --- 腮红（男女都有，增加可爱感）---
      const blushR = headR * 0.18
      const blushY = hy + headR * 0.3

      const drawBlush = (bx: number, by: number) => {
        const blushGrad = ctx.createRadialGradient(bx, by, 0, bx, by, blushR)
        blushGrad.addColorStop(0, colors.skinBlush)
        blushGrad.addColorStop(0.6, colors.skinBlush.replace(')', ', 0.4)').replace('rgb', 'rgba'))
        blushGrad.addColorStop(1, 'rgba(255, 138, 128, 0)')
        ctx.fillStyle = blushGrad
        ctx.beginPath()
        ctx.ellipse(bx, by, blushR * 1.2, blushR * 0.8, 0, 0, 2 * Math.PI)
        ctx.fill()
      }

      // 简单实现腮红渐变
      const drawBlushSimple = (bx: number, by: number) => {
        ctx.globalAlpha = 0.35
        ctx.fillStyle = colors.skinBlush
        ctx.beginPath()
        ctx.ellipse(bx, by, blushR * 1.1, blushR * 0.7, 0, 0, 2 * Math.PI)
        ctx.fill()
        ctx.globalAlpha = 1.0
      }

      drawBlushSimple(hx - headR * 0.5, blushY)
      drawBlushSimple(hx + headR * 0.5, blushY)

      // --- 微笑嘴巴（温暖的弧线）---
      ctx.strokeStyle = '#E88A6A'  // 温暖的珊瑚橙，而非冷红色
      ctx.lineWidth = Math.max(1.5, 2 * dpr)
      ctx.lineCap = 'round'
      ctx.beginPath()
      ctx.arc(hx, hy + headR * 0.35, headR * 0.18, 0.15 * Math.PI, 0.85 * Math.PI)
      ctx.stroke()

      // --- 鼻子（小巧的点）---
      ctx.fillStyle = colors.skinShadow
      ctx.beginPath()
      ctx.arc(hx, hy + headR * 0.22, headR * 0.06, 0, 2 * Math.PI)
      ctx.fill()
    }
  }

  drawPauseOverlay(progress: number): void {
    if (!this.canvasElement || !this.canvasCtx) return
    const ctx = this.canvasCtx
    const w = this.canvasElement.width
    const h = this.canvasElement.height
    const dpr = window.devicePixelRatio || 1

    ctx.save()
    ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'
    ctx.fillRect(0, 0, w, h)

    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'

    // 暂停图标 ⏸
    ctx.fillStyle = '#ffffff'
    ctx.font = `bold ${20 * dpr}px Arial`
    ctx.fillText('⏸ 游戏暂停', w / 2, h / 2 - 20 * dpr)

    ctx.font = `${11 * dpr}px Arial`
    ctx.fillStyle = 'rgba(255, 255, 255, 0.7)'
    ctx.fillText('请回到摄像头范围内继续', w / 2, h / 2 + 8 * dpr)

    // 倒计时进度环
    const ringR = 28 * dpr
    const ringX = w / 2
    const ringY = h / 2 + 50 * dpr
    const clampedProgress = Math.min(1, progress)

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)'
    ctx.lineWidth = 3 * dpr
    ctx.beginPath()
    ctx.arc(ringX, ringY, ringR, 0, 2 * Math.PI)
    ctx.stroke()

    if (clampedProgress > 0) {
      ctx.strokeStyle = '#4ADE80'
      ctx.lineWidth = 3 * dpr
      ctx.beginPath()
      ctx.arc(ringX, ringY, ringR, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * clampedProgress)
      ctx.stroke()
    }

    ctx.font = `bold ${10 * dpr}px Arial`
    ctx.fillStyle = '#ffffff'
    ctx.fillText('等待返回...', ringX, ringY)

    ctx.textAlign = 'left'
    ctx.textBaseline = 'alphabetic'
    ctx.restore()
  }
}
