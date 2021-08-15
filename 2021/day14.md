Day 14 - Rancher - 其他事項
==========================


本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

過去十多篇文章從從三個不同角度來探討如何使用 Rancher，包含系統管理員，叢集管理員到專案管理員，不同層級專注的角度不同，因此使用上也有不同的功能可以用。

本篇文章將探討 Rancher 一些其他的注意事項。

# 清除節點

之前文章探討過三種不同安裝 Kubernetes 的方式，其中一種方式是運行 docker command 在現有的節點上將該節點加入到 RKE 叢集中。

但是如果今天有需求想將該節點從 RKE 中移除該怎麼辦?

![](https://i.imgur.com/K9JI1WS.png)

Cluster Manager 中可以直接到 Cluster 頁面將該節點從 RKE 中移除，但是要注意的是，這邊的移除代表的只是將該節點從 RKE 移除，該節點上可能會有一些因為加入 RKE 而產生的檔案依然存在節點上。

假設今天有需求又要將該節點重新加入回到 RKE 中的話，如果上次移除時沒有妥善地去刪除那些檔案的話，第二次運行 docker command 去加入 RKE 叢集有非常大的機率會失敗，因為節點中有太多之前的產物存在。

官網有特別撰寫一篇文章探討如果要清除這些產物的話，有哪些資源要處理，詳細版本可以參閱 [Removing Kubernetes Components from Nodes](https://rancher.com/docs/rancher/v2.5/en/cluster-admin/cleaning-cluster-nodes/)

這邊列舉一下一個清除節點正確步驟
1. 從 Rancher UI 移除該節點
2. 重啟該節點，確保所有放到暫存資料夾的檔案都會消失
3. Docker 相關資料
4. Mount 相關資訊都要 umount
5. 移除資料夾
6. 移除多的網卡
7. 移除多的 iptables 規則
8. 再次重開機

第三點移除 docker 相關資料，官方列出三個指令，分別移除 container, volume 以及 image。
```bash
docker rm -f $(docker ps -qa)
docker rmi -f $(docker images -q)
docker volume rm $(docker volume ls -q)
```

如果該節點接下來又要重新加入到 Rancher 中，建議不需要執行 docker rmi 的步驟，之前的 image 可以重新使用不需要重新抓取，這樣可以省一些時間。

第四點的 mount 部分要注意的是，官文文件沒有特別使用 sudo 的指令於範例中，代表其假設你會使用 root 身份執行，因此如果不是使用 root 的話記得要在 umount 指令中補上 sudo

```bash
for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do sudo umount $mount; done
```


第五點跟第四點一樣，但是第五點非常重要，因為系統上有太多的資料夾都含有過往 RKE 叢集的資料，所以第五步一定要確保需要執行才可以將資料清除。

```bash=
sudo rm -rf /etc/ceph \
       /etc/cni \
       /etc/kubernetes \
       /opt/cni \
       /opt/rke \
       /run/secrets/kubernetes.io \
       /run/calico \
       /run/flannel \
       /var/lib/calico \
       /var/lib/etcd \
       /var/lib/cni \
       /var/lib/kubelet \
       /var/lib/rancher/rke/log \
       /var/log/containers \
       /var/log/kube-audit \
       /var/log/pods \
       /var/run/calico
```


第六跟第七這兩步驟並不一定要處理，因為這些資訊都是節點加入到 Kubernetes 後被動態創建的，基本上重開機就不會有這些資訊，只要確保節點重新開機後沒有繼續成為 Kubernetes 的節點，那相關的虛擬網卡跟 iptables 規則也就不會被產生。

要注意的是官方文件中的所有步驟不一定都會有東西可以刪除，主要會取決於叢集內的設定，不同的設定可能會有不同的結果，譬如採用不同的 CNI，其產生的 iptables 規則與虛擬網卡就會有所不同。

# 離線安裝
雖然雲端環境方便存取，但是很多產業與環境可能會需要於一個沒有對外網路的環境下去安裝 Kubernetes 叢集，這種情況下如果想要使用 Rancher 的話就要探討如何達到離線安裝。

Rancher 講到離線安裝有兩種含義，一種是
1. Rancher 本身的離線安裝
2. Rancher 以離線安裝的方式幫忙創建 RKE 叢集

上述兩種方式其實都還是仰賴各式各樣的 container image 來處理，所以處理的方法一致，就是要安裝一個 container registry 並且將會需要使用的 container image 都事先匯入到該 container registry 中，接者安裝時要讓系統知道去哪下載相關的 container image 即可。

官網有數篇文章探討這種類型下的安裝該怎麼處理，有興趣的也可以參考 [Air Gapped Helm CLI Install](https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/)

由於安裝 Rancher 本身有很多方式，譬如多節點的 RKE 或是單節的 Docker 安裝，以下簡述一下如何用 Docker 達成單節點的離線安裝。
1. 架設一個 Private Container Registry
2. 透過 Rancher 準備好的腳本去下載並打包 Rancher 會用到的所有 Container Image
3. 把第二步驟產生 Container Image 檔案給匯入到 Private Container Registry
4. 運行修改過後的 Docker 來安裝 Rancher.

第一點這邊有幾點要注意
a. 可以使用 container registry v2 或是使用 harbor
b. 一定要幫該 container registry 準備好一個憑證，這樣使用上會比較方便，不用太多地方要去處理 invalid certificate 的用法。憑證的部分可以自簽 CA 或是由一個已知信任 CA 簽署的。
c. image 的容量大概需要 28 GB 左右，因此準備環境時要注意空間

第二跟第三點直接參閱官網的方式，先到 GitHub 的 Release Page 找到目標版本，接者下載下列三個檔案
1. rancher-images.txt
2. rancher-save.images.sh
3. rancher-load-images.sh

第二個腳本會負責去下載 rancher-images.txt 中描述的檔案並且打包成一個 tar 檔案，系統中會同時存放 container image 以及 tar 檔，所以最好確保空間有 60GB 以上的足夠空間。
第三個腳本會將該 tar 檔案的內容上傳到目標 container registry。

這一切都準備完畢後，就可以執行 docker 指令，可以參閱[Docker Install Commands](https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/install-rancher/docker-install-commands/)

一個範例如下
```bash=
docker run -d --restart=unless-stopped \
    -p 80:80 -p 443:443 \
    -v /mysite/fullchain.pem:/etc/rancher/ssl/cert.pem \
    -v /mysite/previkey.pem>:/etc/rancher/ssl/key.pem \
    -e CATTLE_SYSTEM_DEFAULT_REGISTRY=test.hwchiu.com \ # Set a default private registry to be used in Rancher
    -e CATTLE_SYSTEM_CATALOG=bundled \ # Use the packaged Rancher system charts
    --privileged
    registry.hwchiu.com/rancher/rancher:v2.5.9  \
    --no-cacerts
```

請特別注意上述的參數，不同的憑證方式會傳入的資訊不同，自簽的方式還要額外把 CA_CERTS 給丟進去。
