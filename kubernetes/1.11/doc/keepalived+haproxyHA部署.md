本次部署一个三节点高可用 haproxy+keepalived 集群，分别为：192.168.10.100、192.168.10.101、192.168.10.102。VIP 地址 192.168.10.104

1.安装 haproxy+keepalived,注： 3台 haproxy+keepalived 节点都需安装

    yum install -y haproxy keepalived
    mkdir /var/log/haproxy/;chown haproxy.haproxy /var/log/haproxy/;mkdir /run/haproxy


2.配置 keepalived

    [root@master01 keepalived]# vim keepalived.conf


    bal_defs {
       notification_email {
            329672369@qq.com
       }
       notification_email_from Alexandre.Cassen@firewall.loc
       smtp_server 192.168.200.1
       smtp_connect_timeout 30
       router_id LVS_DEVEL
      vrrp_mcast_group4 224.0.0.100

    }
    vrrp_script chk_keepalived {
            script "/etc/keepalived/check_haproxy.sh"
            interval 3
    }
    vrrp_instance VI_1 {
        state MASTER  ## 如果配置主从，其他2个从服务器改为BACKUP即可
        interface ens32
        virtual_router_id 51
        priority 91  # 从服务器优先级设置小于91的数即可
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass test@123
        }
        virtual_ipaddress {
            192.168.10.104
        }
        track_script {
            chk_keepalived
            }
    }

    健康检测脚本：
    #!/bin/bash
    flag=$(systemctl status haproxy &> /dev/null;echo $?)

    if [[ $flag != 0 ]];then
            echo "haproxy is down,close the keepalived"
            systemctl stop keepalived
    fi

    改keepalived启动文件 vi /usr/lib/systemd/system/keepalived.service 以下部分:

    [Unit]
    Description=LVS and VRRP High Availability Monitor
    After=syslog.target network-online.target haproxy.service
    Requires=haproxy.service


keepalived配置文件三台主机基本一样，除了state，主节点配置为MASTER，备节点配置BACKUP，优化级参数priority，主节点设置最高，备节点依次递减
自定义的检测脚本作用是检测本机haproxy服务状态，如果不正常就停止本机keepalived，释放VIP
这里没有考虑keepalived脑裂的问题，后期可以在脚本中加入相关检测。


3.配置 haproxy

    3台节点配置一模一样 配置文件 vim /etc/haproxy/haproxy.cfg

    global
        log 127.0.0.1 local0 info
        log /var/log/haproxy    local0
        log /var/log/haproxy    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin
        stats timeout 30s
        user haproxy
        group haproxy
        daemon
        nbproc 1

    defaults
           log global
          # mode http
          # option httplog
          # option dontlognull
           retries 3
           timeout connect 5000ms
           timeout client 50000ms
           timeout server 50000ms
           timeout check 50000ms
           timeout queue 50000m

    listen  admin_stats
            bind 0.0.0.0:8888
            mode http
            maxconn  1000
            stats  enable
            stats  hide-version
            stats  refresh 30s
            stats  show-node
            stats  realm Haproxy\ Statistics
            stats  uri /haproxy?stats

    frontend k8s_https *:8443
            mode tcp
            maxconn 2000
            default_backend https_sri

    backend https_sri
            balance roundrobin
            server master01 192.168.10.100:6443  check
            server master02 192.168.10.101:6443  check
            server master03 192.168.10.102:6443  check

    http://192.168.10.102:8888/haproxy?stats  haproxy状态查看。

4.测试：依次在master01上停止haproxy检测vip是否会绑定到master02/03

    [root@master01 haproxy]# ip a
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
        inet6 ::1/128 scope host
           valid_lft forever preferred_lft forever
    2: ens32: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
        link/ether 00:0c:29:94:15:fb brd ff:ff:ff:ff:ff:ff
        inet 192.168.10.100/24 brd 192.168.10.255 scope global ens32
           valid_lft forever preferred_lft forever
        inet 192.168.10.104/32 scope global ens32
