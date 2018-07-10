使用全手工方式安装最新版kubernetes1.11

    高可用安装3个master节点，使用使用lvs做负载均衡提升性能。

    master部署3节点，apiserver使用keepalived+haproxy实现高可用。

        192.168.10.100  master01+haproxy+keepalived
        192.168.10.101  master02+haproxy+keepalived
        192.168.10.102  master03+haproxy+keepalived
        192.168.10.104  keepalived VIP
        192.168.10.105  node01
        192.168.10.160  node02



