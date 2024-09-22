# Dnsmasq SNIproxy One-click Install

## 脚本说明：
 
* 原理简述：使用[Dnsmasq](http://thekelleys.org.uk/dnsmasq/doc.html)的DNS将网站解析劫持到[SNI proxy](https://github.com/dlundquist/sniproxy)反向代理的页面上。

* 用途：让无法观看流媒体的VPS可以观看（前提：VPS中要有一个是能观看流媒体的）。

* 特性：

    **1、完整版**

    在原脚本基础上，增加了Youtube分流规则。
    默认解锁`Netflix Hulu HBO DisneyPlus Youtube`[等](https://github.com/wongjai/dnsmasq_sniproxy_install/blob/master/proxy-domains-all.txt)

   **2、宋仲基版**

    修改了原脚本的规则，仅保留了Youtube分流规则，安装后供宋仲基使用。
    
   **3、台湾流媒体解锁版**

    修改了原脚本的规则，增加了Dazn | Disney+ | Netflix | YouTube Premium | Amazon Prime Video | TVBAnywhere+ | Spotify | KKTV | LiTV | LineTV.TW | HBO | Bahamut | Bilibili国际 分流规则，安装后供台湾流媒体解锁使用。

   ***如果需要自定义***

    可Folk后，自行编辑proxy-domians相关文件。

    或：安装后，修改`/etc/dnsmasq.d/custom_netflix.conf`和`/etc/sniproxy.conf`



* 脚本支持系统：CentOS6+, Debian8+, Ubuntu16+
    * CentOS6/7/8， Debian8/9/10, Ubuntu16/18 已测试成功
    * 理论上不限虚拟化类型，如有问题请反馈
    * 如果脚本最后显示的IP和实际公网IP不相符，请修改一下文件`/etc/sniproxy.conf`中的IP地址

<br /><br />

## 脚本用法：

    bash dnsmasq_sniproxy.sh [-h] [-i] [-f] [-id] [-is] [-fs] [-u] [-ud] [-us]
      -h , --help                显示帮助信息
      -i , --install             安装 Dnsmasq + SNI Proxy
      -f , --fastinstall         快速安装 Dnsmasq + SNI Proxy
      -id, --installdnsmasq      仅安装 Dnsmasq
      -is, --installsniproxy     仅安装 SNI Proxy
      -fs, --fastinstallsniproxy 快速安装 SNI Proxy
      -u , --uninstall           卸载 Dnsmasq + SNI Proxy
      -ud, --undnsmasq           卸载 Dnsmasq
      -us, --unsniproxy          卸载 SNI Proxy

### 快速安装-完整版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_all.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_all.sh && bash dnsmasq_sniproxy_all.sh -f
```
### 快速安装-宋仲基版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_youtube.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_youtube.sh && bash dnsmasq_sniproxy_youtube.sh -f
```
### 快速安装-DisneyPlus版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_disney.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_disney.sh && bash dnsmasq_sniproxy_disney.sh -f
```
### 快速安装-台湾流媒体版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_tw.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_tw.sh && bash dnsmasq_sniproxy_tw.sh -f
```

### 快速安装-Nearouter香港版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_nr.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_nr.sh && bash dnsmasq_sniproxy_nr.sh -f
```

### 普通安装-完整版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_all.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_all.sh && bash dnsmasq_sniproxy_all.sh -i
```
### 普通安装-宋仲基版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_youtube.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_youtube.sh && bash dnsmasq_sniproxy_youtube.sh -i
```

### 卸载-完整版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_all.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_all.sh && bash dnsmasq_sniproxy_all.sh -u
```
### 卸载-宋仲基版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_youtube.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_youtube.sh && bash dnsmasq_sniproxy_youtube.sh -u
```
### 卸载-Disney版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_disney.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_disney.sh && bash dnsmasq_sniproxy_disney.sh -u
```
### 卸载-台湾流媒体版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_tw.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_tw.sh && bash dnsmasq_sniproxy_tw.sh -u
```

### 卸载-Nearouter香港版：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy_nr.sh https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy_nr.sh && bash dnsmasq_sniproxy_nr.sh -u
```
<br /><br />
## 使用方法：
将代理VPS的DNS地址修改为这个主机的IP就可以了，如果不能用，记得只保留一个DNS地址试一下。

防止滥用，建议不要随意公布IP地址，或使用防火墙做好限制工作。

### 调试排错：
- 确认sniproxy有效运行

  查看sni状态：systemctl status sniproxy

  如果sni不在运行，检查一下是否有其他服务占用80,443端口，以防端口冲突，先将其他服务更改一下监听端口，查看端口监听：netstat -tlunp|grep 443

- 确认防火墙放行80,443,53

  调试可直接关闭防火墙 systemctl stop firewalld.service

  阿里云/谷歌云/AWS等运营商安全组端口同样需要放行
  可通过其他服务器 telnet vpsip 53 以及 telnet vpsip 443 进行测试

- 解析域名

  尝试用其他服务器配置完毕dns后，解析域名：nslookup netflix.com 判断IP是否是NETFLIX代理机器IP
  如果不存在nslookup命令，CENTOS安装：yum install -y bind-utils DEBIAN安装：apt-get -y install dnsutils

---

___本脚本仅限解锁流媒体使用___
