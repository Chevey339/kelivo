---
name: ai-api-manager
description: AI API & 模型管理助手 — 配置/切换/排障 LLM 供应商
version: 1.0.0
author: Jaye
trigger: [api, 模型, openai, 硅基流动, deepseek, gemini, claude, token, key, 供应商, 中转, base url, 免费模型, api key]
priority: 85
---

# AI API & 模型管理助手

---

## 一、常用 API 供应商速查

### 官方渠道
| 平台 | 免费额度 | 兼容格式 |
|:---|:---:|:---:|
| **OpenAI** | $5 新用户 | 原生 |
| **Google Gemini** | 60次/天 | OpenAI 兼容 |
| **DeepSeek** | ¥10 新用户 | OpenAI 兼容 |
| **Moonshot (Kimi)** | ¥15 新用户 | OpenAI 兼容 |

### 中转聚合平台
| 平台 | Base URL |
|:---|:---|
| **硅基流动** | `https://api.siliconflow.cn/v1` |
| **OpenRouter** | `https://openrouter.ai/api/v1` |
| **AIHubMix** | `https://api.aihubmix.com/v1` |
| **API易** | `https://api.apiyi.com/v1` |

### 通用配置
```json
{
  "apiKey": "sk-xxxxxxxx",
  "baseURL": "https://api.siliconflow.cn/v1",
  "models": ["deepseek-chat-v3", "Qwen/Qwen2.5-7B-Instruct"]
}
```

---

## 二、供应商排障

| 错误 | 原因 | 解决 |
|:---|:---|:---|
| `401` | Key 错误/过期 | 重新生成 Key |
| `404` | Base URL 路径错 | 检查是否以 `/v1` 结尾 |
| `429` | 频率限制/额度耗尽 | 降频或充值 |
| `500` | 服务端故障 | 等待重试 |
| 流式中断 | 网络波动 | 检查网络 |

### 配置检查清单
```
□ API Key 无多余空格
□ Base URL 完整（/v1 结尾）
□ 模型名与服务商一致
□ 账户余额充足
□ 网络可正常访问
```

### curl 测试
```bash
curl https://api.xxx.com/v1/chat/completions \
  -H "Authorization: Bearer sk-xxx" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hi"}]}'
```

---

## 三、模型选择建议

| 场景 | 推荐模型 |
|:---|:---|
| 日常对话 | GPT-4o-mini / DeepSeek V3 |
| 代码生成 | Claude Sonnet / GPT-4o |
| 长文本 | Gemini Pro / Kimi |
| 中文写作 | DeepSeek / Qwen |
| 本地部署 | DeepSeek-R1 / Qwen2.5 |

---

## 四、RikkaHub / Kelivo 配置

### RikkaHub 添加供应商
```
设置 → 供应商 → + 添加
→ 类型: OpenAI Compatible
→ 名称: 如「硅基流动」
→ Base URL: https://api.siliconflow.cn/v1
→ API Key: sk-xxxxx
→ 获取模型列表 → 选择 → 保存
```

### Kelivo 世界书提醒
> ⚠️ Kelivo 只认 `type: "lorebook"` 格式
> RikkaHub 格式导入 Kelivo 会是空的
> `keywords` 数组不能为空，否则永远不触发

---

## 五、Token 成本参考

| 模型 | 输入 ($/1M tokens) | 输出 ($/1M tokens) |
| GPT-4o | $2.50 | $10.00 |
| GPT-4o-mini | $0.15 | $0.60 |
| Claude Sonnet 4 | $3.00 | $15.00 |
| DeepSeek V3 | $0.27 | $1.10 |
| Gemini 2.0 Flash | $0.10 | $0.40 |

### 省钱技巧
1. 简单任务用 mini 型号
2. 控制上下文长度，及时清理历史
3. 用世界书代替系统提示词中的固定知识
4. 流式响应可提前终止不想要的回复