---
marp: true
theme: gaia
paginate: true
header: "![image height:30px](res/mlLogo.png)"
footer: "**Michael Müller** - _Zero Downtime Upgrading_ "
backgroundImage: url('./res/heroBG.jpg')

---
<style>
  header {
      position: absolute;
      left: 1180px;
  }
</style>

<!-- 
_header: ""
_footer: ""  
_paginate: false
_class: lead
-->

<style scoped>
    section {
        font-size: 45px;
        padding-left: 0px;
    }
</style>

![bg left:40% contain](./res/LogoKombi.png)
# **Zero Downtime**

**PostgreSQL High Availability**
*Upgrade Process*

---
<!-- _footer: "Michael Müller - SDN on ACIDs // Image from [OpenNetworking](https://www.opennetworking.org/sdn-definition/)" -->

# **Intro**



---

# **Technology & Testenvironment**

| Software  |Function          |Version|
|-----------|------------------|-------|
|Floodlight |SDN Controller    |1.2    |
|OpenFlow   |SouthboundProtocol|1.4    |
|OpenVSwitch|Switch            |2.8.8  |
|Mininet    |Testenvironment   |2.2.2  |

- Hardware: i5-5200U with 8GB Ram
- Container > VM (Perigo 2018)

<!--

-->

--- 
<!--  _paginate: false -->
<style scoped>
  footer {
      bottom: 50px;
      left: 30px;
  }

  section {
      font-size: 90px;
      padding-bottom: 0px;
      padding: 50px;
  }
</style>


# **Thanks for Listening**

<!--The End-->