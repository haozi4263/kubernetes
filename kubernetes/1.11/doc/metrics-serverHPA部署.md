# metrics-server HPA

    从 Kubernetes 1.8 开始，资源使用指标（如容器 CPU 和内存使用率）通过 Metrics API 在 Kubernetes 中获取, metrics-server 替代了heapster 
    
    Metrics Server 实现了Resource Metrics API
    
    Metrics Server 是集群范围资源使用数据的聚合器。 
    Metrics Server 从每个节点上的 Kubelet 公开的 Summary API 中采集指标信息。
    
    通过在主 API server 中注册的 Metrics Server Kubernetes 聚合器 来采集指标信息

 
### 要求
    1.8 以上版本
    
    将kube-controller-manager的启动参数中--horizontal-pod-autoscaler-use-rest-clients设置为true
    
    修改kube-apiserver的配置文件apiserver，增加一条配置：
     --requestheader-client-ca-file=/opt/kubernetes/ssl/front-proxy-ca.pem
     --requestheader-allowed-names=aggregator --requestheader-extra-headers-prefix=X-Remote-Extra-
     --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User
     --proxy-client-cert-file=/opt/kubernetes/ssl/front-proxy-client.pem
     --proxy-client-key-file=/opt/kubernetes/ssl/front-proxy-client-key.pem，
     用来配置aggregator的CA证书
  
 

 



## 1. 创建证书

    生成front-proxy-ca-csr.json文件，并生成 Front proxy CA 密钥，Front proxy 主要是用在 API aggregator 上:
    生成front-proxy-ca-csr.json文件
    
    复制代码
    cd /etc/kubernetes/ssl/
    
    cat <<EOF > front-proxy-ca-csr.json
    {
        "CN": "kubernetes",
        "key": {
            "algo": "rsa",
            "size": 2048
        }
    }
    EOF

 

    生成 Front proxy CA 密钥
    
    cfssl gencert \
      -initca front-proxy-ca-csr.json | cfssljson -bare front-proxy-ca
     
    
    生成front-proxy-client-csr.json文件，并生成 front-proxy-client 证书
    生成front-proxy-client-csr.json文件
    
    
    cat <<EOF > front-proxy-client-csr.json
    {
        "CN": "front-proxy-client",
        "key": {
            "algo": "rsa",
            "size": 2048
        }
    }
    EOF
    复制代码
    生成 front-proxy-client 证书
    
    复制代码
    cfssl gencert \
      -ca=front-proxy-ca.pem \
      -ca-key=front-proxy-ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
      front-proxy-client-csr.json | cfssljson -bare front-proxy-client
    复制代码
     
    
    将证书copy多有node 节点的 /etc/kubernetes/ssl/目录下, 权限755
    
    scp /etc/kubernetes/ssl/*   node1:/etc/kubernetes/ssl 
 

## 2.下载mestrics-server yaml文件

    git clone https://github.com/stefanprodan/k8s-prom-hpa
    或者
    git clone https://github.com/kubernetes-incubator/metrics-server.git
     
    
    修改metrics-server-deployment.yaml,  添加证书--requestheader-client-ca-file
    
        spec:
          serviceAccountName: metrics-server
          containers:
          - name: metrics-server
            image: gcr.io/google_containers/metrics-server-amd64:v0.2.1
            imagePullPolicy: Always
            volumeMounts:
            - mountPath: /etc/kubernetes/ssl
              name: ca-ssl
            command:
            - /metrics-server
            - --source=kubernetes.summary_api:''
            - --requestheader-client-ca-file=/etc/kubernetes/ssl/front-proxy-ca.pem
          volumes:
          - name: ca-ssl
            hostPath:
              path: /etc/kubernetes/ssl
    
     

 

 

## 3. 修改kube-apiserver配置文件


    cat /lib/systemd/system/kube-apiserver.service 
    [Unit]
    Description=Kubernetes API Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target
    
    [Service]
    ExecStart=/opt/kubernetes/bin/kube-apiserver \
      --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota,NodeRestriction \
      --bind-address=192.168.10.100 \
      --insecure-bind-address=127.0.0.1 \
      --authorization-mode=Node,RBAC \
      --runtime-config=rbac.authorization.k8s.io/v1 \
      --requestheader-client-ca-file=/opt/kubernetes/ssl/front-proxy-ca.pem \
      --requestheader-allowed-names=aggregator \
      --requestheader-extra-headers-prefix=X-Remote-Extra- \
      --requestheader-group-headers=X-Remote-Group \
      --requestheader-username-headers=X-Remote-User \
      --proxy-client-cert-file=/opt/kubernetes/ssl/front-proxy-client.pem \
      --proxy-client-key-file=/opt/kubernetes/ssl/front-proxy-client-key.pem \
      --enable-aggregator-routing=true \
      --kubelet-https=true \
      --anonymous-auth=false \
      --basic-auth-file=/opt/kubernetes/ssl/basic-auth.csv \
      --enable-bootstrap-token-auth \
      --token-auth-file=/opt/kubernetes/ssl/bootstrap-token.csv \
      --service-cluster-ip-range=10.1.0.0/16 \
      --service-node-port-range=20000-40000 \
      --tls-cert-file=/opt/kubernetes/ssl/kubernetes-master.pem \
      --tls-private-key-file=/opt/kubernetes/ssl/kubernetes-master-key.pem \
      --client-ca-file=/opt/kubernetes/ssl/ca.pem \
      --service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \
      --etcd-cafile=/opt/kubernetes/ssl/ca.pem \
      --etcd-certfile=/opt/kubernetes/ssl/etcd.pem \
      --etcd-keyfile=/opt/kubernetes/ssl/etcd-key.pem \
      --etcd-servers=https://192.168.10.100:2379,https://192.168.10.101:2379,https://192.168.10.102:2379 \
      --enable-swagger-ui=true \
      --allow-privileged=true \
      --audit-log-maxage=30 \
      --audit-log-maxbackup=3 \
      --audit-log-maxsize=100 \
      --audit-log-path=/opt/kubernetes/log/api-audit.log \
      --event-ttl=1h \
      --v=2 \
      --logtostderr=false \
      --log-dir=/opt/kubernetes/log
    Restart=on-failure
    RestartSec=5
    Type=notify
    LimitNOFILE=65536
    
    [Install]
    WantedBy=multi-user.target
 
## 4.kube-controller-manager 配置文件



    cat /lib/systemd/system/kube-controller-manager.service 
    [Unit]
    Description=Kubernetes Controller Manager
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    
    [Service]
    ExecStart=/opt/kubernetes/bin/kube-controller-manager \
      --address=127.0.0.1 \
      --horizontal-pod-autoscaler-use-rest-clients=true \
      --master=http://127.0.0.1:8080 \
      --allocate-node-cidrs=true \
      --service-cluster-ip-range=10.1.0.0/16 \
      --cluster-cidr=10.2.0.0/16 \
      --cluster-name=kubernetes \
      --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \
      --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \
      --service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \
      --root-ca-file=/opt/kubernetes/ssl/ca.pem \
      --leader-elect=true \
      --v=2 \
      --logtostderr=false \
      --log-dir=/opt/kubernetes/log
    
    Restart=on-failure
    RestartSec=5
    
    [Install]
    WantedBy=multi-user.target
 
## 5. 安装 Metrics Server

    Kubernetes Metrics Server是一个集群范围的资源使用数据聚合器，是Heapster的继承者。 
    metrics服务器通过从kubernet.summary_api收集数据收集节点和pod的CPU和内存使用情况。 
    summary API是一个内存有效的API，用于将数据从Kubelet/cAdvisor传递到metrics server

    kubectl create -f ./metrics-server
 

    查看 v1beta1.metrics.k8s.io    api是否生成

    kubectl get apiservice|grep v1beta1.metrics.k8s.io
    v1beta1.metrics.k8s.io                 2018-08-21T01:47:20Z




    查看 v1beta1.metrics.k8s.io 详细信息
    
    
    kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
    apiVersion: apiregistration.k8s.io/v1
    kind: APIService
    metadata:
      annotations:
        kubectl.kubernetes.io/last-applied-configuration: |
          {"apiVersion":"apiregistration.k8s.io/v1beta1","kind":"APIService","metadata":{"annotations":{},"name":"v1beta1.metrics.k8s.io","namespace":""},"spec":{"group":"metrics.k8s.io","groupPriorityMinimum":100,"insecureSkipTLSVerify":true,"service":{"name":"metrics-server","namespace":"kube-system"},"version":"v1beta1","versionPriority":100}}
      creationTimestamp: 2018-08-21T01:47:20Z
      deletionGracePeriodSeconds: 0
      deletionTimestamp: 2018-08-21T04:27:03Z
      finalizers:
      - foregroundDeletion
      name: v1beta1.metrics.k8s.io
      resourceVersion: "2145603"
      selfLink: /apis/apiregistration.k8s.io/v1/apiservices/v1beta1.metrics.k8s.io
      uid: 24a87389-a4e4-11e8-86c8-000c299415fb
    spec:
      group: metrics.k8s.io
      groupPriorityMinimum: 100
      insecureSkipTLSVerify: true
      service:
        name: metrics-server
        namespace: kube-system
      version: v1beta1
      versionPriority: 100
    status:
      conditions:
      - lastTransitionTime: 2018-08-22T06:44:37Z
        message: all checks passed
        reason: Passed
        status: "True"
        type: Available


 


## 6.查看 nodes 指标， jq是json格式
     安装jq  yum -y install jq
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .
 

 

    基于CPU和内存使用的自动缩放
     
    
    kubectl create -f ./podinfo/podinfo-svc.yaml,./podinfo/podinfo-dep.yaml
     
    
    接下来定义一个HPA，保持最小两个副本和最大十个如果CPU平均超过80%或如果内存超过200mi

 


    apiVersion: autoscaling/v2beta1
    kind: HorizontalPodAutoscaler
    metadata:
      name: podinfo
    spec:
      scaleTargetRef:
        apiVersion: extensions/v1beta1
        kind: Deployment
        name: podinfo
      minReplicas: 2
      maxReplicas: 10
      metrics:
      - type: Resource
        resource:
          name: cpu
          targetAverageUtilization: 80
      - type: Resource
        resource:
          name: memory
          targetAverageValue: 200Mi

 

    创建HPA
    
    kubectl create -f ./podinfo/podinfo-hpa.yaml
     
    
    查看hpa
    
    kubectl get hpa
    NAME      REFERENCE            TARGETS                     MINPODS   MAXPODS   REPLICAS   AGE
    podinfo   Deployment/podinfo   5087232 / 200Mi, 0% / 10%   1         5         1          1h
     

 

 

 

    参考：
    
    https://blog.csdn.net/yevvzi/article/details/79561150
    
    https://www.ctolib.com/docs/sfile/kubernetes-handbook/concepts/custom-metrics-hpa.html

    https://www.cnblogs.com/fengjian2016/p/8819657.html
