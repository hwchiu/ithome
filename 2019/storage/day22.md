[Day22] Container Storage Interface(CSI) - 經驗談
================================================

> 本文同步刊登於 [hwchiu.com - CSI NFS 初體驗](https://www.hwchiu.com/csi-nfs.html)

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

作為 **Container Storage Interface** 的最後一篇，如同慣例這篇文章就不會探討太多深入的議題，分享一些我自己目前對儲存這方面的一些經驗與想法。

就 **CRI/CNI/CSI** 三個面向的議題來說，我認為 **CSI** 是最困難的，對於 **CRI** 來說，一般使用根本不會在意底層到底是走哪套實現來提供容器的功能，更何況很多公有雲提供的 kubernetes service 是根本沒有機會讓你去修改 **kubelet** 的參數，讓你來替換不同的 **CRI** 解決方案。

而 **CNI** 的選擇相對於 **CRI** 又多了一些，不過滿多的使用情境都是基於網路能通即可，這種情況下反而 **CNI** 的選擇也不會太大的問題。不過相較於 **CRI**來說，地端部署的 **kubernetes** 有時候會有滿多網路的限制需要處理，甚至是一些 load-balancer 等相關功能的引進，這時候也需要對 **CNI** 稍微看一下是否能完全支援所需。
此外就如同 **CRI** 一樣，公有雲上面的 kubernetes service 也是不方便讓你去修改 **CNI** 的設定，通常都會與該公有雲本身的基礎建設整合一起。

最後的 **CSI** 則不一樣了，不同於 **CRI/CNI** 為一個堪用容器的最低限度，很多時候甚至沒有額外的儲存設備整個 kubernetes cluster 還是可以運作得很好
而且 **CSI** 本身又因為透過 **StorageClass, PV, PVC** 等不同層次架構的抽象化，比較不會有公有雲跟自架的區別，你可以隨時安裝相關的套件到需要使用的節點上去，而且也可以隨時抽換，這相對起來選擇性非常多。也因為選擇性眾多，才會導致選擇性障礙而難以選擇一個適合自己的儲存解決方案。


# 儲存選擇
儲存方案的互相比較一直都沒有停止，不同的儲存方案都有各自的特色與使用場景，就如同第一篇文章所說的，很多時候都要先從使用情境下手，去估算
1. 空間要多大，會增長嗎
2. 存取速度要多快，是讀重要，還是寫重要
3. 讀寫的資料是隨機讀寫，還是依序讀寫
4. 希望面向的是 Block Device 還是 Mountable Volume?
5. 希望可以多重讀寫？
6. 本身能否有快照? 快照大概要多久
7. 快照能否復原，復原大概要多久
8. 儲存設備本身要地端還是雲端?
10. 本身能不能有備份的效果，硬碟壞掉能夠承受多少顆？

相關的議題列也列不完，針對每個答案都會有不同適合的儲存方案可以使用，而每個儲存方案又分成
1. 開源軟體，自己架設自己維護
2. 購買商業解決方案，從硬體到軟體一次搞定

這時候又要考量到預算的多寡，到底是找人維護方便還是購買解決方案方便? 這個問題也是沒有標準答案，就看每個單位自己的處理方式

選擇玩解決方案後，如果今天要導入到不同的管理平台，又要開始思考這些解決方案跟 **kubernetes** 是否整合良好？
整合的專案是否屬於活躍維護的狀態，相關的議題跟開發熱度夠不夠，甚至說是不是廠商自己有提供的相關的整合

無論如何，我堅決反對基於 **別人怎麼說，所以我就想要** 的這種心態去選擇儲存方案，沒有事先研究與評估，這種通常到後來都只會帶來各種災難。


# Mount

接下來探討一下關於 **Mount Propagation** 的概念，這篇功能於 **kubernetes** v1.8 之後推出，再一些比較複雜的系統設定中都會看到需要設定 **Mount propagation**，但是這個功能到底會做造成什麼變化與影響

詳細的過程非常複雜，牽扯到 **Linux Kernel** 內對於檔案系統的實作以及變化，欲知詳情可以參閱這篇文章 [Kubernetes Mount Propagation](https://medium.com/kokster/kubernetes-mount-propagation-5306c36a4a2d)。

一個最簡單會影響的功能就是對已經 **Mount** 過後的資料夾內，再次透過 **Mount** 掛載資料夾進去會發生什麼事情

```bash=
vagrant@k8s-dev:~$ sudo docker run -d -v /home/vagrant/kubeDemo/:/kubeDemo --name false hwchiu/netutils
288ddbb01a1b0e020bc227f1e9dfb58e9aba8885256bd394ebe2c74fbb6f05ad
```
首先我們透過 **docker** 創建一個測試的容器，命名為 **false**，接者將本地的 **/home/vagrant/kubeDemo** 資料夾掛載進去到容器裡面的 **/kubeDemo**


```bash=
vagrant@k8s-dev:~$ sudo docker exec false ls /kubeDemo
Vagrantfile
cert-manager
dns
docker
ingress
services

vagrant@k8s-dev:~$ ls /home/vagrant/kubeDemo/
cert-manager  dns  docker  ingress  services  Vagrantfile
```

接者先觀察 mount 的資訊是否正確，兩邊看到的資料夾與內容一致

```bash=
vagrant@k8s-dev:~$ mkdir kubeDemo/k8s
vagrant@k8s-dev:~$ sudo mount --bind k8s-course/ kubeDemo/k8s/

vagrant@k8s-dev:~$ ls -ls kubeDemo/
total 28
4 drwxrwxr-x  3 vagrant vagrant 4096 Sep 29 07:17 cert-manager
4 drwxrwxr-x  7 vagrant vagrant 4096 Sep 29 07:17 dns
4 drwxrwxr-x  2 vagrant vagrant 4096 Sep 29 07:17 docker
4 drwxrwxr-x  2 vagrant vagrant 4096 Sep 29 07:17 ingress
4 drwxrwxr-x 12 vagrant vagrant 4096 Sep 29 07:17 k8s
4 drwxrwxr-x  5 vagrant vagrant 4096 Sep 29 07:17 services
4 -rw-rw-r--  1 vagrant vagrant 2483 Sep 29 07:17 Vagrantfile

vagrant@k8s-dev:~$ ls -ls kubeDemo/k8s/
total 40
4 drwxrwxr-x 6 vagrant vagrant 4096 Sep 29 07:17 addons
4 drwxrwxr-x 3 vagrant vagrant 4096 Sep 29 07:17 docker
4 drwxrwxr-x 3 vagrant vagrant 4096 Sep 29 07:17 harbor
4 drwxrwxr-x 5 vagrant vagrant 4096 Sep 29 07:17 kubeflow
4 drwxrwxr-x 4 vagrant vagrant 4096 Sep 29 07:17 load-balancing
4 drwxrwxr-x 5 vagrant vagrant 4096 Sep 29 07:17 manual-installation
4 drwxrwxr-x 4 vagrant vagrant 4096 Sep 29 07:17 minikube-lab
4 drwxrwxr-x 4 vagrant vagrant 4096 Sep 29 07:17 multi-cluster
4 drwxrwxr-x 4 vagrant vagrant 4096 Sep 29 07:17 practical-k8s
4 -rw-rw-r-- 1 vagrant vagrant  250 Sep 29 07:17 README.md

```


接下來嘗試透過 **mount** 指令，把本機端的另外一個資料夾 **k8s-course** 給掛載到 **kubeDemo/k8s** ，這時候本機上面透過 **ls** 的指令可以順利觀察到於 **kubeDemoo/k8s** 中有完全跟 **k8s-course** 一樣的內容。
到這個步驟都如同預料的一樣。

```bash=
vagrant@k8s-dev:~$ sudo docker exec false ls /kubeDemo
Vagrantfile
cert-manager
dns
docker
ingress
k8s
services

vagrant@k8s-dev:~$ sudo docker exec false ls -l /kubeDemo/k8s
total 0
```
下一步則是我們嘗試觀察容器中的資料，就會發現完全資料，只有看到一個完全空的 **k8s** 資料夾，代表外面主機上面的 **mount** 並沒有真實的反映於容器內。

這個問題就是因為 **mount propagation** 並沒有一路傳遞進去，所以對於之後才新增加的 **mount point** 就沒有辦法被容器內看到，反之亦然。

為了解決這個問題我們可以開啟 **mount propagatioon: shard**，將上述的環境清除後來重新測試

```bash=
vagrant@k8s-dev:~/kubeDemo$ sudo docker run -d --mount type=bind,src=/home/vagrant/kubeDemo/,dst=/kubeDemo,bind-propagation=shared --name true hwchiu/netutils
bd70f4044d468fa9794e798c64e313057cf14d4ee12d3cdac748a4206fce3249

vagrant@k8s-dev:~/kubeDemo$ sudo docker exec true ls /kubeDemo
Vagrantfile
cert-manager
dns
docker
ingress
services
```

一樣創建容器，只是這次我們採用更複雜的指令來設定 **mount** 相關的選項，
**type=bind,src=/home/vagrant/kubeDemo/,dst=/kubeDemo,bind-propagation=shared**， 透過該指令我們可以做到跟之前一樣的對照關係，同時特別設定 **mount propagation** 為 **shared**。

```bash=
vagrant@k8s-dev:~$ mkdir kubeDemo/k8s
vagrant@k8s-dev:~$ sudo mount --bind k8s-course/ kubeDemo/k8s/

vagrant@k8s-dev:~$ sudo docker exec true ls -l /kubeDemo/k8s
total 40
-rw-rw-r-- 1 1000 1000  250 Sep 29 07:17 README.md
drwxrwxr-x 6 1000 1000 4096 Sep 29 07:17 addons
drwxrwxr-x 3 1000 1000 4096 Sep 29 07:17 docker
drwxrwxr-x 3 1000 1000 4096 Sep 29 07:17 harbor
drwxrwxr-x 5 1000 1000 4096 Sep 29 07:17 kubeflow
drwxrwxr-x 4 1000 1000 4096 Sep 29 07:17 load-balancing
drwxrwxr-x 5 1000 1000 4096 Sep 29 07:17 manual-installation
drwxrwxr-x 4 1000 1000 4096 Sep 29 07:17 minikube-lab
drwxrwxr-x 4 1000 1000 4096 Sep 29 07:17 multi-cluster
drwxrwxr-x 4 1000 1000 4096 Sep 29 07:17 practical-k8s

```

反覆上面的動作，接下來直接去容器內觀察，就會發現這時候可以看到相關的資料夾了，這樣就解決了沒辦法關看到後續新增的 **mount point** 的問題。

前一篇講到 **CSI** 解決方案的範例中，都會把大量的 **/var/lib/kubelet** 相關的資料夾掛載到 **Pod** 之中使用，對於 **CSI Node** 來說已經牽扯到真正與容器有關的空間掛載，所以這時候就會有需要再 **CSI Node** 容器內處理相關問題的需求，而這些更動也需要讓外面主機可以觀察到，所以都會看到對於 **mount propagation** 都需要設定。

# Summary
作為 **CSI** 的最後一篇文章，差不多把 **CSI** 相關的資訊都討論了一遍，最後就是基於自己的需求去選擇一個需要的解決方案，並且確認該解決方案是否已經有良好相容的 **CSI** 實作。

# 參考
- https://medium.com/kokster/kubernetes-mount-propagation-5306c36a4a2d
