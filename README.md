## 如何使用

要使用本项目, 请通过 SSH 以 root 身份连接你的 Proxmox VE 节点, 并执行以下操作:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/0118Add/rule/main/pve-manager-status.sh)"
```

执行完毕后, 使用 Ctrl + F5 刷新浏览器 Proxmox VE Web 管理页面缓存.

若此时可以看到 PVE-Manager-Status 带来的扩展的硬件监控信息, 但无法看到风扇转速信息, 你还需要继续执行以下步骤来安裝 IT87 系列传感器驱动包:

```
wget -O /root/it87-dkms_1.0.63-1_all.deb https://raw.githubusercontent.com/0118Add/rule/main/it87-dkms_1.0.63-1_all.deb && apt install /root/it87-dkms_1.0.63-1_all.deb && rm -f /root/it87-dkms_1.0.63-1_all.deb
```

执行完毕后, 重启系统并再次检查风扇转速信息.

