import { withRetry, withTimeout, RetryTimeoutError, type RetryOptions } from './retry'

export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'error' | 'reconnecting'

export interface ImuData {
  ax: number
  ay: number
  az: number
  gx: number
  gy: number
  gz: number
  timestamp: number
}

export interface BluetoothServiceOptions {
  serviceUUID?: string
  characteristicUUID?: string
  onData?: (data: ImuData) => void
  onStatusChange?: (status: ConnectionStatus) => void
  onError?: (error: Error) => void
  onDisconnect?: () => void
  autoReconnect?: boolean
  maxReconnectAttempts?: number
  /** GATT 连接重试次数，默认 3 */
  connectRetries?: number
  /** 单次 GATT 连接超时(ms)，默认 10000 */
  connectTimeoutMs?: number
  /** GATT 连接重试初始延迟(ms)，默认 1000 */
  connectRetryDelay?: number
  /** 是否启用 GATT 连接重试，默认 true */
  enableConnectRetry?: boolean
}

/** 蓝牙不可用错误（浏览器不支持或设备不可用） */
export class BluetoothNotAvailableError extends Error {
  constructor(message = '蓝牙不可用') {
    super(message)
    this.name = 'BluetoothNotAvailableError'
    Object.setPrototypeOf(this, BluetoothNotAvailableError.prototype)
  }
}

const DEFAULT_SERVICE_UUID = '4fafc201-1fb5-459e-8fcc-c5c9c331914b'
const DEFAULT_MAX_RECONNECT_ATTEMPTS = 5
const RECONNECT_DELAY_BASE = 1000
const DEFAULT_CONNECT_RETRIES = 3
const DEFAULT_CONNECT_TIMEOUT_MS = 10000
const DEFAULT_CONNECT_RETRY_DELAY = 1000

declare global {
  interface Navigator {
    bluetooth?: {
      requestDevice(options: RequestDeviceOptions): Promise<BluetoothDevice>
      getAvailability(): Promise<boolean>
    }
  }

  interface BluetoothDevice {
    id: string
    name?: string
    gatt?: BluetoothRemoteGATTServer
    addEventListener(type: 'gattserverdisconnected', listener: (event: Event) => void): void
    removeEventListener(type: 'gattserverdisconnected', listener: (event: Event) => void): void
    watchAdvertisements?(): Promise<void>
  }

  interface BluetoothRemoteGATTServer {
    connected: boolean
    connect(): Promise<BluetoothRemoteGATTServer>
    disconnect(): void
    getPrimaryService(service: string | number): Promise<BluetoothRemoteGATTService>
  }

  interface BluetoothRemoteGATTService {
    getCharacteristic(characteristic: string | number): Promise<BluetoothRemoteGATTCharacteristic>
    getCharacteristics(): Promise<BluetoothRemoteGATTCharacteristic[]>
  }

  interface BluetoothRemoteGATTCharacteristic {
    value?: DataView
    startNotifications(): Promise<BluetoothRemoteGATTCharacteristic>
    stopNotifications(): Promise<BluetoothRemoteGATTCharacteristic>
    addEventListener(type: 'characteristicvaluechanged', listener: (event: Event) => void): void
    removeEventListener(type: 'characteristicvaluechanged', listener: (event: Event) => void): void
    readValue(): Promise<DataView>
    writeValue(value: BufferSource): Promise<void>
    writeValueWithoutResponse?(value: BufferSource): Promise<void>
    properties: {
      broadcast?: boolean
      read?: boolean
      writeWithoutResponse?: boolean
      write?: boolean
      notify?: boolean
      indicate?: boolean
      authenticatedSignedWrites?: boolean
      extendedProperties?: boolean
    }
  }

  interface RequestDeviceOptions {
    filters?: Array<{
      services?: (string | number)[]
      name?: string
      namePrefix?: string
    }>
    optionalServices?: (string | number)[]
    acceptAllDevices?: boolean
  }
}

export class BluetoothService {
  private device: BluetoothDevice | null = null
  private server: BluetoothRemoteGATTServer | null = null
  private service: BluetoothRemoteGATTService | null = null
  private characteristic: BluetoothRemoteGATTCharacteristic | null = null
  private status: ConnectionStatus = 'disconnected'
  private serviceUUID: string
  private characteristicUUID?: string
  private onDataCallback?: (data: ImuData) => void
  private onStatusChangeCallback?: (status: ConnectionStatus) => void
  private onErrorCallback?: (error: Error) => void
  private onDisconnectCallback?: () => void
  private autoReconnect: boolean
  private maxReconnectAttempts: number
  private connectRetries: number
  private connectTimeoutMs: number
  private connectRetryDelay: number
  private enableConnectRetry: boolean
  private reconnectAttempts: number = 0
  private reconnectTimer: number | null = null
  private manuallyDisconnected: boolean = false
  private boundHandleDisconnected: (event: Event) => void
  private boundHandleValueChanged: (event: Event) => void

  private dataBuffer: ImuData[] = []
  private maxBufferSize: number = 100
  private lastDataTime: number = 0
  private dataRate: number = 0

  constructor(options: BluetoothServiceOptions = {}) {
    this.serviceUUID = options.serviceUUID || DEFAULT_SERVICE_UUID
    this.characteristicUUID = options.characteristicUUID
    this.onDataCallback = options.onData
    this.onStatusChangeCallback = options.onStatusChange
    this.onErrorCallback = options.onError
    this.onDisconnectCallback = options.onDisconnect
    this.autoReconnect = options.autoReconnect ?? true
    this.maxReconnectAttempts = options.maxReconnectAttempts ?? DEFAULT_MAX_RECONNECT_ATTEMPTS
    this.connectRetries = options.connectRetries ?? DEFAULT_CONNECT_RETRIES
    this.connectTimeoutMs = options.connectTimeoutMs ?? DEFAULT_CONNECT_TIMEOUT_MS
    this.connectRetryDelay = options.connectRetryDelay ?? DEFAULT_CONNECT_RETRY_DELAY
    this.enableConnectRetry = options.enableConnectRetry ?? true
    this.boundHandleDisconnected = this.handleDisconnected.bind(this)
    this.boundHandleValueChanged = this.handleValueChanged.bind(this)
  }

  isSupported(): boolean {
    return typeof navigator !== 'undefined' && 'bluetooth' in navigator
  }

  async checkAvailability(): Promise<boolean> {
    if (!this.isSupported()) return false
    try {
      return await navigator.bluetooth!.getAvailability()
    } catch {
      return true
    }
  }

  getStatus(): ConnectionStatus {
    return this.status
  }

  getDeviceName(): string | undefined {
    return this.device?.name
  }

  getDeviceId(): string | undefined {
    return this.device?.id
  }

  getDataRate(): number {
    return this.dataRate
  }

  getRecentData(count: number = 10): ImuData[] {
    return this.dataBuffer.slice(-count)
  }

  setOnData(callback: (data: ImuData) => void): void {
    this.onDataCallback = callback
  }

  setOnStatusChange(callback: (status: ConnectionStatus) => void): void {
    this.onStatusChangeCallback = callback
  }

  setOnError(callback: (error: Error) => void): void {
    this.onErrorCallback = callback
  }

  setOnDisconnect(callback: () => void): void {
    this.onDisconnectCallback = callback
  }

  setAutoReconnect(enabled: boolean): void {
    this.autoReconnect = enabled
  }

  private setStatus(status: ConnectionStatus): void {
    if (this.status !== status) {
      this.status = status
      this.onStatusChangeCallback?.(status)
    }
  }

  private emitError(error: Error): void {
    this.onErrorCallback?.(error)
  }

  private parseImuData(buffer: ArrayBuffer): ImuData {
    const view = new DataView(buffer)

    if (view.byteLength >= 12) {
      return {
        ax: view.getInt16(0, true),
        ay: view.getInt16(2, true),
        az: view.getInt16(4, true),
        gx: view.getInt16(6, true),
        gy: view.getInt16(8, true),
        gz: view.getInt16(10, true),
        timestamp: Date.now(),
      }
    }

    if (view.byteLength >= 6) {
      return {
        ax: view.getInt16(0, true),
        ay: view.getInt16(2, true),
        az: view.getInt16(4, true),
        gx: 0,
        gy: 0,
        gz: 0,
        timestamp: Date.now(),
      }
    }

    return {
      ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0,
      timestamp: Date.now(),
    }
  }

  private handleValueChanged(event: Event): void {
    const target = event.target as unknown as BluetoothRemoteGATTCharacteristic
    if (!target.value) return

    try {
      const data = this.parseImuData(target.value.buffer as ArrayBuffer)

      const now = Date.now()
      if (this.lastDataTime > 0) {
        const interval = now - this.lastDataTime
        if (interval > 0) {
          this.dataRate = Math.round(1000 / interval)
        }
      }
      this.lastDataTime = now

      this.dataBuffer.push(data)
      if (this.dataBuffer.length > this.maxBufferSize) {
        this.dataBuffer.shift()
      }

      this.onDataCallback?.(data)
    } catch (err) {
      this.emitError(new Error(`数据解析失败: ${err instanceof Error ? err.message : String(err)}`))
    }
  }

  private handleDisconnected(): void {
    const wasConnected = this.status === 'connected' || this.status === 'reconnecting'
    this.setStatus('disconnected')
    this.cleanup()

    if (wasConnected && !this.manuallyDisconnected && this.autoReconnect) {
      this.scheduleReconnect()
    }

    this.onDisconnectCallback?.()
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      this.setStatus('error')
      this.emitError(new Error(`重连失败，已尝试 ${this.maxReconnectAttempts} 次`))
      return
    }

    this.reconnectAttempts++
    this.setStatus('reconnecting')

    const delay = RECONNECT_DELAY_BASE * Math.pow(2, this.reconnectAttempts - 1)

    this.reconnectTimer = window.setTimeout(async () => {
      try {
        await this.reconnect()
      } catch {
        this.scheduleReconnect()
      }
    }, delay)
  }

  private async reconnect(): Promise<boolean> {
    if (!this.device) {
      throw new Error('没有已保存的设备信息')
    }

    try {
      this.setStatus('reconnecting')

      // 复用 establishGattConnection，享受重试与超时保护
      await this.establishGattConnection()

      this.reconnectAttempts = 0
      this.setStatus('connected')
      return true
    } catch (err) {
      this.cleanup()
      throw err
    }
  }

  private async findNotifyCharacteristic(): Promise<BluetoothRemoteGATTCharacteristic | null> {
    if (!this.service) return null

    if (this.characteristicUUID) {
      try {
        const char = await this.service.getCharacteristic(this.characteristicUUID)
        return char
      } catch {
        // fall through to search
      }
    }

    const characteristics = await this.service.getCharacteristics()

    for (const char of characteristics) {
      if (char.properties?.notify) {
        return char
      }
    }

    if (characteristics.length > 0) {
      return characteristics[0]
    }

    return null
  }

  private cleanup(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }

    if (this.characteristic) {
      try {
        this.characteristic.stopNotifications().catch(() => {})
        this.characteristic.removeEventListener('characteristicvaluechanged', this.boundHandleValueChanged)
      } catch (_) {
        // ignore
      }
      this.characteristic = null
    }
    this.service = null
    this.server = null

    if (this.device) {
      this.device.removeEventListener('gattserverdisconnected', this.boundHandleDisconnected)
    }

    this.dataRate = 0
    this.lastDataTime = 0
  }

  async connect(): Promise<boolean> {
    if (!this.isSupported()) {
      const error = new BluetoothNotAvailableError(
        '当前浏览器不支持 Web Bluetooth API，请使用 Chrome 或 Edge 浏览器'
      )
      this.emitError(error)
      this.setStatus('error')
      throw error
    }

    if (this.status === 'connecting' || this.status === 'reconnecting') {
      return false
    }

    if (this.status === 'connected' && this.server?.connected) {
      return true
    }

    this.manuallyDisconnected = false
    this.reconnectAttempts = 0

    try {
      this.setStatus('connecting')

      const device = await navigator.bluetooth!.requestDevice({
        filters: [
          { services: [this.serviceUUID] },
          { namePrefix: 'ESP32' },
          { namePrefix: 'FatBattle' },
          { namePrefix: 'IMU' },
        ],
        optionalServices: [this.serviceUUID],
      })

      this.device = device
      device.addEventListener('gattserverdisconnected', this.boundHandleDisconnected)

      // GATT 连接 + 服务发现 + 特征值订阅，带重试与超时
      await this.establishGattConnection()

      this.dataBuffer = []
      this.reconnectAttempts = 0
      this.setStatus('connected')
      return true
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))

      // 用户取消选择设备不视为错误
      if (error.message.includes('User cancelled') || error.message.includes('取消')) {
        this.setStatus('disconnected')
      } else {
        this.setStatus('error')
        this.emitError(error)
      }

      this.cleanup()
      this.device = null
      return false
    }
  }

  /**
   * 建立 GATT 连接并完成服务发现与特征值订阅。
   * - 内部使用 withRetry（线性退避，connectRetries 次）
   * - 单次尝试受 connectTimeoutMs 超时保护
   */
  private async establishGattConnection(): Promise<void> {
    if (!this.device?.gatt) {
      throw new BluetoothNotAvailableError('设备不支持 GATT 连接')
    }

    const connectFn = async (): Promise<void> => {
      // 每次重试前清理上一次残留状态
      this.service = null
      this.characteristic = null

      this.server = await this.device!.gatt!.connect()
      this.service = await this.server.getPrimaryService(this.serviceUUID)

      const notifyChar = await this.findNotifyCharacteristic()
      if (!notifyChar) {
        throw new Error('未找到可用的数据特征值，请检查设备固件')
      }

      this.characteristic = notifyChar

      try {
        await notifyChar.startNotifications()
        notifyChar.addEventListener('characteristicvaluechanged', this.boundHandleValueChanged)
      } catch (_) {
        // 降级：通知订阅失败时尝试读取一次
        try {
          const value = await notifyChar.readValue()
          if (value) {
            const data = this.parseImuData(value.buffer as ArrayBuffer)
            this.onDataCallback?.(data)
          }
        } catch (_) {
          // ignore
        }
      }
    }

    const retryOptions: RetryOptions = {
      retries: this.connectRetries,
      delay: this.connectRetryDelay,
      backoff: 'linear',
      factor: 1,
      timeout: this.connectTimeoutMs,
      shouldRetry: (err) => {
        // 超时与网络类错误可重试，参数/权限错误不重试
        if (err instanceof RetryTimeoutError) return true
        const msg = (err.message || '').toLowerCase()
        if (msg.includes('cancel') || msg.includes('取消')) return false
        if (msg.includes('not found') || msg.includes('未找到')) return true
        return true
      },
    }

    if (this.enableConnectRetry) {
      await withRetry(connectFn, retryOptions)
    } else {
      // 不启用重试时仍保留单次超时保护
      await withTimeout(connectFn, this.connectTimeoutMs, '蓝牙连接超时')
    }
  }

  async disconnect(): Promise<void> {
    this.manuallyDisconnected = true
    this.reconnectAttempts = 0

    try {
      if (this.server?.connected) {
        this.server.disconnect()
      }
    } catch (_) {
      // ignore
    }
    this.cleanup()
    this.device = null
    this.setStatus('disconnected')
  }

  async readData(): Promise<ImuData | null> {
    if (!this.characteristic || this.status !== 'connected') {
      return null
    }
    try {
      const value = await this.characteristic.readValue()
      return this.parseImuData(value.buffer as ArrayBuffer)
    } catch (err) {
      this.emitError(err instanceof Error ? err : new Error(String(err)))
      return null
    }
  }

  async writeData(data: Uint8Array): Promise<boolean> {
    if (!this.characteristic || this.status !== 'connected') {
      return false
    }
    try {
      const buffer = new Uint8Array(data).buffer as ArrayBuffer
      if (this.characteristic.writeValueWithoutResponse) {
        await this.characteristic.writeValueWithoutResponse(buffer)
      } else {
        await this.characteristic.writeValue(buffer)
      }
      return true
    } catch (err) {
      this.emitError(err instanceof Error ? err : new Error(String(err)))
      return false
    }
  }

  destroy(): void {
    this.disconnect().catch(() => {})
    this.onDataCallback = undefined
    this.onStatusChangeCallback = undefined
    this.onErrorCallback = undefined
    this.onDisconnectCallback = undefined
    this.dataBuffer = []
  }
}

export const createBluetoothService = (options?: BluetoothServiceOptions): BluetoothService => {
  return new BluetoothService(options)
}
