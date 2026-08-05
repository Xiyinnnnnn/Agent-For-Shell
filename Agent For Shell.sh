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

QUESTION="{{QUESTION}}"
case "$QUESTION" in
  "{{"*) QUESTION="你好" ;;
esac
API_KEY="{{API_KEY}}"
case "$API_KEY" in
  "") echo "[!] API Key 为空"; exit 1 ;;
  "{{"*) echo "[!] 请在弹出的参数框中填入 API Key"; exit 1 ;;
esac
MODEL="{{MODEL}}"
case "$MODEL" in
  ""|"{{"*) MODEL="$MODEL_DEFAULT" ;;
esac

CURL=$(command -v curl 2>/dev/null || echo /data/data/com.termux/files/usr/bin/curl)

BL="rm:mv:dd:mkfs:format:wipe:reboot:shutdown:su:mount:chmod:chown:killall:pm uninstall:pm clear:settings put:setprop"

esc() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g' | sed 's/\t/\\t/g; s/\r/\\r/g'
}
escj() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g;s/\t/\\t/g;s/\r/\\r/g'
}
json_val() {
  printf '%s' "$1" | awk -v k="\"$2\":" '
    function dec(s,   r,i,c){
      r=""; i=1
      while(i<=length(s)){
        c=substr(s,i,1)
        if(c=="\\"){
          c=substr(s,i+1,1)
          if(c=="\""){r=r"\""; i+=2}
          else if(c=="\\"){r=r"\\"; i+=2}
          else if(c=="n"){r=r"\n"; i+=2}
          else if(c=="t"){r=r"\t"; i+=2}
          else if(c=="/"){r=r"/"; i+=2}
          else if(c=="r"){r=r"\r"; i+=2}
          else {r=r c; i+=2}
        } else {r=r c; i++}
      }
      return r
    }
    {p=index($0,k);
     if(p>0){
       t=substr($0,p+length(k));
       sub(/^[ \t]*/,"",t);
       if(substr(t,1,1)=="\""){
         t=substr(t,2);
         if(t=="" || substr(t,1,1)=="," || substr(t,1,1)=="}" || substr(t,1,1)=="]"){
           print ""; next
         }
         n=length(t); i=1; f=0;
         while(i<=n && f==0){
           if(substr(t,i,1)=="\""){
             b=0; j=i-1;
             while(j>=1 && substr(t,j,1)=="\\"){b++; j--}
             if(b%2==0){f=1} else {i++}
           } else {i++}
         }
         if(f==1){v=substr(t,1,i-1); print dec(v)}
         else {print ""}
       } else {
         v=t; sub(/^[ \t]*/,"",v);
         sub(/[^0-9A-Za-z.+-].*$/,"",v);
         if(v=="null"||v=="true"||v=="false") v="";
         print v
       }
     }}'
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
  head -c 2900 "$O_TMP"
  if [ -s "$E_TMP" ]; then
    echo
    echo "[stderr]"
    head -c 1000 "$E_TMP"
  fi
  rm -f "$O_TMP" "$E_TMP"
  return 0
}

run_cmd() {
  c=$(printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$c" ] && { echo "[安全] 空命令"; return 1; }
  OLDIFS=$IFS
  IFS=':'
  for b in $BL; do
    IFS=$OLDIFS
    case " $c " in *" $b "*)
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

extract_tool_call() {
  FLAT=$(printf '%s' "$1" | tr '\n' ' ')
  C=$(printf '%s' "$FLAT" | sed -n 's/.*\[CMD\]\([^[]*\)\[\/CMD\].*/\1/p' | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$C" ] && { printf '%s' "$C"; return 0; }
  C=$(printf '%s' "$FLAT" | sed -n 's/.*<parameter[^>]*name="command"[^>]*>\([^<]*\)<\/parameter>.*/\1/p' | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$C" ] && { printf '%s' "$C"; return 0; }
  B=$(printf '%s' "$FLAT" | grep -o -E '(run_terminal|terminal|shell|bash|exec|cmd|run|终端|执行|运行|命令)[[:space:]]*\([^)]*\)' | head -n 1)
  if [ -n "$B" ]; then
    B2=$(printf '%s' "$B" | sed 's/^[^()]*([[:space:]]*//; s/)[[:space:]]*$//')
    C=$(printf '%s' "$B2" | sed -n 's/.*command[[:space:]]*[:=][[:space:]]*\(["'"'"'][^"'"'"']*["'"'"']\).*/\1/p' | head -n 1 | sed 's/^["'"'"']//; s/["'"'"']$//')
    [ -z "$C" ] && C=$(printf '%s' "$B2" | sed -n 's/\(["'"'"'][^"'"'"']*["'"'"']\).*/\1/p' | head -n 1 | sed 's/^["'"'"']//; s/["'"'"']$//')
    [ -n "$C" ] && { printf '%s' "$C"; return 0; }
  fi
  C=$(printf '%s' "$FLAT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')
  [ -n "$C" ] && { printf '%s' "$C"; return 0; }
  C=$(printf '%s' "$FLAT" | grep -o -E '(run_terminal|terminal|shell|bash|exec|cmd|run|终端|执行|运行|命令)[[:space:]]*[:：][[:space:]]*[^"'"'"'`<（），。；;、]+' | head -n 1 | sed 's/^[^:：]*[:：][[:space:]]*//')
  [ -n "$C" ] && { printf '%s' "$C"; return 0; }
  return 1
}

ask_llm() {
  RESP_TMP=/data/local/tmp/agent_resp_$$.txt
  "$CURL" -sS --max-time 300 "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$1" > "$RESP_TMP" 2>/dev/null
  ACCUM=""; TC_ARGS=""; TC_ID=""; TOTAL_USAGE=0; REASON=""
  RESP=$(cat "$RESP_TMP" 2>/dev/null)
  C=$(json_val "$RESP" content)
  TCA=$(json_val "$RESP" arguments)
  TCID=$(printf '%s' "$RESP" | sed -n 's/.*"tool_calls":[[:space:]]*\[[[:space:]]*{"id":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  U=$(json_val "$RESP" total_tokens)
  R=$(json_val "$RESP" reasoning_content)
  [ -n "$C" ] && ACCUM="$C"
  [ -n "$TCA" ] && TC_ARGS="$TCA"
  [ -n "$TCID" ] && TC_ID="$TCID"
  [ -n "$U" ] && [ "$U" -gt 0 ] 2>/dev/null && TOTAL_USAGE=$U
  [ -n "$R" ] && REASON="$R"
  if [ -n "$ACCUM" ]; then
    ALEN=${#ACCUM}
    if [ "$ALEN" -gt 4000 ]; then
      echo "[正文] (超4000字符, 截断显示):"
      printf '%s' "$ACCUM" | head -c 4000; echo
    else
      echo "[正文]:"
      printf '%s\n' "$ACCUM"
    fi
  fi
  if [ -n "$REASON" ]; then
    RLEN=${#REASON}
    if [ "$RLEN" -gt 2000 ]; then
      echo "[思维链] (超2000字符, 截断显示):"
      printf '%s' "$REASON" | head -c 2000; echo
    else
      echo "[思维链]:"
      printf '%s\n' "$REASON"
    fi
  fi
  if [ -z "$ACCUM" ] && [ -z "$TC_ARGS" ]; then
    ACCUM="(无输出)"
  fi
  rm -f "$RESP_TMP"
}

compress_summary() {
  BODY=$(printf '{"model":"%s","messages":[%s,{"role":"user","content":"[总结所有]"}],"stream":false}' \
    "$MODEL" "$MSGS")
  RESP=$("$CURL" -s --max-time 300 "$API_URL" \
    -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "$BODY")
  NEW=$(json_val "$RESP" content)
  [ -z "$NEW" ] && NEW=$(json_val "$RESP" message)
  [ -z "$NEW" ] && NEW="解析失败"
  SUMMARY="历史背景：$NEW"
  MSGS="{\"role\":\"system\",\"content\":\"$(esc "$SYS")\"},{\"role\":\"user\",\"content\":\"$(esc "$SUMMARY")\"},{\"role\":\"user\",\"content\":\"$(esc "$QUESTION")\"}"
  echo "[压缩] token超$MAX_TOK，历史已压缩为内存摘要，继续当前会话"
}

SYS='[ROLE] Agent For Shell | [LANG] zh-CN
[MUST] 工具先于语言：思考→run_terminal→执行→验证
[MUST] 产出写文件；简单问答直接回复
[MUST] 查优于猜：记忆→命令探查→推理，不跳过
[MUST_NOT] 草稿当交付；未完成→继续调工具
[MUST] 代码/命令/列表用```包裹，不准裸文本
[MUST] 算优于估：dumpsys/getprop/ls/cat实测，不目测
[TOOL] 唯一工具 run_terminal，参数 command+explain+dangerous

[SYS] 环境=adb shell 权限，可执行 dumpsys/settings/getprop/pm/am/input 等系统命令
[SAFETY] 禁止危险操作(删除/覆盖/格式化/卸载/重启/提权)：
  必须时→明确告知命令+影响→请求授权→同意后 dangerous=true 执行

[BOOT] 新对话开始，不跳过：
  ① run_terminal: ls /data/local/tmp/agent_mem/ → 有记忆文件→cat 相关文件复用 | 无→标"无历史"
  ② 明确任务目标与执行计划
  ③ 进入 [THINK]

[MEMORY_LOOP] 前查后存，漏→不交付（记忆目录读写权在 agent，程序层零落盘不干预）：
  前·· 需要历史→run_terminal: ls /data/local/tmp/agent_mem/ 列出记忆文件 → cat 相关文件 → 命中复用 | 无→标"无历史"
  后·· 有价值结论→run_terminal: echo 总结 >> /data/local/tmp/agent_mem/YYYYMMDD.md（追加：需求+做了什么+关键命令+结果+教训，一行一条）

[THINK] 思考强度MAX，P1-P5全执行（<think>内，绝不进<answer>）：
  P1 拆解：核心需求+隐含需求 → 明确目标
  P2 回记忆：run_terminal: ls 记忆目录+cat 相关文件 → 命中复用+标源 | 无→命令探查→不编造
  P3 规划：步骤表(步骤→命令→预期→验证)
  P4 执行：逐步 run_terminal，失败→读报错→修正重试
  P5 存忆：完成→run_terminal: echo 总结 >> 记忆目录/YYYYMMDD.md（日期文件，一行一条）

[SUMMARY] 收到"[总结所有]"→ 不调工具，总结全部历史，输出纯摘要正文

[DELIVER] 核对(缺一不交付)：□记忆已回 □任务完成 □输出已验证 □问题已回答

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
  BODY=$(printf '{"model":"%s","messages":[%s],"tools":%s,"tool_choice":"auto"}' \
    "$MODEL" "$MSGS" "$TOOLS")
  ask_llm "$BODY"

  if [ "$TOTAL_USAGE" -gt "$MAX_TOK" ] 2>/dev/null; then
    compress_summary
  fi

  if [ -n "$TC_ARGS" ]; then
    CMD=$(json_val "$TC_ARGS" command)
    if [ -n "$CMD" ]; then
      [ -n "$TC_ID" ] || TC_ID="call_gen"
      echo "[工具] $CMD"
      OUT=$(run_ui "$CMD")
      echo "$OUT"
      if [ -n "$ACCUM" ]; then CONTENT_JSON=$(printf '"%s"' "$(esc "$ACCUM")"); else CONTENT_JSON="null"; fi
      if [ -n "$REASON" ]; then REASON_JSON=$(printf '"%s"' "$(escj "$REASON")"); else REASON_JSON="null"; fi
      MSGS="$MSGS,{\"role\":\"assistant\",\"content\":$CONTENT_JSON,\"reasoning_content\":$REASON_JSON,\"tool_calls\":[{\"id\":\"$TC_ID\",\"type\":\"function\",\"function\":{\"name\":\"run_terminal\",\"arguments\":$(printf '"%s"' "$(esc "$TC_ARGS")")}}]}"
      MSGS="$MSGS,{\"role\":\"tool\",\"tool_call_id\":\"$TC_ID\",\"content\":$(printf '"%s"' "$(esc "$OUT")")}"
      continue
    fi
  fi

  CMD2=$(extract_tool_call "$ACCUM")
  if [ -n "$CMD2" ]; then
    if [ "$CMD2" = "$LAST_CAUGHT" ]; then
      REPEAT=$((REPEAT + 1))
      if [ "$REPEAT" -ge 3 ]; then
        echo "[防循环] 正文同一命令重复3次，按回答输出"
        break
      fi
    else
      LAST_CAUGHT="$CMD2"
      REPEAT=1
    fi
    echo "[工具] $CMD2"
    OUT=$(run_ui "$CMD2")
    echo "$OUT"
    if [ -n "$REASON" ]; then REASON_JSON=$(printf '"%s"' "$(escj "$REASON")"); else REASON_JSON="null"; fi
    MSGS="$MSGS,{\"role\":\"assistant\",\"content\":$(printf '"%s"' "$(esc "$ACCUM")"),\"reasoning_content\":$REASON_JSON}"
    MSGS="$MSGS,{\"role\":\"user\",\"content\":\"命令已执行，输出如下：$(esc "$OUT")\"}"
    continue
  fi

  break
done
