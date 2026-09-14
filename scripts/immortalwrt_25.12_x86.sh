#!/bin/bash

# 1. 修改默认 IP
sed -i '/lan)/s/192\.168\.[0-9.]*/192.168.100.253/' package/base-files/files/bin/config_generate

# 2.移除要替换的包
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-dae
rm -rf feeds/packages/net/dae
rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/packages/net/daed
#rm -rf feeds/packages/lang/golang
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
#rm -rf feeds/luci/applications/luci-app-netdata

# 3. 增强版稀疏克隆函数 (参数1是分支名, 参数2是仓库地址, 参数3是子目录，同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开)
function git_sparse_clone() {
  local branch=""
  local repourl=""
  local sub_paths=()
  local repodir=""

  # 1. 智能参数解析
  if [[ "$1" == http* ]]; then
    # 情况 A: 第一个参数是 URL (可能是网页链接或纯仓库地址)
    if [[ "$1" == *"tree/"* ]]; then
      # 自动解析 GitHub 网页格式: .../tree/分支/路径
      repourl="${1%/tree/*}"
      local rest="${1#*/tree/}"
      branch="${rest%%/*}"
      sub_paths=("${rest#*/}")
      echo ">> 检测到网页 URL，自动解析分支: [$branch], 路径: [${sub_paths[0]}]"
    else
      # 纯仓库地址，尝试使用第二个参数作为分支，默认为 main
      repourl="$1"
      branch="${2:-main}"
      shift 2
      sub_paths=("$@")
      echo ">> 检测到纯仓库地址，使用分支: [$branch]"
    fi
  else
    # 情况 B: 兼容你原始的代码格式 (参数1:分支 参数2:地址 参数3+:路径)
    branch="$1"
    repourl="$2"
    shift 2
    sub_paths=("$@")
    echo ">> 使用原始传参模式，分支: [$branch]"
  fi

  # 2. 准备克隆环境
  # 使用 basename 处理 .git 后缀，防止 cd 失败
  repodir=$(basename "$repourl" .git)
  
  # 3. 执行极速克隆 (Blob 过滤 + 稀疏模式)
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$repodir"
  if [ $? -ne 0 ]; then
    echo "错误: 克隆失败，请检查 URL 或分支名。"
    return 1
  fi

  cd "$repodir" || return

  # 4. 如果没有指定子路径，默认拉取整个仓库内容
  if [ ${#sub_paths[@]} -eq 0 ]; then
    echo ">> 未指定子路径，拉取全量代码..."
    git sparse-checkout disable
  else
    echo ">> 正在提取指定目录: ${sub_paths[*]}"
    git sparse-checkout set "${sub_paths[@]}"
  fi

  # 5. 搬运到 ../package/
  mkdir -p ../package/
  for sub in "${sub_paths[@]}"; do
    if [ -d "$sub" ]; then
      local target_name=$(basename "$sub")
      local target="../package/$target_name"
      [ -d "$target" ] && rm -rf "$target"
      mv -f "$sub" ../package/
      echo "   [已完成] $target_name"
    fi
  done

  # 6. 清理
  cd .. && rm -rf "$repodir"
  echo ">> 任务结束。"
}

# 4. 更新 golang 1.26 版本
#git clone --depth=1 -b 26.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# 5. 主题与常规插件
# 添加argon主题
#git clone --depth=1 -b master https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
#git clone --depth=1 -b master https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
# 添加Lucky
#git clone --depth=1 -b main https://github.com/gdy666/luci-app-lucky package/lucky
# 添加系统高级设置
git clone --depth=1 -b main https://github.com/free-diy/luci-app-advancedplus package/luci-app-advancedplus
# 添加kenzok8大鹅
git clone --depth=1 -b main https://github.com/kenzok8/openwrt-daede package/openwrt-daede
# 添加QiuSimons大鹅
#git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed package/openwrt-daed
# 添加Passwall 及其依赖
git clone --depth=1 -b main https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
git clone --depth=1 -b main https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
#git clone --depth=1 -b main https://github.com/Openwrt-Passwall/openwrt-passwall2 package/passwall12-luci
# 添加ssrplus
#git clone --depth=1 -b dev https://github.com/fw876/helloworld.git package/helloworld
# 添加中文版netdata
#git clone --depth=1 -b master https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata
# 添加应用管理
#git clone --depth=1 -b master https://github.com/destan19/OpenAppFilter package/OpenAppFilter
# 添加momo
#git clone --depth=1 -b main https://github.com/nikkinikki-org/OpenWrt-momo package/OpenWrt-momo
# 添加壁虎合集
#git clone --depth=1 -b main https://github.com/free-diy/all-proxy package/all-proxy
# 添加nikki
git clone --depth=1 -b main https://github.com/nikkinikki-org/OpenWrt-nikki package/OpenWrt-nikki
#git_sparse_clone main https://github.com/nikkinikki-org/OpenWrt-nikki luci-app-nikki mihomo-meta nikki
# 添加openclash
git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash
# 添加taskplan定时设置插件
git_sparse_clone main https://github.com/sirpdboy/luci-app-taskplan luci-app-taskplan
# 添加设备关机功能
git_sparse_clone master https://github.com/sirpdboy/luci-app-poweroffdevice luci-app-poweroffdevice
# 添加istore
#git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
#git_sparse_clone main https://github.com/linkease/istore luci
# 特别注意：iStore 的目录在仓库里叫 luci，移动到 package 后我们给它改个名防止冲突
#[ -d package/luci ] && mv package/luci package/luci-app-istore

# 添加rtp2httpd
#git_sparse_clone https://github.com/stackia/rtp2httpd/tree/main/openwrt-support/luci-app-rtp2httpd
#git_sparse_clone https://github.com/stackia/rtp2httpd/tree/main/openwrt-support/rtp2httpd

# 6. 修复与优化编译环境
# 禁用 Rust 的 LLVM 编译，节省 10GB+ 空间和大量时间
#if [ -f feeds/packages/lang/rust/Makefile ]; then
#    sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
#fi

# 7. 其他
# 专门针对 advancedplus 的流氓逻辑进行清洗
#if [ -f package/luci-app-advancedplus/root/etc/init.d/advancedplus ]; then
#    sed -i '/zsh/d' package/luci-app-advancedplus/root/etc/init.d/advancedplus
#fi

# 8. 删除多余的插件
#rm -rf package/all-proxy/mihomo
#rm -rf package/helloworld/mihomo

