# Summary

* 2019 鐵人賽
    * [Kubernetes 設計原理](2019/overview/day1.md)
    * Container 介紹
        * [淺談 Container 實現原理- 上](2019/container/day2.md)
        * [淺談 Container 實現原理- 中](2019/container/day3.md)
        * [淺談 Container 實現原理- 下](2019/container/day4.md)
    * Container Runtime Interface(CRI)
        * [Kubernetes & CRI (I)](2019/runtime/day5.md)
        * [Kubernetes & CRI (II)](2019/runtime/day6.md)
        * [Container Runtime - CRI-O](2019/runtime/day7.md)
        * [Container Runtime - Security Container](2019/runtime/day8.md)
        * [Container Runtime - Virtual Machine](2019/runtime/day9.md)
    * Container Network Interface(CNI)
        * [Container Network Interface 介紹](2019/network/day10.md)
        * [kubernetes 與 CNI 的互動](2019/network/day11.md)
        * [使用 golang 開發第一個 CNI 程式](2019/network/day12.md)
        * [初探 CNI 的 IP 分配問題 (IPAM)](2019/network/day13.md)
        * [CNI - Flannel - 安裝設定篇](2019/network/day14.md)
        * [CNI - Flannel - IP 管理篇](2019/network/day15.md)
        * [CNI - Flannel - VXLAN 封包運作篇](2019/network/day16.md)
        * [CNI 閒談](2019/network/day17.md)
    * Container Storage Interface(CSI)
        * [Container Storage Interface 基本介紹](2019/storage/day18.md)
        * [Container Storage Interface 標準介紹](2019/storage/day19.md)
        * [Container Storage Interface 與 kubernetes](2019/storage/day20.md)
        * [Container Storage Interface(CSI) - NFS 初體驗](2019/storage/day21.md)
        * [CSI 雜談](2019/storage/day22.md)
    * Device Plugin
        * [Device Plugin Introduction](2019/device-plugin/day23.md)
        * [Device Plugin - Kubernetes](2019/device-plugin/day24.md)
        * [RDMA](2019/device-plugin/day25.md)
        * [SR-IOV](2019/device-plugin/day26.md)
    * Miscellaneous
        * [Operator Pattern](2019/extension/day27.md)
        * [Service Catalog](2019/extension/day28.md)
        * [Security](2019/security/day29.md)
    * [總結](2019/summary/day30.md)



* 2020 鐵人賽
    * [DevOps 與 Kubernetes 的愛恨情仇](2020/overview/day1.md)
    * Kubernetes 物件管理與部署
        * [Kubernetes 物件管理簡介](2020/application/day2.md)
        * [Helm 的介紹](2020/application/day3.md)
        * [Helm 的使用範例](2020/application/day4.md)
    * Kubernetes 本地開發之道
        * [淺談本地部署 Kubernetes 的各類選擇](2020/local/day5.md)
        * [K3D與KIND 的部署示範](2020/local/day6.md)
        * [本地開發 Kubernetes 應用程式](2020/local/day7.md)
        * [Skaffold  本地開發與測試](2020/local/day8.md)
    * CI 流水線介紹
        * [Pipeline System 介紹](2020/ci/day9.md)
        * [CI 與 Kubernetes 的整合](2020/ci/day10.md)
        * [Kubernetrs 應用測試](2020/ci/day11.md)
        * [CI Pipeline x Kubernetes 結論](2020/ci/day12.md)
    * CD 流水線介紹
        * [CD 系統的選擇議題](2020/cd/day13.md)
        * [CD 與 Kubernetes 的整合](2020/cd/day14.md)
        * [CD 之 Pull Mode 介紹: Keel](2020/cd/day15.md)
    * GitOps 的部署概念
        * [GitOps 的介紹](2020/gitops/day16.md)
        * [GitOps 與 Kubernetes 的整合](2020/gitops/day17.md)
        * [GitOps - ArgoCD 介紹](2020/gitops/day18.md)
    * Private Registry
        * [Container Registry 的介紹及需求](2020/registry/day19.md)
        * [自架 Registry 的方案介紹](2020/registry/day20.md)
        * [自架 Registry - Harbor](2020/registry/day21.md)
        * [自架 Registry 與 Kubernetes 的整合](2020/registry/day22.md)
    * Secret 的議題
        * [Secret 的部署問題與參考解法(上)](2020/secret/day23.md)
        * [Secret 的部署問題與參考解法(下)](2020/secret/day24.md)
        * [Secret 使用範例: sealed-secrets](2020/secret/day25.md)
    * 番外篇
        * [kubectl plugin 介紹](2020/plugin/day26.md)
        * [Kubernetes plugin 範例](2020/plugin/day27.md)
        * [Kubernetes 第三方好用工具介紹](2020/plugin/day28.md)
    * [Summary](2020/summary/day29.md)
    * [各類資源分享](2020/summary/day30.md)

* 2021 鐵人賽
    * Rancher 基本知識
        * [淺談 Kubernetes 的架設與管理](2021/day1.md)
        * [何謂 Rancher](2021/day2.md)
        * [Rancher 架構與安裝方式介紹](2021/day3.md)
        * [透過 RKE 架設第一套 Rancher(上)](2021/day4.md)
        * [透過 RKE 架設第一套 Rancher(下)](2021/day5.md)
    * Rancher 系統管理指南
        * [系統管理指南 - 使用者登入管理](2021/day6.md)
        * [系統管理指南 - RKE Template](2021/day7.md)
    * Rancher 叢集管理指南
        * [架設 K8s(上)](2021/day8.md)
        * [架設 K8s(下)](2021/day9.md)
        * [RKE 管理與操作](2021/day10.md)
        * [Monitoring 介紹](2021/day11.md)
    * Rancher 專案管理指南
        * [Project 基本概念介紹](2021/day12.md)
        * [Resource Quota 介紹](2021/day13.md)
    * Rancher 雜談
        * [其他事項](2021/day14.md)
        * [Rancher & Infrastructure as Code][2021/day15.md]
        * [Rancher 指令工具的操作][2021/day16.md]
    * Rancher 應用程式部署
        * [淺談 Rancher 的應用程式管理][2021/day17.md]
        * [Rancher Catalog 介紹(v2.0~v2.4)][2021/day18.md]
        * [Rancher App & Marketplace 介紹(v2.5)][2021/day19.md]
    * GitOps 部署
        * [淺談 GitOps ][2021/day20.md]
        * [GitOps 解決方案比較][2021/day21.md]
        * [Rancher Fleet 介紹][2021/day22.md]
        * [Fleet 環境架設與介紹][2021/day23.md]
        * [Fleet 玩轉第一個 GitOps][2021/day24.md]
        * [Fleet.yaml 檔案探討][2021/day25.md]
        * [Fleet Kubernetes 應用程式部署][2021/day26.md]
        * [Fleet Kustomize 應用程式部署][2021/day27.md]
        * [Fleet Helm 應用程式部署][2021/day28.md]