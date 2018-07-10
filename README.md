## 使用全手工方式安装最新版kubernetes1.11

    高可用安装3个master节点，使用使用lvs做负载均衡提升性能。

    master部署3节点，apiserver使用keepalived+haproxy实现高可用。

        192.168.10.100  master01+haproxy+keepalived
        192.168.10.101  master02+haproxy+keepalived
        192.168.10.102  master03+haproxy+keepalived
        192.168.10.104  keepalived VIP
        192.168.10.105  node01
        192.168.10.160  node02


 #安装部署：


<table border="0">
    <tr>
            <td><strong>手动部署</strong></td>
            <td><a href="kubernetes/1.11/doc/系统初始化.md">1.系统初始化</a></td>
            <td><a href="kubernetes/1.11/doc/CA证书制作.md">2.CA证书制作</a></td>
            <td><a href="kubernetes/1.11/doc/ETCD集群部署.md">3.ETCD集群部署</a></td>
            <td><a href="kubernetes/1.11/doc/Master节点部署.md">4.Master节点部署</a></td>
            <td><a href="kubernetes/1.11/doc/Node节点部署.md">5.Node节点部署</a></td>
            <td><a href="kubernetes/1.11/doc/flannel部署.md">6.Flannel部署</a></td>
            <td><a href="doc/app.md">7.应用创建</a></td>
    </tr>
    <tr>
            <td><strong>必备插件</strong></td>
            <td><a href="doc/CoreDNS.md">1.CoreDNS部署</a></td>
            <td><a href="doc/dashboard.md">2.Dashboard部署</a></td>
            <td><a href="doc/heapster.md">3.Heapster部署</a></td>
    </tr>
</table>



# 手动部署
- [系统初始化](kubernetes/1.11/doc/系统初始化.md)
- [CA证书制作](kubernetes/1.11/doc/CA证书制作.md)
- [ETCD集群部署](kubernetes/1.11/doc/ETCD集群部署.md)
- [Master节点部署](kubernetes/1.11/doc/Master节点部署.md)
- [Node节点部署](kubernetes/1.11/doc/Node节点部署.md)
- [Flannel网络部署](kubernetes/1.11/doc/flannel部署.md)
- [创建第一个K8S应用](kubernetes/1.11/doc/app.md)
- [CoreDNS和Dashboard部署](kubernetes/1.11/doc/CoreDNS.md)
