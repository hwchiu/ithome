[Day11] Kubernetes - Container Network Interface (CNI)
======================================================

> 本文同步刊登於 [hwchiu.com - Kubernetes & Container Network Interface](https://www.hwchiu.com/kubernetes-cni.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論


# 前言

前篇文章探討了 `CNI` 的基本概念，包含了
- CNI 呼叫的範例
- 設定檔案的格式
- 執行流程
- Sanbox Container

接下來本篇文章要著重在如何把上述概念跟 Kubernetes 融會貫通，來瞭解到底 kubernete 是如何透過 CNI 讓每個 Pod 都有網路可以使用的。

# Kubernetes
## Vagrant
這邊先跟大家分享一下自己平常使用的 `Vagrant` 腳本，我習慣在 MAC 上面透過 Vagrant 的方式去創建一個單機的 Kubernetes Cluster 來進行測試，主要是快速且方便，且該腳本中還會透過 kubeadm 的方式自動建立 kubernetes cluster ，安裝 Flannel CNI 以及透過 taint 的方式允與 master node 運行 Pod。


```ruby=
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-18.04"
  config.vm.hostname = 'k8s-dev'
  config.vm.define vm_name = 'k8s'

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e -x -u
    export DEBIAN_FRONTEND=noninteractive

    #change the source.list
    sudo apt-get update
    sudo apt-get install -y vim git cmake build-essential tcpdump tig jq
    # Install ntp
    sudo apt-get install -y ntp
    # Install Docker
    # kubernetes official max validated version: 17.03.2~ce-0~ubuntu-xenial
    export DOCKER_VERSION="18.06.3~ce~3-0~ubuntu"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce=${DOCKER_VERSION}

    # Install Kubernetes
    export KUBE_VERSION="1.13.5"
    export NET_IF_NAME="enp0s8"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubeadm=${KUBE_VERSION}-00 kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubernetes-cni=0.7.5-00
    # Disable swap
    sudo swapoff -a && sudo sysctl -w vm.swappiness=0
    sudo sed '/swap.img/d' -i /etc/fstab
    sudo kubeadm init --kubernetes-version v${KUBE_VERSION} --apiserver-advertise-address=172.17.8.101 --pod-network-cidr=10.244.0.0/16
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
    kubectl taint nodes --all node-role.kubernetes.io/master-


  SHELL

  config.vm.network :private_network, ip: "172.17.8.101"
  config.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--cpus", 2]
      v.customize ["modifyvm", :id, "--memory", 4096]
      v.customize ['modifyvm', :id, '--nicpromisc1', 'allow-all']
  end
end
```
接下來我的操作環境都會基於這個範例去操作，唯一要注意的就是如果要修改 kubernetes 版本的話，要注意 flannel 的 yaml 是否支援當前版本。 譬如 kubernetes 1.16  中 daemonset 就類型就要修改成 apps/v1。

## kubelet

kubernetes 目前在網路方面提供兩者設定，再啟動 `kubelet`  的時候可以透過參數 **--network-plugin** 的方式來決定要如何設定該 kubernetes cluster 的網路解決方案
目前支援兩種設定
1. cni
2. kubenet

接下來針對這兩種選項討論一下彼此的用法與架構

### CNI
`CNI` 顧名思義就是使用各式各樣的 `CNI` 解決方案來為 Kubernetes cluster 提供網路能力， 前述文章討論 CNI 的時候，有提到兩個跟檔案有關的概念，一個是 `CNI` 解決方案的 binary，另外一個則是基於 json 格式的 `CNI` 設定檔案。

有這些檔案就會有檔案存取的問題需要處理，因此 kubelet 這邊就必須要針對上述兩種類型的檔案設定其系統位置。 該兩個參數分別是

1. --cni-bin-dir
預設情況是在 /opt/cni/bin，用來存放各式各樣的 CNI 解決方案的執行檔
2. --cni-conf-dir
預設情況是在 /etc/cni/net.d/，用來存放當前要提供給 CNI 使用的設定檔案，檔案格式就如同前篇討論過的 **Network Configuration**  或是 **Network Configuration List**。

我們先來觀察一下當前 kubelet 的設定
```bash=
vagrant@k8s-dev:~$ ps axuw | grep kubelet | grep cni
root      2433  2.0  2.2 1346404 90016 ?       Ssl  00:37   4:21 /usr/bin/kubelet 
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf 
--kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml 
--cgroup-driver=cgroupfs --network-plugin=cni 
--pod-infra-container-image=k8s.gcr.io/pause:3.1 --resolv-conf=/run/systemd/resolve/resolv.conf
```

可以觀察到預設情況下， kubeadm 會使用 `cni` 的方式作為 network-plugin 的選項，此時我們來看看上述提到的兩個資料夾到底放了什麼檔案

```bash=
vagrant@k8s-dev:~$ sudo ls /opt/cni/bin/
bridge  dhcp  flannel  host-device  host-local  ipvlan  loopback  macvlan  portmap  ptp  sample  tuning  vlan

vagrant@k8s-dev:~$ file /opt/cni/bin/*
/opt/cni/bin/bridge:      ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/dhcp:        ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/flannel:     ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/host-device: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/host-local:  ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/ipvlan:      ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/loopback:    ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/macvlan:     ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/portmap:     ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/ptp:         ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/sample:      ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/tuning:      ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
/opt/cni/bin/vlan:        ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
```

首先我們先觀察 **--cni-bin-dir** 設定的資料夾，裡面放置了各式各樣的執行檔，每個執行檔案的名稱必須與 **Network Configuration** 裡面的 **type** 一致。

上述所有的執行檔除了 **flannel** 外都是內建的，其他的執行檔都是 [ContainerNetworking GitHub](https://github.com/containernetworking/plugins/tree/master/plugins/main) 官方維護的，算是提供一些最基本的 `CNI` 解決方案給其他的開發者重複利用。
所以如果今天需要自行開發一套 CNI，則必須要將該執行檔也放入到這個資料夾中才可以被使用。

```bash=
vagrant@k8s-dev:~$ sudo ls /etc/cni/net.d/
10-flannel.conflist

vagrant@k8s-dev:~$ sudo cat /etc/cni/net.d/10-flannel.conflist
{
  "name": "cbr0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
vagrant@k8s-dev:~$
```
首先我們先觀察 **--cni-conf-dir** 設定的資料夾，裡面只有放置一個檔案 **10-flannel.conflist**， 這個檔案是安裝 `flannel` 時一併安裝進來的。預設情況下該資料夾是完全空的，不會有任何設定。

所以這個運作流程是欲使用的 `CNI` 解決方案必須要
1. 安裝欲使用的 binary 檔案放到 --cni-bin-dir 的位置
2. 將要使用的 CNI 設定檔案(json) 放到 --cni-conf-dir 的位置

同時這邊要注意的是 **CNI** 是伴隨 **kubelet** 去運行的，因此 kubernetes cluster 內的所有節點都要獨立進行上述的設定，所以其實也是可以做到每一台節點使用不同的 CNI 解決方案或是相同解決方案但是採用不同的設定檔案。

另外上述 **flannel** 安裝的檔案 **10-flannel.conflist** 是一個 **Network Configuration List** 的格式

其裡面描述了兩個要**依序**執行的 `CNI` binary,分別是 **flannel** 以及 **portmap**，所以也要確認這兩個檔案都有在 **--cni-bin-dir** 的位置內。

```bash=
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
```

由這邊可以觀察到 **flannel** 本身並不是單純只依賴自己的 binary 去完成所需功能的，實際上背後用到的 binary 數量更多，之後會有篇文章詳細介紹 **flannel** 的運作原理與安裝過程。

所以用一個流程來描述一下當前環境內的 CNI 運作流程
1. 使用者發送創建 Pod 的請求，最後送到 Kubelet
2. Kubelet 透過 dockershim + docker-containerd 的方式創建出需要的 container
3. 當 Pod 創建完畢後， kubelet 準備透過 CNI 的流程來設定該 Pod 內的網路
    a. 去搜尋 --cni-conf-dir 資料夾下的所有檔案，依照字母排序的方式找到第一個合法的設定檔案，這個範例就是 **10-flannel.conflist**
    b. 解讀該設定檔案的內容 **Network Configuration List**， 接者針對每個該陣列內的內容去解讀，讀取到第一個項目的 **type** 是 **flannel**
    c. 將所有需要的參數準備，呼叫 --cni-bin-dir 底下的 **flannel** binary
    d. 執行完畢將相關的 STDOUT 準備好，然後再次呼叫 --cni-bin-dir 底下的 **portmap** binary
4. CNI 相關程序執行完畢

### Kubenet
剛剛前述談了這麼多，接下來看一下另外一個 **network-plugin** 的選項 **kubenet**

**kubenet** 是個非常簡單的 L2 Bridge 實現，背後的實現也還是透過基本的 CNI 解決方案來建立一個非常簡單的環境，這個環境簡單到根本不能實現節點對節點溝通，只能用在單一節點或是你有其他的方式去設定節點間的網路路由問題。

使用這個 **Kubenet** 選項的話，也是要確認系統上 **--cni-bin-conf** 裡面有下列的 binary
- bridge
- lo
- host-local

所以基本上這個選項就是拿來測試用，不會拿來商用現在也不是預設選項，有興趣的瞭解更多細節的細節可以參考[官網說明](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/#kubenet)

## Pause Container
上篇文章有討論過所有的 Sandbox Container 的概念，作為一個創世 container，讓使用者的 container 都跟其共享 `network namespace`，藉此滿足多個 container 可以共用
- 網卡名稱
- IP 地址
- IPtables 規則
- 路由規則
- ...等各種網路資源

![](https://i.imgur.com/K95n3LP.png)
上圖節錄自[Containerd Brings More Container Runtime Options for Kubernetes
](https://kubernetes.io/blog/2017/11/containerd-container-runtime-options-kubernetes/)

而 **kubernetes** 之中也是用了相同概念的方式去實現所謂的 **Pod**，而這個 **Sandbox Contaienr** 也被稱為 **Infrastructure Container**。

如果仔細觀察 **kubelet** 的設定參數就會看到一個相關的設定

```bash=
vagrant@k8s-dev:~$ ps axuw | grep kubelet | grep cni
root      2433  2.0  2.2 1346404 90016 ?       Ssl  00:37   4:21 /usr/bin/kubelet 
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf 
--kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml 
--cgroup-driver=cgroupfs --network-plugin=cni 
--pod-infra-container-image=k8s.gcr.io/pause:3.1 --resolv-conf=/run/systemd/resolve/resolv.conf
```

上述的設定中將 **--pod-infra-container-image** 設定成 k8s.gcr.io/pause:3.1, 這個是其 container image 的位置，代表 kubernetes 會透過這個 image 創立一個 sandbox container 當做基底，接下來才把使用者規劃的 container 都與其共享 **network namespace**

這時候如果透過 **docekr ps** 的指令去觀察，可以觀察到有非常多的 **pause** container 被創立，而其 container name 都是一個一個的 **Pod**
```bash=
vagrant@k8s-dev:~$ sudo docker ps | grep pause
10a6fcd1692d        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_coredns-86c58d9df4-srncw_kube-system_a448c5f9-dc93-11e9-9d35-080027c2be11_3
104bb6a0c83e        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_coredns-86c58d9df4-v8f5d_kube-system_a449ee4f-dc93-11e9-9d35-080027c2be11_4
4581173892a6        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_kube-proxy-dl4bm_kube-system_a46016b1-dc93-11e9-9d35-080027c2be11_1
209b3af9308c        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_kube-flannel-ds-amd64-5xmgf_kube-system_a4626d19-dc93-11e9-9d35-080027c2be11_1
1710678a5a02        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_kube-scheduler-k8s-dev_kube-system_15c129447b0aa0f760fe2d7ba217ecd4_1
c63c097c20c5        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_kube-controller-manager-k8s-dev_kube-system_8a8f55dd50b2821b309adc83a00139ff_1
3bee914719b2        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_kube-apiserver-k8s-dev_kube-system_d834af7c4c9483e2d999ded255dd7798_1
82aa2e03cec9        k8s.gcr.io/pause:3.1   "/pause"                 6 hours ago         Up 6 hours                              k8s_POD_etcd-k8s-dev_kube-system_71e763946160f2ea04d6946ece43e176_1
```

Pause container 的原始內容都可以在 [GitHub](https://github.com/kubernetes/kubernetes/blob/master/build/pause/pause.c) 這邊找到，其實作非常簡單，就是一個攔截相關系統訊號後透過 system call 進行 **pause** 的應用程式而已，相關內容如下。

```c=
/*
Copyright 2016 The Kubernetes Authors.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define STRINGIFY(x) #x
#define VERSION_STRING(x) STRINGIFY(x)

#ifndef VERSION
#define VERSION HEAD
#endif

static void sigdown(int signo) {
  psignal(signo, "Shutting down, got signal");
  exit(0);
}

static void sigreap(int signo) {
  while (waitpid(-1, NULL, WNOHANG) > 0)
    ;
}

int main(int argc, char **argv) {
  int i;
  for (i = 1; i < argc; ++i) {
    if (!strcasecmp(argv[i], "-v")) {
      printf("pause.c %s\n", VERSION_STRING(VERSION));
      return 0;
    }
  }

  if (getpid() != 1)
    /* Not an error because pause sees use outside of infra containers. */
    fprintf(stderr, "Warning: pause should be the first process\n");

  if (sigaction(SIGINT, &(struct sigaction){.sa_handler = sigdown}, NULL) < 0)
    return 1;
  if (sigaction(SIGTERM, &(struct sigaction){.sa_handler = sigdown}, NULL) < 0)
    return 2;
  if (sigaction(SIGCHLD, &(struct sigaction){.sa_handler = sigreap,
                                             .sa_flags = SA_NOCLDSTOP},
                NULL) < 0)
    return 3;

  for (;;)
    pause();
  fprintf(stderr, "Error: infinite loop terminated\n");
  return 42;
}
```


## CRI Impact
最後來分享的是 **CRI** 對 **CNI** 的關係

**CNI** 作為完成整體 Container 創建的一部份，所以都是由 CRI 解決方案那邊去處理相關流程，因此不同的 **CRI** 解決方案對於 **CNI** 的處理流程也就不一定相似。
譬如上述有提到於 **dockershime** 的環境下，會將 **--cni-conf-dir** 內的設定檔案進行排序，並且使用第一個合法的設定檔案。

相關的原始碼可以參考 [GitHub](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/dockershim/network/cni/cni.go#L154-L216)

而如果採用的是基於 `containerd` 或是 `cri-o` 這種解決方案的話，最後都會透過 **ocicni** 這個工具去處理，而同樣的流程其運作過程就不太一樣，反而會是一次讀取全部的資料進來，之後再慢慢處理

相關的原始碼可以參考 [GitHub](https://github.com/cri-o/ocicni/blob/master/pkg/ocicni/ocicni.go#L266)

# Summary
本篇文章跟大家討論了下 Kubernets 與 CNI 相關的設定，只要對這些資料夾有基本的理解，以後看到任何 kubernetes cluster 都能夠有辦法粗略的看一下這個 cluster 是用哪套  CNI 來提供服務的。
特別的是如果你今天使用的是公有雲的服務，譬如 GKE, AKS, EKS 等服務，你也可以嘗試去看看這些公有雲到底是用哪套 CNI, 其設定檔案又是如何，接者可以搭配他們的文件或是原始碼去理解其其運作原理。

# 參考
- https://github.com/containernetworking/cni
- https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/dockershim/network/cni/cni.go
- https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- https://github.com/containernetworking/plugins/tree/master/plugins/main
- https://github.com/kubernetes/kubernetes/blob/master/build/pause/pause.c
