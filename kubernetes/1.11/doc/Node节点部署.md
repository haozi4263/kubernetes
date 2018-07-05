
1.二进制包准备 将软件包从master02拷贝到node01/02上

     cd /usr/local/src/kubernetes/server/bin/
     cp kubelet kube-proxy /opt/kubernetes/bin/
     scp kubelet kube-proxy 192.168.10.105:/opt/kubernetes/bin/
     scp kubelet kube-proxy 192.168.10.106:/opt/kubernetes/bin/
2.创建角色绑定

    kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
  
3.创建 kubelet bootstrapping kubeconfig 文件 设置集群参数

     kubectl config set-cluster kubernetes \
       --certificate-authority=/opt/kubernetes/ssl/ca.pem \
       --embed-certs=true \
       --server=https://192.168.10.104:8443 \
       --kubeconfig=bootstrap.kubeconfig
   
设置客户端认证参数

     kubectl config set-credentials kubelet-bootstrap \
       --token=ad6d5bb607a186796d8861557df0d17f \
       --kubeconfig=bootstrap.kubeconfig

设置上下文参数

     kubectl config set-context default \
       --cluster=kubernetes \
       --user=kubelet-bootstrap \
       --kubeconfig=bootstrap.kubeconfig
  
选择默认上下文

     kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
    
     cp bootstrap.kubeconfig /opt/kubernetes/cfg
     scp bootstrap.kubeconfig 192.168.10.105:/opt/kubernetes/cfg
     scp bootstrap.kubeconfig 192.168.10.106:/opt/kubernetes/cfg

部署kubelet：

    1.设置CNI支持
     mkdir -p /etc/cni/net.d
     vim /etc/cni/net.d/10-default.conf
    {
            "name": "flannel",
            "type": "flannel",
            "delegate": {
                "bridge": "docker0",
                "isDefaultGateway": true,
                "mtu": 1400
            }
    }


2.创建kubelet目录
    mkdir /var/lib/kubelet
3.创建kubelet服务配置

    vim /usr/lib/systemd/system/kubelet.service
    [Unit]
    Description=Kubernetes Kubelet
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=docker.service
    Requires=docker.service
    
    [Service]
    WorkingDirectory=/var/lib/kubelet
    ExecStart=/opt/kubernetes/bin/kubelet \
      --address=192.168.10.105 \
      --hostname-override=192.168.10.105 \
      --pod-infra-container-image=mirrorgooglecontainers/pause-amd64:3.0 \
      --experimental-bootstrap-kubeconfig=/opt/kubernetes/cfg/bootstrap.kubeconfig \
      --kubeconfig=/opt/kubernetes/cfg/kubelet.kubeconfig \
      --cert-dir=/opt/kubernetes/ssl \
      --network-plugin=cni \
      --cni-conf-dir=/etc/cni/net.d \
      --cni-bin-dir=/opt/kubernetes/bin/cni \
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
4.启动Kubelet

     systemctl daemon-reload
     systemctl enable kubelet
     systemctl start kubelet
5.查看服务状态

    systemctl status kubelet
6.查看csr请求 注意是在master节点上执行。

    kubectl get csr
    NAME                                                   AGE       REQUESTOR           CONDITION
    node-csr-0_w5F1FM_la_SeGiu3Y5xELRpYUjjT2icIFk9gO9KOU   1m        kubelet-bootstrap   Pending
7.批准kubelet 的 TLS 证书请求

    kubectl get csr|grep 'Pending' | awk 'NR>0{print $1}'| xargs kubectl certificate approve
    执行完毕后，查看节点状态已经是Ready的状态了  kubectl get node NAME STATUS ROLES AGE VERSION

部署Kubernetes Proxy

    1.配置kube-proxy使用LVS
    
     yum install -y ipvsadm ipset conntrack
2.创建 kube-proxy 证书请求
    
     cd /usr/local/src/ssl/
     vim kube-proxy-csr.json
    {
      "CN": "system:kube-proxy",
      "hosts": [],
      "key": {
        "algo": "rsa",
        "size": 2048
      },
      "names": [
        {
          "C": "CN",
          "ST": "BeiJing",
          "L": "BeiJing",
          "O": "k8s",
          "OU": "System"
        }
      ]
    }
3.生成证书
    
     cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
       -ca-key=/opt/kubernetes/ssl/ca-key.pem \
       -config=/opt/kubernetes/ssl/ca-config.json \
       -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
4.分发证书到所有Node节点
    
     cp kube-proxy*.pem /opt/kubernetes/ssl/
     scp kube-proxy*.pem 192.168.10.105:/opt/kubernetes/ssl/
     scp kube-proxy*.pem 192.168.10.105:/opt/kubernetes/ssl/
5.创建kube-proxy配置文件
    
     kubectl config set-cluster kubernetes \
       --certificate-authority=/opt/kubernetes/ssl/ca.pem \
       --embed-certs=true \
       --server=https://192.168.10.104:8443 \
       --kubeconfig=kube-proxy.kubeconfig

    
     kubectl config set-credentials kube-proxy \
       --client-certificate=/opt/kubernetes/ssl/kube-proxy.pem \
       --client-key=/opt/kubernetes/ssl/kube-proxy-key.pem \
       --embed-certs=true \
       --kubeconfig=kube-proxy.kubeconfig
    
    
     kubectl config set-context default \
       --cluster=kubernetes \
       --user=kube-proxy \
       --kubeconfig=kube-proxy.kubeconfig
    
    
     kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
   
6.分发kubeconfig配置文件
    
     cp kube-proxy.kubeconfig /opt/kubernetes/cfg/
     scp kube-proxy.kubeconfig 192.168.10.105:/opt/kubernetes/cfg/
     scp kube-proxy.kubeconfig 192.168.10.106:/opt/kubernetes/cfg/
7.创建kube-proxy服务配置
    
     mkdir /var/lib/kube-proxy
    
     vim /usr/lib/systemd/system/kube-proxy.service
    [Unit]
    Description=Kubernetes Kube-Proxy Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target
    
    [Service]
    WorkingDirectory=/var/lib/kube-proxy
    ExecStart=/opt/kubernetes/bin/kube-proxy \
      --bind-address=192.168.10.105 \
      --hostname-override=192.168.10.105 \
      --kubeconfig=/opt/kubernetes/cfg/kube-proxy.kubeconfig \
    --masquerade-all \
      --feature-gates=SupportIPVSProxyMode=true \
      --proxy-mode=ipvs \
      --ipvs-min-sync-period=5s \
      --ipvs-sync-period=5s \
      --ipvs-scheduler=rr \
      --logtostderr=true \
      --v=2 \
      --logtostderr=false \
      --log-dir=/opt/kubernetes/log
    
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536
    
    [Install]
    WantedBy=multi-user.target
 8.启动Kubernetes Proxy，另外node节点一样配置。
     systemctl daemon-reload
     systemctl enable kube-proxy
     systemctl start kube-proxy
9.查看服务状态 查看kube-proxy服务状态
    
     systemctl status kube-proxy
    
10.检查LVS状态
    ipvsadm -L -n
    IP Virtual Server version 1.2.1 (size=4096)
    Prot LocalAddress:Port Scheduler Flags
      -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
    TCP  10.1.0.1:443 rr persistent 10800
      -> 192.168.10.100:6443           Masq    1      0          0
    如果你在两台实验机器都安装了kubelet和proxy服务，使用下面的命令可以检查状态：
    
    kubectl get node
    NAME            STATUS    ROLES     AGE       VERSION
    192.168.10.105   Ready     <none>    22m       v1.11.0
    192.168.10.106   Ready     <none>    3m        v1.11.0