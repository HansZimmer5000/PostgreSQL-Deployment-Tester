---
marp: true
theme: gaia
paginate: true
footer: "![image height:25px](res/mlLogo.png) | **Michael Müller** - _Zero Downtime Upgrading_"
backgroundImage: url('./res/heroBG.jpg')

---
<style>
    header {
      position: absolute;
      left: 1180px;
    }

    footer {
        text-align: center;
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
*Zero Downtime Upgrade*

---
<style scoped>
    section {
        text-align: center;
    }
</style>
![width:900px](res/hotswap.jpg)

---
<!-- _footer: "![image height:25px](res/mlLogo.png) | **Michael Müller** - _Zero Downtime Upgrading_ // Quelle oder Hinweis" -->

# **Aufgabenstellung (+Intro 2 Minuten)**

- TODO Alle Folien in 10 Sekunden verständlich?
- TODO Insgesamt 60 Minuten? 
- TODO Wenn Final, Zeiten in Kommentare und Gruppierung (Wort vor "-") streichen.
- PostgreSQL HA Environment
- Zero Downtime Upgrading 
- IT-Security nicht im Mittelpunkt

---

# **Problem - Context (6 Minuten)**

- (Verbessertes) HA Cluster in Docker Swarm 
- PostgreSQL v9.5
- Upgrade in HA Environments:
    - Zero Downtime
    - **Rolling Upgrade**
    - Blue/Green Deployment

<!--
Vergleich Rolling <-> Blue/Green
    - Blue/Green braucht mehr Resourcen
-->

---

# **Problem - Existierende Lösungen (5 Minuten)**

- **Spilo/Patroni/Stolon/Zalando PO**: Nur mit Kubernetes
- **CrunchyData Container**: Keine Logische Replikation
- **ClusterControl**: PostgreSQL v9.6 oder höher
- **Bucardo**: Interessant, aber zu spät gesehen

<!-- 
- CrunchyData Container: Bereits in Verwendung für normales HA Deployment, allerdings keine Logische Replikation!
- ClusterControl: Only works with v9.6 or higher.
- Bucardo (Keine Info zu Upgrade Prozess aber sieht interessant aus, leider zu spät gesehen: https://bucardo.org/Bucardo/index.html)
- BDR (Kostenpflichtig)
- Citus (No Info if workes with V9.5)
- Zalando PO=PostgresOperator/Spilo/Patroni/Stolon (only works with Kubernetes/Helm)
-->
---
<style scoped>
    table {
        font-size: 35px; /* normal size is 35 */
        text-align: center;
        margin-left: 10%;
    }
</style>
# **Problem - Anforderungen (7 Min)**

|ID|Blickwinkel|Must-Have Anforderung              |
|--|-----------|-----------------------------------|
|A1|Aufgabe    |Zero Downtime Upgrade              |
|A2|Tech       |PostgreSQL limitationen            |
|A3|Tech       |Docker (Swarm) limitationen        |
|A4|Kunde      |Keine Schwächung der HA-Eigenschaft|
|A5|Kunde      |Kein Datenverlust                  |

<!--
Maintainer = Wir / Nachtblau

- Nicht berücksichtigt:
    - (Kunde) Ein wenig Downtime OK, aber soll dann auch laufen. (Konträr zur Aufgabenstellung)
    - (Kunde) Neue Version soll möglichst lange laufen, Performanter sein, oder weitere Vorteile bringen.
- Must-Have
    - Siehe Tabelle
- Should-Have
    - A6 (Kunde) Keine Internet Connection während Update
    - A7 (Kunde) Unmodifizierte PostgreSQL Container
    - A8 (Maintainer) PostgreSQL Version je Container transparent
    - A9 (Maintainer) Möglichst leicht umzusetzen / zu warten.
- Nice-To-Have
    - A10 (Kunde) Möglichst geringe Upgradedauer
-->
---

# **Solution - Lösungen (5 Minuten)**
- Rolling Upgrade
    - Zuerst nach und nach Subscriber upgraden
    - Zuletzt Provider Upgrade
        - Provider v9.5 upgraden -> Subscriber v10
        - Subscriber v10 befördern -> Provider v10
    - pglogical2 für Logische Replikation in v9.5
- Externes "Upgrader" Skript
---

# **Solution - Lösungen**

- TODO Folie nicht zeigen, nur für Organisation
- InPlace (5 Minuten)
- Seperate Services (5 Minuten)

---

<style scoped>
    footer {
        text-align: left;
    }

    section {
        text-align: center;
        padding-top: 10px;
    }
</style>

![h:700px](./res/InPlaceInstanz.png)


<!--
Nur Vorstellen, noch nicht vergleichen!
-->

---
<style scoped>
    footer {
        text-align: left;
    }

    section {
        text-align: center;
        padding-top: 10px;
    }
</style>
![h:700px](./res/SepSvcInstanz.png)

<!--
Nur Vorstellen, noch nicht vergleichen!
-->

---

# **Vergleich der Lösungen (8 Minuten)**

- **InPlace** (Done & Tested)
    - Nicht erfüllte Anfoderungen: A6, A7, A8, A9
- **Seperate Services** (Wird implementiert)
    - Nicht erfüllte Anfoderungen: ggf. A10
- TODO Sind die Lösungen wirklich valide?

<!--
- Welche Lösung wird nun implementiert & getestet?
    - Externer: Scheiterte an Machbarkeit wegen Docker Limitationen (Neustart nach Upgrade mit altem Container -> nutzt alte Binarys und Daten)
    - Sep Services: Kam vor 2 Wochen als Idee auf, als InPlace schon fertig war
-->
---
# **Testbed (2 Minuten)**
- 2 VirtualBox VM (1 Core, 1GB Ram)
    - CentOS 7
    - Docker v19.03.8
    - PostgreSQL v9.5.18 & v10.13
- 1 Provider / 1 Subscriber
---
# **Testszenarios (5 Minuten)**

- Test 1: Major Upgrade eines Subscribers 
- Test 2: Major Upgrade des Clusters

<!--
- Alle Tests starten mit einem Provider und einem Subscriber inklusive Check ob Replikation so funktioniert wie sie soll.
- Test_1: Prüfe, ob die vom Testtool erkannten Rollen auch die realen Rollen (Provider/Subscriber) sind.
- Test_2: Prüfe, ob nach Subscriber Crash, neuer Subscriber auch die alten Daten erhält.
- Test_3: Prüfe, ob nach Provider Crash, neuer Provider tatsächlich von dem Subscriber als Provider erkannt wird.
- Test_4: Prüfe, ob nach Provider Crash, neuer Provider die alten Daten hat.
- Up_Test1: Prüfe, ob Major Upgrade eines Subscribers Probleme verursacht (z.b. Crash, Verlust alter Daten)
- Up_Test2: Prüfe, ob Major Upgrade des Clusters Probleme verursacht (z.b. Crash, Verlust alter Daten)
-->
---
# **Testtool (5 Minuten)**
- in Bash
- Hilft beim hoch- / herunterfahren des Testbeds in 3 Stufen (VMs, Docker, Postgres)
- Vereinfacht häufig genutzte Interaktion mit VMs, Docker, Postgres, Keepalived (z.b. lesen von Logs)
- Startet Testszenarios

<!--
- Live Vorführung?
-->
---
# **Conclusion (3 Minuten)**
- Tolles und facettenreiches Thema
- Valide Lösungen gefunden
- Detailierte Infos in Confluence
- IT-Security teilweise einfach nachrüstbar

<!--
Nach Research und etwas Trial & Error valide Lösungen gefunden

IT-Security nachrüstbar z.b. mit Postgres Passwörtern
-->

---
# **Zukünftige Arbeit (2 Minuten)**
- Implementation fertigstellen
- Ausprobieren von Bucardo
- Eigene Lösung verbessern: Refactoring, mehr Tests (Unit & Integration)
- Upgrade Dauer und Downtime implementierter Lösungen messen & vergleichen
--- 
<!--  
_header: ""
_paginate: false 
_footer: ""
-->

![bg left:40% contain](./res/LogoKombi.png)

<style scoped>
  h1 {
      font-size: 100px;
      padding-bottom: 0px;
      padding-top: 60px;
  }

  section {
      text-align: center;
      padding-right: 150px;
      padding-left: 0px;
  }
</style>


# **Thanks for Listening**

**Michael Müller**
_Zero Downtime Upgrading_

<!--The End-->