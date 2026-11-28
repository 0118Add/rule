#!/bin/sh
# 仿 ShellCrash 架构的 reF1nd 版 sing-box 极简裸核管理脚本 (彻底防截断版)

GH_PROXY="https://ghfast.top"
PROTO="https://"
DOMAIN="github.com"
REPO_USER="reF1nd"
REPO_NAME="sing-box-releases"

BASE_DIR="/etc/sb_ref1nd"
BIN_PATH="$BASE_DIR/sing-box"
CONF_PATH="$BASE_DIR/config.json"
SUB_FILE="$BASE_DIR/sub.url"

mkdir -p "$BASE_DIR"

# 拼接完整仓库根路径（防止浏览器复制截断）
REPO_BASE="${PROTO}${DOMAIN}/${REPO_USER}/${REPO_NAME}"

gh_url() {
    if [ -n "$GH_PROXY" ]; then
        echo "${GH_PROXY}/$1"
    else
        echo "$1"
    fi
}

# 自动注册全局快捷命令 sb
SELF_PATH=$(readlink -f "$0" 2>/dev/null || echo "$0")
if [ "$SELF_PATH" != "/usr/bin/sb" ] && [ -w "/usr/bin" ]; then
    cp -f "$SELF_PATH" /usr/bin/sb
    chmod +x /usr/bin/sb
fi

get_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        *) echo "unsupported" ;;
    esac
}

# 1. 安装 / 升级 reF1nd 版 sing-box 裸核
install_ref1nd_core() {
    ARCH=$(get_arch)
    [ "$ARCH" = "unsupported" ] && { echo "❌ 不支持的 CPU 架构: $(uname -m)"; return 1; }

    echo "请选择要安装的 reF1nd 内核分支："
    echo "  1. Stable 正式版 (推荐)"
    echo "  2. Testing 测试版 (包含 alpha/beta/rc)"
    printf "请输入数字 [1-2，默认 1]: "
    read -r BRANCH_CHOICE

    echo "🔍 正在检索 ${REPO_USER}/${REPO_NAME} 最新版本号..."
    RELEASES_URL=$(gh_url "${REPO_BASE}/releases")
    RELEASES_HTML=$(curl -fsSL --connect-timeout 15 "$RELEASES_URL" 2>/dev/null)
    
    if [ -z "$RELEASES_HTML" ] && [ -n "$GH_PROXY" ]; then
        echo "⚠️ 加速节点检索超时，尝试直连..."
        RELEASES_HTML=$(curl -fsSL --connect-timeout 15 "${REPO_BASE}/releases" 2>/dev/null)
    fi

    if [ -n "$RELEASES_HTML" ]; then
        if [ "$BRANCH_CHOICE" = "2" ]; then
            LATEST_TAG=$(echo "$RELEASES_HTML" | grep -oE 'releases/tag/v[0-9]+\.[0-9]+\.[0-9]+-(alpha|beta|rc)[^"'\'']*' | head -n1 | awk -F'/' '{print $NF}')
        else
            LATEST_TAG=$(echo "$RELEASES_HTML" | grep -oE 'releases/tag/v[0-9]+\.[0-9]+\.[0-9]+(-reF1nd)?' | head -n1 | awk -F'/' '{print $NF}')
        fi
    fi

    if [ -z "$LATEST_TAG" ]; then
        echo "⚠️ 自动解析未命中，请手动输入版本号（例如 v1.14.6-reF1nd 或 1.14.6）："
        read -r INPUT_VER
        [ -z "$INPUT_VER" ] && return 1
        # 自动补全开头的 v
        case "$INPUT_VER" in
            v*) LATEST_TAG="$INPUT_VER" ;;
            *)  LATEST_TAG="v${INPUT_VER}" ;;
        esac
    fi
    echo "📌 锁定版本标签: ${LATEST_TAG}"

    # 检索真实资产文件名
    ASSETS_URL=$(gh_url "${REPO_BASE}/releases/expanded_assets/${LATEST_TAG}")
    ASSETS_HTML=$(curl -fsSL --connect-timeout 15 "$ASSETS_URL" 2>/dev/null)
    ASSET_PATH=$(echo "$ASSETS_HTML" | grep -oE "/${REPO_USER}/${REPO_NAME}/releases/download/${LATEST_TAG}/sing-box-[^\"]*linux-${ARCH}[^\"]*\.tar\.gz" | head -n1)

    if [ -n "$ASSET_PATH" ]; then
        RAW_DOWNLOAD="${PROTO}${DOMAIN}${ASSET_PATH}"
    else
        VER=${LATEST_TAG#v}
        # 优先尝试带 -reF1nd 的标准文件名，若不存在再试不带后缀的
        RAW_DOWNLOAD="${REPO_BASE}/releases/download/${LATEST_TAG}/sing-box-${VER}-linux-${ARCH}.tar.gz"
    fi

    DOWNLOAD_URL=$(gh_url "$RAW_DOWNLOAD")
    echo "📥 正在加速下载: $DOWNLOAD_URL"

    if ! curl -fsSL --retry 3 -o /tmp/sb_ref1nd.tar.gz "$DOWNLOAD_URL"; then
        # 自动尝试带 -reF1nd 后缀的标签格式兜底
        case "$LATEST_TAG" in
            *-reF1nd) ;;
            *)
                ALT_TAG="${LATEST_TAG}-reF1nd"
                ALT_VER=${ALT_TAG#v}
                ALT_URL=$(gh_url "${REPO_BASE}/releases/download/${ALT_TAG}/sing-box-${ALT_VER}-linux-${ARCH}.tar.gz")
                echo "🔄 尝试备用命名下载: $ALT_URL"
                curl -fsSL --retry 3 -o /tmp/sb_ref1nd.tar.gz "$ALT_URL" || { echo "❌ 下载失败，请核对版本号是否正确！"; return 1; }
                ;;
        esac
    fi

    rm -rf /tmp/sb_extract && mkdir -p /tmp/sb_extract
    tar -xzf /tmp/sb_ref1nd.tar.gz -C /tmp/sb_extract

    EXTRACTED_BIN=$(find /tmp/sb_extract -type f -name "sing-box" | head -n1)
    [ -z "$EXTRACTED_BIN" ] && { echo "❌ 压缩包内未找到 sing-box 主程序！"; return 1; }

    mv -f "$EXTRACTED_BIN" "$BIN_PATH"
    chmod +x "$BIN_PATH"
    rm -rf /tmp/sb_ref1nd.tar.gz /tmp/sb_extract

    enable_ip_forward
    setup_service
    echo "✅ reF1nd 内核 (${LATEST_TAG}) 安装完成！"
}

enable_ip_forward() {
    if [ -d "/etc/sysctl.d" ]; then
        cat << 'EOF' > /etc/sysctl.d/99-sb-ref1nd.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
        sysctl --system >/dev/null 2>&1
    fi
}

setup_service() {
    if [ -f "/etc/rc.common" ]; then
        cat << 'EOF' > /etc/init.d/sb_ref1nd
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

start_service() {
    [ ! -f "/etc/sb_ref1nd/config.json" ] && return 1
    procd_open_instance
    procd_set_param command /etc/sb_ref1nd/sing-box run -c /etc/sb_ref1nd/config.json -D /etc/sb_ref1nd
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF
        chmod +x /etc/init.d/sb_ref1nd
        /etc/init.d/sb_ref1nd enable
    elif command -v systemctl >/dev/null 2>&1; then
        cat << 'EOF' > /etc/systemd/system/sb_ref1nd.service
[Unit]
Description=sing-box reF1nd service
After=network.target nss-lookup.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/etc/sb_ref1nd/sing-box run -c /etc/sb_ref1nd/config.json -D /etc/sb_ref1nd
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable sb_ref1nd
    fi
}

update_config() {
    [ ! -x "$BIN_PATH" ] && { echo "❌ 请先安装 reF1nd 内核 (选项 1)！"; return 1; }

    if [ ! -s "$SUB_FILE" ]; then
        printf "请输入 sing-box (reF1nd) 配置文件或 Sub-Store 订阅链接: "
        read -r INPUT_URL
        [ -z "$INPUT_URL" ] && { echo "❌ 链接不能为空！"; return 1; }
        echo "$INPUT_URL" > "$SUB_FILE"
    fi

    URL=$(cat "$SUB_FILE")
    echo "📥 正在拉取最新配置..."
    curl -fsSL --retry 3 -o /tmp/sb_ref1nd_test.json "$URL" || { echo "❌ 配置下载失败，已保留旧配置！"; return 1; }

    echo "🔍 正在使用 reF1nd 内核校验配置语法..."
    if "$BIN_PATH" check -c /tmp/sb_ref1nd_test.json; then
        mv -f /tmp/sb_ref1nd_test.json "$CONF_PATH"
        echo "✅ 语法校验通过！正在重启服务..."
        control_service restart
    else
        rm -f /tmp/sb_ref1nd_test.json
        echo "❌ 新配置校验不通过！已自动丢弃并保留原配置，网络不受影响。"
        return 1
    fi
}

control_service() {
    ACTION="$1"
    if [ -f "/etc/init.d/sb_ref1nd" ]; then
        /etc/init.d/sb_ref1nd "$ACTION"
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl "$ACTION" sb_ref1nd
    fi
    echo ">>> 服务已执行: $ACTION"
}

show_status() {
    if pgrep -f "$BIN_PATH" >/dev/null 2>&1; then
        echo "🟢 运行状态: 运行中 (PID: $(pgrep -f "$BIN_PATH"))"
        echo "📌 当前内核: $("$BIN_PATH" version | head -n1)"
    else
        echo "🔴 运行状态: 未运行"
    fi
    echo "----------------------------------------"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -u sb_ref1nd -n 25 --no-pager
    else
        logread -e sing-box | tail -n 25
    fi
}

enable_cron() {
    if [ -d "/etc/cron.d" ]; then
        echo "0 4 * * * root /usr/bin/sb update" > /etc/cron.d/sb_ref1nd
        chmod 644 /etc/cron.d/sb_ref1nd
    else
        (crontab -l 2>/dev/null | grep -v "/usr/bin/sb update"; echo "0 4 * * * /usr/bin/sb update") | crontab -
    fi
    echo "✅ 已开启每天凌晨 04:00 自动更新订阅配置！"
}

if [ "$1" = "update" ]; then
    update_config
    exit $?
fi

while true; do
    echo ""
    echo "=========================================="
    echo "   sing-box (reF1nd 裸核) 轻量控制台"
    echo "=========================================="
    echo "  1. 安装 / 升级 reF1nd 内核 (加速通道)"
    echo "  2. 导入 / 更新订阅配置 (带语法校验)"
    echo "  3. 清除并重设订阅链接"
    echo "  4. 启动 / 重启服务"
    echo "  5. 停止服务"
    echo "  6. 查看运行状态与最近日志"
    echo "  7. 开启每天 04:00 自动更新配置"
    echo "  0. 退出 (输入 sb 可随时重新打开)"
    echo "=========================================="
    printf "请选择操作 [0-7]: "
    read -r CHOICE
    echo ""
    case "$CHOICE" in
        1) install_ref1nd_core ;;
        2) update_config ;;
        3) rm -f "$SUB_FILE" && echo "✅ 已清除旧订阅链接，请重新执行选项 2。" ;;
        4) control_service restart ;;
        5) control_service stop ;;
        6) show_status ;;
        7) enable_cron ;;
        0) exit 0 ;;
        *) echo "无效选项，请输入 0-7。" ;;
    esac
done
