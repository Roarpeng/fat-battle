// 管理后台单页（Go embed：无构建工具、无外部 CDN 依赖）
package adminui

import _ "embed"

//go:embed index.html
var IndexHTML []byte
