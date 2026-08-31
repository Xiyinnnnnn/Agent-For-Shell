# Agent-For-Shell

## 是什么
POSIX sh 单文件终端 Agent（678 行），跑在 Android adb shell（幻·实验室 / toybox 0.8.12 / mksh）。`MSGS` 字符串累计全部消息，无持久化（每次运行=新对话）。

## 运行方式
- 幻·实验室以"脚本文本"方式运行，`#---` 必须第一行
- `#param` 注入：`API_KEY` / `QUESTION` / `MODEL`（传给 shell 前字符串替换）
- 环境：mksh，无 busybox/python3/jq，仅 toybox 命令集（base64/awk/sed/curl/getevent...）

## 全局常量
| 常量 | 值 | 用途 |
|---|---|---|
| API_URL | 火山方舟 v4 chat/completions | LLM 端点 |
| SUMTOK | 524288 | TOTAL_USAGE 超此值→触发压缩 |
| MAXTOK | 32768 | 输出上限；压缩用 `MAXTOK/4` |
| MAX_BATCH_TOOLS | 8 | 单轮最大工具数 |
| MAX_BATCH_OUT | 128000 | 工具输出预算上限 |
| AUTH_TIMEOUT | 30 | 危险命令授权超时(秒) |
| REASONING_EFFORT | max | 推理强度 |
| STREAM_MODE | true | 流式开关 |
| SEP | `\037` | 聚合行字段分隔符 |

## 消息累计：MSGS
单 JSON 字符串，`system` 开头，逐条 append。
```
初始化:  MSGS = system + user(QUESTION)
累计:    MSGS += assistant(含tool_calls) + tool(结果) + ...
压缩后:  MSGS = system + SUMMARIES(快照链) + user(QUESTION)   # 重建对话起点
```

## 核心循环
```
MSGS = system + QUESTION
loop:
  BODY = [MSGS] + tools
  ask_llm BODY                     # 流式解析，产出 ACCUM/REASON/TCB
  if TOTAL_USAGE > SUMTOK: compress_summary   # 快照 append
  if TCB(工具调用):
    for 每条 tool_call:
      解析 id/name/arguments(command)
      run_cmd 命令（黑名单→音量键授权→执行）
      MSGS += assistant(tool_calls) + tool(结果)
    再次 ask_llm（携带工具结果）
  else: 输出正文，结束本轮
```

## 流式协议（awk → shell）
SSE `data:` 行 → awk 解析 → 输出行协议 → shell `read` 循环实时处理。
```
awk 输出:
  Pc<正文> / Pr<推理>   实时行（换行用 \001 编码）
  S<RR>\037<CC>         聚合行（500 块清空，规避 toybox awk 拼接 O(n²)）
  A<args>\037I<id>\037N<name>\037U<usage>\037X<index>  工具/用量透传
  DONE                  结束

shell 处理:
  Pc/Pr → 替换 \001→换行 → 实时 printf
  S     → set -- 按 SEP 分词 → 追加 ACCUM/REASON
  A     → 按 index 聚合 TC_IDS/TC_NAMES/TC_ARGS（同 index 拼 arguments）
  DONE  → break
收尾: ACCUM 一次 dec 还原；TCB 组装 tool_calls JSON
```

## 快照链压缩（append-only）
```
SUMMARIES=""                     # 初始空
compress_summary:
  BODY = [MSGS, {user:"[总结所有]"}]     # MSGS 已含完整前缀，不动
  成功:
    SUMMARY = "[历史背景] $NEW"
    SUMMARIES = "${SUMMARIES:+$SUMMARIES,}{user:SUMMARY}"   # 追加快照
    MSGS = system + SUMMARIES + user(QUESTION)              # 重建
```
旧快照永不变更/不移除；压缩请求复用完整前缀 → 最大化 KV 命中。

## 函数地图
| 函数 | 职责 |
|---|---|
| ask_llm | 流式/非流式请求 + awk 解析 + 行协议 + 工具聚合 |
| compress_summary | 压缩历史 → 快照 append + MSGS 重建 |
| esc / escj | JSON 字符串值转义（escj=纯 awk 逐字符版，规避 toybox 坑） |
| dec | JSON 转义还原（`\"`→`"`、`\n`→换行、`\\`→`\`） |
| get_cmd | 嵌套 JSON 结构感知提取 command（处理内容引号） |
| json_val | JSON 字段取值（容忍空格） |
| json_arr_blocks | 按工具块切分 tool_calls |
| run_cmd / exec_captured | 黑名单匹配 + 音量键授权 + 捕获执行 |
| wait_vol | getevent 音量键等待（上=同意/下=拒绝） |
| img_build | 图片：本地 base64（`-w0`）/ http(s) URL 直连 |

## 工具执行与安全
```
run_cmd:
  命令规整（拆 ;&| 、pm 子命令归一、去路径）
  case 匹配黑名单 $BL → 音量键授权：
    上=同意执行 / 下=拒绝 / 超时 AUTH_TIMEOUT 自动拒绝
  正常 → exec_captured 执行（输出截断到 MAX_BATCH_OUT）
```

## 环境坑（toybox / mksh）
- `print -r --` 是 mksh/zsh 内建（本机 bash 测试需 `print` 桩）
- `"$CURL"` 是**变量**（curl 路径探测），不是函数
- toybox awk 字符串拼接 `R=R r` 是 O(n²)（9.66s 实测）→ 分块 500 清空
- toybox awk 不支持 `'\"'` 转义 → escj 纯 awk 逐字符
- `base64 -w0`（mksh 处理数 MB 字符串无压力）
- 管道子 shell 不共享变量（测试桩计数需写文件）

## 改哪 / 怎么验
- 改压缩 → `compress_summary` + `SUMMARIES` 初始化（L435/553 附近）
- 改流式 → `ask_llm` awk 段 + shell `case`
- 改工具/安全 → `run_cmd` + `$BL` 黑名单 + `wait_vol`
- 验：`bash -n`；awk 提取函数体 + 桩测试（`print` 桩 / `CURL` 变量指向桩函数 / 计数写文件）
