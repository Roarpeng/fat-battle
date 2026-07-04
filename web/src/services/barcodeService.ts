export interface BarcodeResult {
  rawValue: string
  format: string
}

export type ScannerStatus = 'idle' | 'requesting' | 'scanning' | 'error'

export class BarcodeScannerService {
  private videoElement: HTMLVideoElement | null = null
  private canvasElement: HTMLCanvasElement | null = null
  private status: ScannerStatus = 'idle'
  private stream: MediaStream | null = null
  private animationId: number | null = null
  private onResult: ((result: BarcodeResult) => void) | null = null
  private onStatusChange: ((status: ScannerStatus) => void) | null = null
  private onError: ((error: Error) => void) | null = null
  private useZxing: boolean = false
  private zxingReader: any = null

  constructor(options: {
    videoElement?: HTMLVideoElement
    canvasElement?: HTMLCanvasElement
    onResult?: (result: BarcodeResult) => void
    onStatusChange?: (status: ScannerStatus) => void
    onError?: (error: Error) => void
  } = {}) {
    this.videoElement = options.videoElement || null
    this.canvasElement = options.canvasElement || null
    this.onResult = options.onResult || null
    this.onStatusChange = options.onStatusChange || null
    this.onError = options.onError || null
  }

  private setStatus(status: ScannerStatus) {
    this.status = status
    this.onStatusChange?.(status)
  }

  isSupported(): boolean {
    return 'BarcodeDetector' in window || this.useZxing
  }

  async start(facingMode: 'user' | 'environment' = 'environment'): Promise<void> {
    if (this.status === 'scanning') return

    this.setStatus('requesting')

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode, width: { ideal: 1280 }, height: { ideal: 720 } },
      })

      if (this.videoElement) {
        this.videoElement.srcObject = this.stream
        await this.videoElement.play()
      }

      this.setStatus('scanning')
      this.startDetectionLoop()
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error))
      this.setStatus('error')
      this.onError?.(err)
      throw err
    }
  }

  private async startDetectionLoop() {
    if (!this.videoElement || !this.canvasElement) return

    const ctx = this.canvasElement.getContext('2d')
    if (!ctx) return

    const detect = async () => {
      if (this.status !== 'scanning') return
      if (!this.videoElement || !this.canvasElement) return

      const video = this.videoElement
      const canvas = this.canvasElement

      if (video.readyState >= video.HAVE_CURRENT_DATA) {
        canvas.width = video.videoWidth
        canvas.height = video.videoHeight
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height)

        try {
          if ('BarcodeDetector' in window) {
            const detector = new (window as any).BarcodeDetector({
              formats: ['ean_13', 'ean_8', 'code_128', 'code_39', 'qr_code', 'data_matrix'],
            })
            const barcodes = await detector.detect(canvas)
            if (barcodes.length > 0) {
              const barcode = barcodes[0]
              this.onResult?.({
                rawValue: barcode.rawValue,
                format: barcode.format,
              })
            }
          }
        } catch (e) {
          // 静默失败，继续下一帧
        }
      }

      this.animationId = requestAnimationFrame(detect)
    }

    detect()
  }

  stop(): void {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
      this.animationId = null
    }

    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }

    if (this.videoElement) {
      this.videoElement.srcObject = null
    }

    this.setStatus('idle')
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.videoElement = video
  }

  setCanvasElement(canvas: HTMLCanvasElement): void {
    this.canvasElement = canvas
  }

  getStatus(): ScannerStatus {
    return this.status
  }

  async scanFromImage(imageFile: File): Promise<BarcodeResult[]> {
    return new Promise((resolve, reject) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        canvas.width = img.width
        canvas.height = img.height
        const ctx = canvas.getContext('2d')
        if (!ctx) {
          reject(new Error('无法创建 Canvas 上下文'))
          return
        }
        ctx.drawImage(img, 0, 0)

        if ('BarcodeDetector' in window) {
          const detector = new (window as any).BarcodeDetector()
          detector.detect(canvas)
            .then((barcodes: any[]) => {
              resolve(barcodes.map((b: any) => ({
                rawValue: b.rawValue,
                format: b.format,
              })))
            })
            .catch(reject)
        } else {
          reject(new Error('浏览器不支持条码检测'))
        }
      }
      img.onerror = () => reject(new Error('图片加载失败'))
      img.src = URL.createObjectURL(imageFile)
    })
  }
}
