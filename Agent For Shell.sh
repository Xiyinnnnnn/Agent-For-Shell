#---
#name: Agent For Shell
#author: Xiyinnnnnn
#brand: 通用
#description: Agent For Shell
#param: API_KEY|DeepSeek API Key|
#param: QUESTION|本次问题|你好
#param: MODEL|模型名|deepseek-v4-flash
#---

API_URL="https://api.deepseek.com/chat/completions"
MODEL_DEFAULT="deepseek-v4-flash"
MAX_TOK=900000
AUTH_TIMEOUT=60
REASONING_EFFORT="max"
MAX_BATCH_TOOLS=8
MAX_BATCH_OUT=128000

QUESTION="{{QUESTION}}"
case "$QUESTION" in
  "{{"*) QUESTION="你好" ;;
esac
API_KEY="{{API_KEY}}"
MODEL="{{MODEL}}"
case "$MODEL" in
  ""|"{{"*) MODEL="$MODEL_DEFAULT" ;;
esac

CURL=$(command -v curl 2>/dev/null || echo /data/data/com.termux/files/usr/bin/curl)

BL="rm
dd
su
pm uninstall
pm clear
chmod -R 777
:(){"

esc() {
  print -r -- "$1" | tr '\n\t\r' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}
escj() {
  print -r -- "$1" | tr '\t\r' '  ' | awk '{ gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); out = out $0 "\\n" } END { printf "%s", out }'
}
dec() {
  print -r -- "$1" | sed 's/\\"/"/g' | awk '{ gsub(/\\\\/, "\001"); gsub(/\\n/, "\n"); gsub(/\\t/, "\t"); gsub(/\\r/, "\r"); gsub(/\001/, "\\"); print }'
}
json_val() {
  print -r -- "$1" | LC_ALL=C awk -v k="\"$2\":" '
  {
    kl = length(k)
    p = 0
    i = 1
    found = 0
    while (found == 0) {
      if (substr($0, i, kl) == k) { p = i; found = 1 }
      else if (substr($0, i, 1) == "") { found = 2 }
      else { i = i + 1 }
    }
    if (p > 0) {
      t = substr($0, p + kl)
      sub(/^[ ]*/, "", t)
      if (substr(t, 1, 1) == "\"") {
        s = substr(t, 2)
        i = 1
        f = 0
        while (f == 0) {
          c = substr(s, i, 1)
          if (c == "") { f = 2 }
          else if (c == "\\") { i = i + 2 }
          else if (c == "\"") { f = 1 }
          else { i = i + 1 }
        }
        if (f == 1) { print substr(s, 1, i - 1) }
      }
    }
  }'
}

json_arr_blocks() {
  print -r -- "$1" | LC_ALL=C awk -v k="\"$2\":" '
  {
    kl = length(k)
    p = 0
    i = 1
    found = 0
    while (found == 0) {
      if (substr($0, i, kl) == k) { p = i; found = 1 }
      else if (substr($0, i, 1) == "") { found = 2 }
      else { i = i + 1 }
    }
    if (p > 0) {
      t = substr($0, p + kl)
      sub(/^[ ]*/, "", t)
      if (substr(t, 1, 1) == "[") {
        i = 1
        depth = 0
        instr = 0
        blk = ""
        done = 0
        while (done == 0) {
          c = substr(t, i, 1)
          if (c == "") { done = 1 }
          else if (instr == 1) {
            if (c == "\\") {
              blk = blk substr(t, i, 2)
              i = i + 2
            } else {
              if (c == "\"") { instr = 0 }
              blk = blk c
              i = i + 1
            }
          } else {
            if (c == "\"") { instr = 1; blk = blk c; i = i + 1 }
            else if (c == "{") {
              depth = depth + 1
              if (depth == 1) { blk = "{" } else { blk = blk c }
              i = i + 1
            }
            else if (c == "}" && depth > 0) {
              depth = depth - 1
              blk = blk "}"
              i = i + 1
              if (depth == 0) { print blk; blk = "" }
            }
            else if (c == "]" && depth == 0) { done = 1 }
            else { blk = blk c; i = i + 1 }
          }
        }
      }
    }
  }'
}

wait_vol() {
  i=0
  while [ "$i" -lt "$AUTH_TIMEOUT" ]; do
    ev=$(timeout 1 getevent -lc 1 2>/dev/null)
    case "$ev" in
      *KEY_VOLUMEUP*)   return 0 ;;
      *KEY_VOLUMEDOWN*) return 1 ;;
    esac
    i=$((i + 1))
  done
  return 2
}

exec_captured() {
  O_TMP=/data/local/tmp/agent_out_$$.txt
  E_TMP=/data/local/tmp/agent_err_$$.txt
  eval "$1" > "$O_TMP" 2> "$E_TMP"
  head -c 12000 "$O_TMP"
  if [ -s "$E_TMP" ]; then
    echo
    echo "[stderr]"
    head -c 4000 "$E_TMP"
  fi
  rm -f "$O_TMP" "$E_TMP"
  return 0
}

run_cmd() {
  c=$(print -r -- "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$c" ] && { echo "[安全] 空命令"; return 1; }
  OLDIFS=$IFS
  IFS='
'
  for b in $BL; do
    IFS=$OLDIFS
    case " $c " in *" $b "*|"$b "*|"$b."*|"$b:"*|"$b")
      echo "──────────────────────────────────" >&2
      echo "⚠ 危险命令，需要物理按键授权：" >&2
      echo "   命令: $c" >&2
      echo "   [音量上] 同意执行  |  [音量下] 拒绝" >&2
      echo "   ${AUTH_TIMEOUT}秒无操作自动拒绝" >&2
      echo "──────────────────────────────────" >&2
      wait_vol
      case $? in
        0) exec_captured "$c"; return 0 ;;
        1) echo "[已拒绝] 用户按了音量下" >&2; return 1 ;;
        2) echo "[超时拒绝] 未收到按键" >&2; return 1 ;;
      esac
      ;;
    esac
  done
  IFS=$OLDIFS
  exec_captured "$c"
}
run_ui() {
  T=/data/local/tmp/agent_ui_$$.txt
  run_cmd "$1" | tee "$T"
  rm -f "$T"
}


extract_tool_calls() {
  FLAT=$(print -r -- "$1" | tr '\n' ' ')
  ALL=$(print -r -- "$FLAT" | grep -o '\[CMD\][^[]*\[/CMD\]' | sed 's/^\[CMD\]//; s/\[\/CMD\]$//' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
  if [ -n "$ALL" ]; then
    print -r -- "$ALL"
    return 0
  fi
  C=$(print -r -- "$FLAT" | sed -n 's/.*<parameter[^>]*name="command"[^>]*>\([^<]*\)<\/parameter>.*/\1/p' | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$C" ] && { print -r -- "$C"; return 0; }
  B=$(print -r -- "$FLAT" | grep -o -E '(run_terminal|terminal|shell|bash|exec|cmd|run|终端|执行|运行|命令)[[:space:]]*\([^)]*\)' | head -n 1)
  if [ -n "$B" ]; then
    B2=$(print -r -- "$B" | sed 's/^[^()]*([[:space:]]*//; s/)[[:space:]]*$//')
    C=$(print -r -- "$B2" | sed -n 's/.*command[[:space:]]*[:=][[:space:]]*\(["'"'"'][^"'"'"']*["'"'"']\).*/\1/p' | head -n 1 | sed 's/^["'"'"']//; s/["'"'"']$//')
    [ -z "$C" ] && C=$(print -r -- "$B2" | sed -n 's/\(["'"'"'][^"'"'"']*["'"'"']\).*/\1/p' | head -n 1 | sed 's/^["'"'"']//; s/["'"'"']$//')
    [ -n "$C" ] && { print -r -- "$C"; return 0; }
  fi
  C=$(print -r -- "$FLAT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')
  [ -n "$C" ] && { print -r -- "$C"; return 0; }
  C=$(print -r -- "$FLAT" | grep -o -E '(run_terminal|terminal|shell|bash|exec|cmd|run|终端|执行|运行|命令)[[:space:]]*[:：][[:space:]]*[^"'"'"'`<（），。；;、]+' | head -n 1 | sed 's/^[^:：]*[:：][[:space:]]*//')
  [ -n "$C" ] && { print -r -- "$C"; return 0; }
  return 1
}

ask_llm() {
  while :; do
  RESP=$(print -r -- "$1" | "$CURL" -sS --max-time 300 "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d @- 2>/dev/null)
    [ -n "$RESP" ] && break
  done
  ACCUM=""; TC_ARGS=""; TC_ID=""; TOTAL_USAGE=0; REASON=""; TC_RAW=""
  TC_RAW="$RESP"
  C=$(json_val "$RESP" content)
  [ -n "$C" ] && C=$(dec "$C")
  TCA=$(json_val "$RESP" arguments)
  TCID=$(print -r -- "$RESP" | sed -n 's/.*"tool_calls":[[:space:]]*\[[[:space:]]*{"id":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  U=$(json_val "$RESP" total_tokens)
  R=$(json_val "$RESP" reasoning_content)
  [ -n "$R" ] && R=$(dec "$R")
  [ -n "$C" ] && ACCUM="$C"
  [ -n "$TCA" ] && TC_ARGS="$TCA"
  [ -n "$TCID" ] && TC_ID="$TCID"
  [ -n "$U" ] && [ "$U" -gt 0 ] 2>/dev/null && TOTAL_USAGE=$U
  [ -n "$R" ] && REASON="$R"
  if [ -n "$ACCUM" ]; then
    echo "[正文]:"
    echo "$ACCUM"
  fi
  if [ -n "$REASON" ]; then
    echo "[思维链]:"
    echo "$REASON"
  fi
  [ -z "$ACCUM" ] && ACCUM="(无输出)"
}

compress_summary() {
  BODY="{\"model\":\"$MODEL\",\"messages\":[$MSGS,{\"role\":\"user\",\"content\":\"[总结所有]\"}],\"stream\":false}"
  RESP=$(print -r -- "$BODY" | "$CURL" -s --max-time 300 "$API_URL" \
    -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d @-)
  NEW=$(json_val "$RESP" content)
  [ -n "$NEW" ] && NEW=$(dec "$NEW")
  [ -z "$NEW" ] && NEW=$(json_val "$RESP" message)
  [ -z "$NEW" ] && NEW="解析失败"
  SUMMARY="[历史背景] $NEW"
  MSGS="{\"role\":\"system\",\"content\":\"$(esc "$SYS")\"},{\"role\":\"user\",\"content\":\"$(esc "$SUMMARY")\"},{\"role\":\"user\",\"content\":\"$(esc "$QUESTION")\"}"
}

SYS='[ROLE] Agent For Shell | [LANG] zh-CN
[MUST] 工具先于语言：思考→run_terminal→执行→验证
[MUST] 产出写文件；简单问答直接回复
[MUST] 查优于猜：记忆→命令探查→推理，不跳过
[MUST_NOT] 草稿当交付；未完成→继续调工具
[MUST] 代码/命令/列表用```包裹，不准裸文本
[MUST] 算优于估：dumpsys/getprop/ls/cat实测，不目测

[SYS] 环境=adb shell 权限，可执行 dumpsys/settings/getprop/pm/am/input 等系统命令
[SAFETY] 禁止危险操作(删除/覆盖/格式化/卸载/重启/提权)：
  必须时→明确告知命令+影响→请求授权→同意后 dangerous=true 执行

[BOOT] 新对话开始，不跳过：
  ① run_terminal: ls /data/local/tmp/agent_mem/*.md → 按文件名摘要选相关记忆→cat 精读复用 | 无→标"无历史"
  ② 明确任务目标与执行计划
  ③ 进入 [THINK]

[MEMORY_LOOP] 前查后存，漏→不交付（记忆目录读写权在 agent，程序层零落盘不干预）：
  前·· 需要历史→run_terminal: ls /data/local/tmp/agent_mem/*.md → 按文件名摘要识别相关记忆 → cat 精读 → 命中复用 | 无→标"无历史"
  后·· 有价值结论→run_terminal: 写记忆文件 /data/local/tmp/agent_mem/摘要名.md

[THINK] 推理协议 P1-P5全执行（<think>内，绝不进<answer>）：
  P1 拆解：核心需求+隐含需求 → 明确目标
  P2 回记忆：run_terminal: ls 记忆目录/*.md 按文件名摘要选相关 → cat 精读 → 命中复用+标源 | 无→命令探查→不编造
  P3 规划：步骤表(步骤→命令→预期→验证)
  P4 执行：逐步 run_terminal，失败→读报错→修正重试
  P5 存忆：完成→run_terminal: 写 记忆目录/摘要名.md

<EXAMPLE>
用户: {需求}
<think>
P1 拆解: {目标}
P2 回记忆: ls 记忆目录/*.md 按文件名摘要选相关 → {命中|无历史}
P3 规划: {步骤→命令→验证}
P4 执行: run_terminal {命令} → {结果}
P5 存忆: 写 记忆目录/摘要名.md
</think>
<answer>{结果总结}</answer>
</EXAMPLE>

[SUMMARY] 收到"[总结所有]"→ 不调工具，总结全部历史，输出纯摘要正文

[DELIVER] 核对：□记忆已回 □任务完成 □输出已验证 □问题已回答
<RULES> P1-P5不进answer；记忆必查必存；危险先授权；
  参数写死在脚本顶部，要改→告诉用户修改'


TOOLS='[{"type":"function","function":{"name":"run_terminal","description":"在终端执行 shell 命令并返回输出。唯一工具，别名 terminal/shell/exec/cmd/终端/执行，一切系统操作都通过它完成","parameters":{"type":"object","properties":{"command":{"type":"string","description":"要执行的命令"},"explain":{"type":"string","description":"为什么执行这条命令"},"dangerous":{"type":"boolean","description":"是否涉及删除/覆盖/安装/系统级修改，是则true"}},"required":["command","explain","dangerous"]}}}]'

MSGS="{\"role\":\"system\",\"content\":\"$(esc "$SYS")\"}"
MSGS="$MSGS,{\"role\":\"user\",\"content\":\"$(esc "$QUESTION")\"}"

echo "====Agent For Shell====="
echo "问题 : $QUESTION"

LAST_CAUGHT=""
REPEAT=0
while :; do
  BODY="{\"model\":\"$MODEL\",\"messages\":[$MSGS],\"tools\":$TOOLS,\"tool_choice\":\"auto\",\"reasoning_effort\":\"$REASONING_EFFORT\",\"thinking\":{\"type\":\"enabled\"}}"
  ask_llm "$BODY"
  if [ "$TOTAL_USAGE" -gt "$MAX_TOK" ] 2>/dev/null; then
    compress_summary
  fi


  if [ -n "$TC_RAW" ]; then
    TCB_TMP=/data/local/tmp/agent_tc_$$.txt
    json_arr_blocks "$TC_RAW" tool_calls > "$TCB_TMP"
    if [ -s "$TCB_TMP" ]; then
      TCS_JSON=""; TC_COUNT=0
      while IFS= read -r TC_B; do
        [ "$TC_COUNT" -ge "$MAX_BATCH_TOOLS" ] && break
        TC_BID=$(json_val "$TC_B" id)
        TC_BNAME=$(json_val "$TC_B" name)
        TC_BARGS=$(json_val "$TC_B" arguments)
        [ -n "$TC_BARGS" ] && TC_BARGS=$(dec "$TC_BARGS")
        [ -z "$TC_BNAME" ] && TC_BNAME="run_terminal"
        if [ -n "$TC_BARGS" ]; then ARGS_JSON="\"$(esc "$TC_BARGS")\""; else ARGS_JSON='""'; fi
        TCS_JSON="$TCS_JSON,{\"id\":\"$TC_BID\",\"type\":\"function\",\"function\":{\"name\":\"$TC_BNAME\",\"arguments\":$ARGS_JSON}}"
        TC_COUNT=$((TC_COUNT + 1))
      done < "$TCB_TMP"
      if [ "$TC_COUNT" -gt 0 ]; then
        TCS_JSON=$(print -r -- "$TCS_JSON" | sed 's/^,//')
        if [ -n "$ACCUM" ]; then CONTENT_JSON="\"$(esc "$ACCUM")\""; else CONTENT_JSON="null"; fi
        if [ -n "$REASON" ]; then REASON_JSON="\"$(escj "$REASON")\""; else REASON_JSON="null"; fi
        MSGS="$MSGS,{\"role\":\"assistant\",\"content\":$CONTENT_JSON,\"reasoning_content\":$REASON_JSON,\"tool_calls\":[$TCS_JSON]}"
        TC_EXEC=0; TOTAL_OUT=0; SKIP=0
        while IFS= read -r TC_B; do
          TC_EXEC=$((TC_EXEC + 1))
          [ "$TC_EXEC" -gt "$MAX_BATCH_TOOLS" ] && break
          TC_BID=$(json_val "$TC_B" id)
          [ -z "$TC_BID" ] && TC_BID="call_$((TC_EXEC - 1))"
          TC_BARGS_RAW=$(json_val "$TC_B" arguments)
          TC_BARGS=$(dec "$TC_BARGS_RAW")
          CMD=$(json_val "$TC_BARGS" command)
          [ -n "$CMD" ] && CMD=$(dec "$CMD")
          if [ -z "$CMD" ] && [ -n "$TC_BARGS" ]; then
            CMD=$(print -r -- "$TC_BARGS" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')
            [ -n "$CMD" ] && CMD=$(dec "$CMD")
          fi
          if [ -z "$CMD" ] && [ -n "$TC_BARGS" ]; then
            INNER=$(json_val "$TC_BARGS" arguments)
            [ -n "$INNER" ] && INNER=$(dec "$INNER")
            [ -n "$INNER" ] && CMD=$(json_val "$INNER" command)
            [ -n "$CMD" ] && CMD=$(dec "$CMD")
          fi
          if [ -n "$CMD" ]; then
            if [ "$SKIP" -eq 1 ]; then
              MSGS="$MSGS,{\"role\":\"tool\",\"tool_call_id\":\"$TC_BID\",\"content\":\"(输出预算超限,本命令未执行)\"}"
              continue
            fi
            echo "[工具] $CMD"
            OUT=$(run_ui "$CMD")
            echo "$OUT"
            TOTAL_OUT=$((TOTAL_OUT + ${#OUT}))
            MSGS="$MSGS,{\"role\":\"tool\",\"tool_call_id\":\"$TC_BID\",\"content\":\"$(esc "$OUT")\"}"
            if [ "$TOTAL_OUT" -gt "$MAX_BATCH_OUT" ]; then
              echo "[批量] 输出预算超限(${TOTAL_OUT}>${MAX_BATCH_OUT}),剩余命令跳过"
              SKIP=1
            fi
          else
            MSGS="$MSGS,{\"role\":\"tool\",\"tool_call_id\":\"$TC_BID\",\"content\":\"(工具调用解析失败)\"}"
          fi
          done < "$TCB_TMP"
        rm -f "$TCB_TMP"
        continue
      fi
    fi
    rm -f "$TCB_TMP"
  fi

  CMD2=$(extract_tool_calls "$ACCUM")
  if [ -n "$CMD2" ]; then
    CMDS_TMP=/data/local/tmp/agent_cmds_$$.txt
    print -r -- "$CMD2" > "$CMDS_TMP"
    FIRST=""
    while IFS= read -r CC; do
      CC=$(print -r -- "$CC" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -n "$CC" ] && [ -z "$FIRST" ] && FIRST="$CC"
    done < "$CMDS_TMP"
    if [ -n "$FIRST" ]; then
      if [ "$FIRST" = "$LAST_CAUGHT" ]; then
        REPEAT=$((REPEAT + 1))
        if [ "$REPEAT" -ge 3 ]; then
          break
        fi
      else
        LAST_CAUGHT="$FIRST"
        REPEAT=1
      fi
    fi
    if [ -n "$REASON" ]; then REASON_JSON="\"$(escj "$REASON")\""; else REASON_JSON="null"; fi
    MSGS="$MSGS,{\"role\":\"assistant\",\"content\":\"$(esc "$ACCUM")\",\"reasoning_content\":$REASON_JSON}"
    OUT_ALL=""; TOTAL_OUT=0; EXEC_TMP=/data/local/tmp/agent_exec_$$.txt; : > "$EXEC_TMP"
    while IFS= read -r CC; do
      CC=$(print -r -- "$CC" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -z "$CC" ] && continue
      if grep -Fxq "$CC" "$EXEC_TMP" 2>/dev/null; then
        echo "[批量] 跳过重复命令: $CC"
        continue
      fi
      if [ "$TOTAL_OUT" -gt "$MAX_BATCH_OUT" ]; then
        echo "[批量] 输出预算超限,跳过: $CC"
        continue
      fi
      echo "[工具] $CC"
      OUT=$(run_ui "$CC")
      echo "$OUT"
      print -r -- "$CC" >> "$EXEC_TMP"
      TOTAL_OUT=$((TOTAL_OUT + ${#OUT}))
      OUT_ALL="$OUT_ALL |cmd| $CC => $OUT"
    done < "$CMDS_TMP"
    rm -f "$CMDS_TMP" "$EXEC_TMP"
    if [ -n "$OUT_ALL" ]; then
      MSGS="$MSGS,{\"role\":\"user\",\"content\":\"[工具结果] $(esc "$OUT_ALL")\"}"
    else
      MSGS="$MSGS,{\"role\":\"user\",\"content\":\"(未执行任何命令)\"}"
    fi
    continue
  fi
  echo "[结束] 无工具调用,会话结束"
  break
done
