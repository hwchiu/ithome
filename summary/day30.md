[Day30] Summary
===============

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- [Device Plugin](https://ithelp.ithome.com.tw/articles/10226060)


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 感想

本篇為鐵人賽的最後一篇，本篇基本上沒有什麼要探討的了，主要是回顧一下這三十天以來的所有文章以及想要跟社群大眾分享的重點

從2012左右開始引起一波虛擬化熱潮的 OpenStack 開始，人們開始討論架構的改變，虛擬化帶來的優缺點，基於虛擬機器產生的部署環境開始落地於各種場景之中，不論是研究,測試或是真的商用.

然而在OpenStack出現之前，其實虛擬化的技術早就蓬勃發展，譬如 chroot, jail, lxc 甚至各式各樣的虛擬機器解決方案.

而 OpenStack 的出現，帶來的不單純只是一個虛擬化的範例，而是一整個解決方案，裡面滿滿的不同元件，基於不同的功能一起搭建出完整的解決方案。
我認為也是這一點才使得整個專案可以如此吸人目光與吸引熱潮，還在世界各地的使用者都思緒這如何使用這個 虛擬化叢集管理工具來管理大量的虛擬機器並且提供更有效的管理效率,良好的服務品質

然而軟體世界就是有趣，永遠都無法滿足眾人，隨著 docker 專案的興起，基於容器的虛擬化解決方案也開始吸引了一波目光，容器與虛擬機器的比較從來沒有停過，輕巧快速簡單等特色吸引了大眾的眼球。

就如同 OpenStack 帶來的叢集管理功能，容器方面是否也有基於多節點的管理工具?
Docker Swam, Mesos 等諸多的專案都為了這些方向發展，直到 kubernetes 的出現，我個人認為其幾乎打趴了先前的所有管理工具，幾乎一統了基於容器的叢集管理平台解決方案。

綜觀發展歷程，解決方案一直推陳出新，虛擬機器與容器共存，不同平台互相整合已提供更完善的解決方案。
對於使用者來說，看到的反而是一直出現的新專案，每個專案發展的速度比大部分使用學習速度還要快上超級多，根本追都追不上。

但是仔細想想，底層的容器技術早就存在已久，從隔離的 **namespace**, 網路的 **iptables/ipvs**, 儲存系統的 **mount,file system**, 系統的 **device** 等技術早就行之有年甚至成熟。
對於 **kubernetes** 來說就是如何把這些存在的功能與平台進行整合，讓使用者使用起來更為方便。

我自己的想法是除了學習新功能如何使用之外，其實多花點時間瞭解所有底層的運作原理並不會吃虧，目前看起來都還是過去那些基礎功能不停的轉換使用，而這些東西也是最為苦悶但是卻最為重要的基底。

一旦瞭解更多的底層原理，其實看到任何的新功能的時候都可以開始思考，這個功能可能怎麼完成的? 如果是我來做我會怎麼做，接者開始驗證自己的想法，藉由這種思考後學習的辦法其實更可以幫助你理解其實做的概念與理由。

很多時候實作上不一定會有註解，甚至文件都只是描述其功能，沒有描述為什麼，這時候如果有相關的經驗與概念，對於思考上都會有很大的幫助。

最後再次重申，學習底層原理，學習閱讀原始碼，都能夠為你帶來很大的好處與進步，這些知識也許短時間之內不能幫你解決問題，但就如同歷久彌新般的內功，你遲早會愛上他的>


# 相關資料

這次 30 天的所有文章都放到 [GitHub](https://github.com/hwchiu/ithome-2020ironman) 上面了，

# 社群推廣

最後跟來跟大家推廣一下台灣在地社群， [Cloud Native Taiwan User Group](https://www.facebook.com/groups/cloudnative.tw/)

每個月都會定期有 meetup 來探討各式各樣的議題，有從使用者角度出發的，也有從底層開發出發的，歡迎大家有興趣可以加入社群一起討論。

[Telegram](https://t.me/cntug)

[Meetup](https://www.meetup.com/CloudNative-Taiwan/)

[每次 Meetup 投影片紀錄](https://github.com/cloud-native-taiwan/meetups)

[演講相關範例程式碼與相關文章](https://github.com/cloud-native-taiwan/kourse)

[徵才相關](https://github.com/cloud-native-taiwan/jobs)
