0.使用 Kube-router 作为 Kubernetes 负载均衡器

     Kube-router 是一个挺有想法的项目，兼备了 calico 和 kube-proxy 的功能，是基于 Kubernetes 网络设计的一个集负载均衡器、
     防火墙和容器网络的综合方案。
     
1.体系架构

    Kube-router是围绕观察者和控制器的概念而建立的。
    
    观察者: 使用 Kubernetes watch API 来获取与创建，更新和删除 Kubernetes 对象有关的事件的通知。 每个观察者获取与特定 API 对象相关的通知。
    在从API服务器接收事件时，观察者广播事件。
    
    控制器: 注册以获取观察者的事件更新，并处理事件。
    
    
    
       
2.主要功能

    基于 IPVS/LVS 的负载均衡器 | --run-service-proxy
    Kube-router 采用 Linux 内核的 IPVS 模块为 K8s 提供 Service 的代理。
    
    Kube-router 的负载均衡器功能，会在物理机上创建一个虚拟的 kube-dummy-if 网卡，然后利用 k8s 的 watch APi 实时更新 svc 和 ep 的信息。
    svc 的 cluster_ip 会绑定在 kube-dummy-if 网卡上，作为 lvs 的 virtual server 的地址。realserver 的 ip 则通过 ep 获取到容器的IP地址。
    基于 Kubernetes 网络服务代理的 Kube-router IPVS 演示: https://asciinema.org/a/120312
    
    
    
    特征：
    
    轮询负载均衡
    基于客户端IP的会话保持
    如果服务控制器与网络路由控制器（带有 –-run-router 标志的 kube-router）一起使用，源IP将被保留
    用 –-masquerade-all 参数明确标记伪装(SNAT)
    更多详情可以参考：
    
    Kubernetes network services prox with IPVS/LVS:https://link.jianshu.com/?t=https://cloudnativelabs.github.io/post/2017-05-10-kube-network-service-proxy/
    Kernel Load-Balancing for Docker Containers Using IPVS:https://link.jianshu.com/?t=https://blog.codeship.com/kernel-load-balancing-for-docker-containers-using-ipvs/
    LVS负载均衡之持久性连接介绍:https://www.yangcs.net/posts/lvs-persistent-connection/
    
    
    容器网络 | --run-router
    Kube-router 利用 BGP 协议和 Go 的 GoBGP 库和为容器网络提供直连的方案。因为用了原生的 Kubernetes API 去构建容器网络，意味着在使用 kube-router 时，不需要在你的集群里面引入其他依赖。
    
    同样的，kube-router 在引入容器 CNI 时也没有其它的依赖，官方的 bridge 插件就能满足 kube-rouetr 的需求。
    
    更多关于 BGP 协议在 Kubernetes 中的使用可以参考：
    
    Kubernetes pod networking and beyond with BGP:https://link.jianshu.com/?t=https://cloudnativelabs.github.io/post/2017-05-22-kube-pod-networking/

    网络策略管理 | --run-firewall
    网络策略控制器负责从 Kubernetes API 服务器读取命名空间、网络策略和 pod 信息，并相应地使用 ipset 配置 iptables 以向 pod 提供入口过滤，保证防火墙的规则对系统性能有较低的影响。
    
    Kube-router 支持 networking.k8s.io/NetworkPolicy 接口或网络策略 V1/GA semantics 以及网络策略的 beta 语义。
    
    更多关于 kube-router 防火墙的功能可以参考：https://link.jianshu.com/?t=https://cloudnativelabs.github.io/post/2017-05-1-kube-network-policies/
3.使用 kube-router 替代 kube-proxy

    前提:
    已有一个 k8s 集群
    kube-router 能够连接 apiserver
    如果您选择以 daemonset 运行 kube-router，那么 kube-apiserver 和 kubelet 必须以 –allow-privileged=true 选项运行
    controller-manager 需要添加一个参数：
    –allocate-node-cidrs=true
    
    安装步骤
    如果你正在使用 kube-proxy，需要先停止 kube-proxy 服务，并且删除相关 iptables 规则。
    
    $ systemctl stop kube-proxy
    $ kube-proxy --cleanup-iptables 清理iptables规则
   
4. kubelet配置

    [root@master02 net.d]# vim /lib/systemd/system/kubelet.service 
    
    [Unit]
    Description=Kubernetes Kubelet
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=docker.service
    Requires=docker.service
    
    [Service]
    WorkingDirectory=/var/lib/kubelet
    ExecStart=/opt/kubernetes/bin/kubelet \
      --address=192.168.10.101 \
      --hostname-override=192.168.10.101 \
      --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/acs/pause-amd64:3.0 \
      --experimental-bootstrap-kubeconfig=/opt/kubernetes/cfg/bootstrap.kubeconfig \
      --kubeconfig=/opt/kubernetes/cfg/kubelet.kubeconfig \
      --cert-dir=/opt/kubernetes/ssl \
      --network-plugin=cni \
      --cni-conf-dir=/etc/cni/net.d \
      --cni-bin-dir=/opt/cni/bin \  --使用标准cni网络接口
      --cluster-dns=10.1.0.2 \
      --cluster-domain=cluster.local. \
      --hairpin-mode hairpin-veth \
      --allow-privileged=true \
      --fail-swap-on=false \
      --logtostderr=true \
      --v=2 \
      --logtostderr=false \
      --log-dir=/opt/kubernetes/log
  
    Restart=on-failure
    RestartSec=5
    
    [Install]
    WantedBy=multi-user.target

###注意：如过之前配置了使用了flannel网络方案，需清空/etc/cni/net.d目录下所有文件
        使用kube-router 代理kube-proxy,不再使用calico,而使用kube-router做网络bgp

 5.部署kube-router
 
    wget https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/generic-kuberouter-all-features.yaml
    # 启用pod网络通信，网络隔离策略，服务代理所有功能
    # CLUSTERCIDR kube-controller-manager 启动参数 --cluster-cidr 的值
    # APISERVER kube-apiserver 启动参数 --advertise-address 值
    CLUSTERCIDR='10.244.0.0/16'
    APISERVER='https://192.168.10.104:8443'
    sed -i "s;%APISERVER%;$APISERVER;g" generic-kuberouter-all-features.yaml
    sed -i "s;%CLUSTERCIDR%;$CLUSTERCIDR;g" generic-kuberouter-all-features.yaml
    kubectl apply -f generic-kuberouter-all-features.yam
    
    验证：
        kubectl get pod -o wide -n kube-system
        NAME                        READY     STATUS    RESTARTS   AGE       IP               NODE
        coredns1-6d94b66654-jp4b4   1/1       Running   138        10h       192.168.10.101   192.168.10.101
        kube-router-7qqg5           1/1       Running   0          11h       192.168.10.100   192.168.10.100
        kube-router-csr2p           1/1       Running   0          11h       192.168.10.102   192.168.10.102
        kube-router-cwpwl           1/1       Running   0          11h       192.168.10.101   192.168.10.101
        kube-router-hjdsm           1/1       Running   0          11h       192.168.10.106   192.168.10.106
        kube-router-p4cmp           1/1       Running   0          11h       192.168.10.105   192.168.10.105
        
        ip route（每台主机路由，对应到/etc/cni/net.d/10-kuberouter.conf自动生成的路由信息）
        default via 192.168.10.2 dev ens32  proto static  metric 100 
        10.2.0.0/24 via 192.168.10.100 dev ens32  proto 17 
        10.2.1.0/24 via 192.168.10.106 dev ens32  proto 17 
        10.2.2.0/24 via 192.168.10.105 dev ens32  proto 17 
        10.2.3.0/24 dev kube-bridge  proto kernel  scope link  src 10.2.3.1 
        10.2.4.0/24 via 192.168.10.102 dev ens32  proto 17 
        172.17.0.0/16 dev docker0  proto kernel  scope link  src 172.17.0.1 
        192.168.10.0/24 dev ens32  proto kernel  scope link  src 192.168.10.101  metric 100 
        
        在每台机器上查看 lvs 条目
        ipvsadm -L -n
        IP Virtual Server version 1.2.1 (size=4096)
        Prot LocalAddress:Port Scheduler Flags
          -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
        TCP  192.168.10.101:39610 rr
          -> 10.2.0.10:8080               Masq    1      0          0         
          -> 10.2.2.10:8080               Masq    1      0          0         
          -> 10.2.2.11:8080               Masq    1      0          0         
          -> 10.2.3.5:8080                Masq    1      0          0         
          -> 10.2.4.8:8080                Masq    1      0          0         
        TCP  10.1.0.1:443 rr
          -> 192.168.10.100:6443          Masq    1      0          0         
          -> 192.168.10.101:6443          Masq    1      0          0         
          -> 192.168.10.102:6443          Masq    1      0          0         
        TCP  10.1.36.171:8080 rr
          -> 10.2.0.10:8080               Masq    1      0          0         
          -> 10.2.2.10:8080               Masq    1      0          0         
          -> 10.2.2.11:8080               Masq    1      0          0         
          -> 10.2.3.5:8080                Masq    1      0          0         
          -> 10.2.4.8:8080                Masq    1      0          0    

        在kube-route容器中查看bgp邻居：
        gobgp neighbor
        Peer              AS  Up/Down State       |#Received  Accepted
        192.168.10.100 64512 10:51:55 Establ      |        1         1
        192.168.10.101 64512 10:51:56 Establ      |        1         1
        192.168.10.102 64512 10:51:58 Establ      |        1         1
        192.168.10.105 64512 10:50:39 Establ      |        1         1

   
         
 6.创建应用测试kube-router
 
    kubectl run myip --image=cloudnativelabs/whats-my-ip --replicas=5       启动5个pod
    kubectl expose deploy myip --target-port=8080 --port=8080 --name=myip   暴露服务
    
    kubectl get pod -o wide
    NAME                   READY     STATUS    RESTARTS   AGE       IP          NODE
    myip-bbd9f55d8-7wrcw   1/1       Running   0          10h       10.2.2.10   192.168.10.105
    myip-bbd9f55d8-nj9cs   1/1       Running   0          10h       10.2.0.10   192.168.10.100
    myip-bbd9f55d8-sl5k7   1/1       Running   0          10h       10.2.3.5    192.168.10.101
    myip-bbd9f55d8-trltf   1/1       Running   0          10h       10.2.4.8    192.168.10.102
    myip-bbd9f55d8-v6l2g   1/1       Running   0          10h       10.2.2.11   192.168.10.105
    
    kubectl get svc -o wide
    NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE       SELECTOR
    kubernetes   ClusterIP   10.1.0.1      <none>        443/TCP          71d       <none>
    myip         ClusterIP    10.1.36.171   <none>        8080/TCP    12h       run=myip
    
    curl 10.1.36.171:8080（随便在那个集群宿主机上执行，验证svc网络打通）
    HOSTNAME:myip-bbd9f55d8-nj9cs IP:10.2.0.10
    curl 10.1.36.171:8080
    HOSTNAME:myip-bbd9f55d8-trltf IP:10.2.4.8
    curl 10.1.36.171:8080
    HOSTNAME:myip-bbd9f55d8-v6l2g IP:10.2.2.11
    curl 10.1.36.171:8080
    HOSTNAME:myip-bbd9f55d8-7wrcw IP:10.2.2.10
    curl 10.1.36.171:8080
    HOSTNAME:myip-bbd9f55d8-sl5k7 IP:10.2.3.5

    查看 lvs 规则条目：
    ipvsadm -L -n
    IP Virtual Server version 1.2.1 (size=4096)
    Prot LocalAddress:Port Scheduler Flags
      -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
    TCP  192.168.10.106:39610 rr
      -> 10.2.0.10:8080               Masq    1      0          0         
      -> 10.2.2.10:8080               Masq    1      0          0         
      -> 10.2.2.11:8080               Masq    1      0          0         
      -> 10.2.3.5:8080                Masq    1      0          0         
      -> 10.2.4.8:8080                Masq    1      0          0         
    TCP  10.1.0.1:443 rr
      -> 192.168.10.100:6443          Masq    1      0          0         
      -> 192.168.10.101:6443          Masq    1      0          0         
      -> 192.168.10.102:6443          Masq    1      0          0         
    TCP  10.1.36.171:8080 rr
      -> 10.2.0.10:8080               Masq    1      0          1         
      -> 10.2.2.10:8080               Masq    1      0          0         
      -> 10.2.2.11:8080               Masq    1      0          0         
      -> 10.2.3.5:8080                Masq    1      0          0         
      -> 10.2.4.8:8080                Masq    1      0          0         
    可以发现本机的 Cluster IP 代理后端真实 Pod IP，使用 rr 算法。
    
    通过 ip a 可以看到，每添加一个服务，node 节点上面的 kube-dummy-if 网卡就会增加一个虚IP。
    session affinity
    Service 默认的策略是，通过 round-robin 算法来选择 backend Pod。 要实现基于客户端 IP 的会话亲和性，
    可以通过设置 service.spec.sessionAffinity 的值为 ClientIP （默认值为 “None”）。
    kubectl delete svc myip
    kubectl expose deploy myip --target-port=8080 --port=8080 --session-affinity=ClientIP
    
    
    ipvsadm -L -n
    IP Virtual Server version 1.2.1 (size=4096)
    Prot LocalAddress:Port Scheduler Flags
      -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
    TCP  10.1.0.1:443 rr
      -> 192.168.10.100:6443          Masq    1      0          0         
      -> 192.168.10.101:6443          Masq    1      0          0         
      -> 192.168.10.102:6443          Masq    1      0          0         
    TCP  10.1.21.161:8080 rr persistent 10800
      -> 10.2.0.10:8080               Masq    1      0          0         
      -> 10.2.2.10:8080               Masq    1      0          0         
      -> 10.2.2.11:8080               Masq    1      0          0         
      -> 10.2.3.5:8080                Masq    1      0          0       
      
      ipvsadm -S -n
      -A -t 10.1.0.1:443 -s rr
      -a -t 10.1.0.1:443 -r 192.168.10.100:6443 -m -w 1
      -a -t 10.1.0.1:443 -r 192.168.10.101:6443 -m -w 1
      -a -t 10.1.0.1:443 -r 192.168.10.102:6443 -m -w 1
      -A -t 10.1.21.161:8080 -s rr -p 10800
      -a -t 10.1.21.161:8080 -r 10.2.0.10:8080 -m -w 1
      -a -t 10.1.21.161:8080 -r 10.2.2.10:8080 -m -w 1
      -a -t 10.1.21.161:8080 -r 10.2.2.11:8080 -m -w 1
      -a -t 10.1.21.161:8080 -r 10.2.3.5:8080 -m -w 1
      -a -t 10.1.21.161:8080 -r 10.2.4.8:8080 -m -w 1
      
      
      可以看到 lvs 的规则条目里多了个 persistent，即 lvs 的持久连接
      
      可以通过设置 service.spec.sessionAffinityConfig.clientIP.timeoutSeconds 的值来修改 lvs 的 persistence_timeout 超时时间。
      kubectl get svc myip -o yaml|grep timeoutSeconds
            timeoutSeconds: 10800
            
     更改算法
     最少连接数
     $ kubectl annotate service my-service "kube-router.io/service.scheduler=lc"
     轮询
     $ kubectl annotate service my-service "kube-router.io/service.scheduler=rr"
     源地址哈希
     $ kubectl annotate service my-service "kube-router.io/service.scheduler=sh"
     目的地址哈希
     $ kubectl annotate service my-service "kube-router.io/service.scheduler=dh"       
        
    参考：https://juejin.im/post/5b658f82f265da0fa644c6c9
         https://juejin.im/post/5b658f82f265da0fa644c6c9
         https://www.kubernetes.org.cn/4257.html
         http://blog.51cto.com/net592/2059315
         https://asciinema.org/a/120312