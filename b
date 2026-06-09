将战场切换到 **Ubuntu 22.04 LTS**，核心的排查逻辑和 RHEL 是完全通用的，但由于两者的“家族”（Debian 系 vs. RedHat 系）不同，**软件包的名字、配置文件的路径以及包管理命令（从 dnf 变成 apt）会有所调整**。
同样秉承**“零第三方软件、极轻量、不给生产增加负担”**的原则，以下是你在 Ubuntu 22.04 上开启同款监控矩阵的完整指南：
## 一、 基础指标监控：Sysstat (全量激活)
在 Ubuntu 上，sysstat 默认安装后甚至连历史收集功能都是**关闭**的，必须手动唤醒并调整路径。
### 1. 安装与启用
```bash
sudo apt update
sudo apt install sysstat -y

```
### 2. 修改 Ubuntu 专属配置文件
Ubuntu 的配置文件在 /etc/default/ 下，而不是 RHEL 的 /etc/sysconfig/。
```bash
sudo vi /etc/default/sysstat

```
做两处修改：
 * 将 ENABLED="false" 改为 ENABLED="true"（允许后台定时收集）。
 * 将 SADC_OPTIONS="" 修改为 SADC_OPTIONS="-S ALL"（开启全量指标，包括 TCP/ICMP 错误）。
修改后的文件关键部分应该像这样：
```text
ENABLED="true"
SADC_OPTIONS="-S ALL"

```
### 3. 重启并激活 Systemd 定时器
Ubuntu 22.04 使用 systemd timer 来控制收集频率（默认每 10 分钟一次）：
```bash
sudo systemctl enable --now sysstat
sudo systemctl restart sysstat

```
## 二、 行为与安全审计：Auditd (使用高性能现代语法)
为了避免你在 RHEL 上遇到的那类性能警告，我们在 Ubuntu 上直接部署**现代高性能语法**。
### 1. 安装
```bash
sudo apt install auditd -y

```
### 2. 配置高性能规则
Ubuntu 22.04 同样采用 augenrules 机制，规则文件路径与 RHEL 相同：
```bash
sudo vi /etc/audit/rules.d/audit.rules

```
在文件末尾加上专为 Ubuntu 环境（假设同样运行 Apache/Nginx）定制的高性能规则：
```text
# 1. 监控 Web 服务器核心配置（如果你们 Ubuntu 上用的是 Nginx，可以换成 /etc/nginx/）
-a always,exit -F arch=b64 -F path=/etc/httpd/conf/httpd.conf -F perm=wa -F key=web_config

# 2. 监控系统网络套接字（查看是否有非法端口抢占）
-a always,exit -F arch=b64 -S socket -k network_monitor

# 3. 监控时区与时间篡改
-a always,exit -F arch=b64 -F path=/etc/localtime -F perm=wa -F key=time_change

```
### 3. 加载规则
```bash
sudo augenrules --load

```
## 三、 进程生死簿：Acct (Ubuntu 中的 Psacct)
**注意改名：** 在 RHEL 中这个工具叫 psacct，但在 Ubuntu/Debian 家族中，它的名字叫 **acct**。不过别担心，安装后的底层命令（如 lastcomm）是完全一样的。
### 1. 安装与启用
```bash
sudo apt install acct -y
# Ubuntu 会自动创建并启动服务，稳妥起见我们显式启动一下
sudo systemctl enable --now acct

```
### 2. 故障倒查命令（完全一致）
```bash
# 检查最近是谁、在几点几分执行了什么命令
lastcomm nginx
lastcomm kill

```
## 四、 日志安全锁：Systemd-Journald
由于 Ubuntu 22.04 同样基于 Systemd 架构，因此它的日志限流和控盘策略与 RHEL **完全一模一样**。
### 1. 修改配置（安全控盘 2G）
```bash
sudo vi /etc/systemd/journald.conf

```
直接在 [Journal] 标签下，把之前那套既不漏日志、又能死死卡住空间的“组合拳”抄过来：
```text
[Journal]
Storage=persistent
RateLimitIntervalSec=0
RateLimitBurst=0
SystemMaxUse=2G
SystemKeepFree=10G
SystemMaxFileSize=200M

```
### 2. 重启生效
```bash
sudo systemctl restart systemd-journald

```
### 💡 顺口溜总结：两台服务器的对齐状态
现在你手里管着两台异构的 Linux，可以做个简单的心智对齐：
| 监控维度 | RHEL 9.6 战场 | Ubuntu 22.04 战场 |
|---|---|---|
| **包管理器** | dnf | apt |
| **网络历史指标** | /etc/sysconfig/sysstat | /etc/default/sysstat |
| **内核行为审计** | auditd (规则与现代语法两机通用) | auditd (规则与现代语法两机通用) |
| **进程历史记账** | psacct | acct |
| **安全日志控盘** | journald.conf (完全通用) | journald.conf (完全通用) |
把这两台机器的配置都铺好后，你就相当于给整个生产环境穿上了一层“防弹衣”。下次不管网络组怎么切灾备、系统怎么报错，你随时能在两台服务器上本地秒出证据。
