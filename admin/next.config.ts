import type { NextConfig } from 'next'

const config: NextConfig = {
  // 管理画面はキャッシュせず常に最新の DB 内容を出す。
  experimental: {},
}

export default config
