使用全手工方式安装最新版kubernetes1.11

    高可用安装3个master节点，使用使用lvs做负载均衡提升性能。

    master部署3节点，apiserver使用keepalived+haproxy实现高可用。

        192.168.10.100  master01+haproxy+keepalived
        192.168.10.101  master02+haproxy+keepalived
        192.168.10.102  master03+haproxy+keepalived
        192.168.10.104  keepalived VIP
        192.168.10.105  node01
        192.168.10.160  node02


    安装部署：
        <a hrep="https://github.com/haozi4263/kubernetes/blob/master/kubernetes/1.11/doc/%E7%B3%BB%E7%BB%9F%E5%88%9D%E5%A7%8B%E5%8C%96.md">1.系统初始化</a>
        2.CA证书制作
        3.ETCD集群部署
        4.Master节点部署
        5.keepalive+haproxyHA部署
        6.Node节点部署
        7.flannel网络部署