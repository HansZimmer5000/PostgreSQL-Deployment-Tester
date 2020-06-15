# Notes

## What do I want to tell?
- What is the context of this work (HA, Zero Downtime Upgrading, Postgres, Related Work)
- My Work
  - Requirements 
  - (All Solutions and) implemented solutions
  - Why does this better suit our needs than Related Work?
  - How is this tested?
- Conclusion
- 50% Problem (Intro, Context, Requirements, Existing Tools?)
- 50% Solution(s) (Concrete solutions, testbed, testszenario, testtool)

## Outline

- Context
  - What is HA Deployment?
    - Everything is replicated and there is a automatin failover after crash detection.
    - SLA (99,99% -> ca. 4 Min pro Monat Downtime)
  - what is Zero Downtime Upgrade?
    - Theoretically is it hardly possible to achieve tru zero downtime, no data loss upgrading (+Meme Picture)
  - Postgres Context
    - Versioning (Major / Minor)
    - Physical / Asynch or Synch, Logical (Streaming) Replication
  - Related Work (Theory and tools: Stolon, ...)
- My Work
  - Requirements 
  - (All Solutions and) implemented solutions
  - Why does this better suit our needs than Related Work?
  - How is this tested?
  - Limitations with Docker Swarm & Keepalived
  - Lessons Learned
  - My Tool + Live presentation of it?
- Conclusion

### Chronological Order

- How to upgrade in HA environment?:
  - Zero Downtime
  - Rolling Upgrade
  - Blue/Green
  - Canary
- What is our Deployment?
  - PostgreSQL as Docker Swarm Service
    - 1 Master (Provider / Publisher)
    - n Warm Standbies (Subscriber)
    - Physical Streaming Replication
  - Role DEfinition of PostgreSQL via Keepalived promotions
- Rolling Upgrade limitations
  1. PostgreSQL
    1.1. Physical Replication only works with same Major Version -> No Rolling Upgrade without additions
  2. Docker Swarm 
    2.1. 1 Service 1 Image (there is a workaround but that makes the deployment confusing)
    2.2. Service Ingress Ports are global (so no 2nd deployment with same port possible)
    2.3. "volumes" in Docker Swarm are locally mountet and not shared accross hosts (So Upgrading has to be done at each host with a PostgreSQL on it.)
  3. Docker
    3.1. Container PID 1 cannot be stopped or the container dies (But this is needed in order to upgrade the database -> Stop, Upgrade, Restart with new data and binary directories)
- Solutions
  - In Place Upgrades in running containers (or alternatively extra upgrade container)
    Pro: Close to zero Downtime possible, Nutzt lokal gespeicherte Datenbank (schnellerer Start nach Upgrade)
    Con: Needs Internet during Upgrade, Additional SQL request neccessary to determine database version (SELECT version();), Bei Container Ausfall start der alten Version (da immernoch altes Image)
    Status: Implemented
    Upgrade Sequence:
      - External Upgrader Process starts
      - Upgrade each subscriber like:
        - SSH in Container
        - Install new PostgreSQL Version
        - Stop PostgreSQL
        - Upgrade Datenbank
        - Start PostgreSQL mit neuer Datenbank
      - Upgrade Provider like:
        - Fahre aktuellen Master "smart" herunter
        - Mache Keepalived eines Subscribers zum Keepalived Master -> Bekommt VIP & befördert lokale DB
        - Reconnecte alle Subscriber zum neuen Master
        - Upgrade alten Master wie Subscriber
      - Done
  - 3 Phase Upgrade, Shutdown old version, start new version (!= Blue/Green Deployment)
    Pro: Einfach, Eine Postgres Version pro Stack
    Con: Mehr Downtime als bei der ersten Variante
    Status: Rejected (To much downtime)
  - NEU! Rolling Upgrade mit seperaten Upgrade und nachfolge Service.
    Pro: Smoother than Solution 1 and may not needed second exposed port via Ingress (see Con), does not need Internet during Upgrade
    Con: Only one service is allowed to export via ingress, so in this case all ports are exposed locally and PostgreSQL is accessed via LoadBalancer that knows all IPs. Must get current state via pg_basebackup and replication.
    Status: In Implementation
    Upgrade Sequence (variations possible, f.e. replace old provider with new one as soon as possible):
      - External Upgrader Process starts
      - Upgrade each subscriber like:
        - Shutdown old subscriber (old service, image)
        - Start new subscriber (new service, image)
          - Get current State via pg_basebackup and logical replication 
      - Upgrade Provider like:
        - Fahre aktuellen Master "smart" herunter
        - Mache Keepalived eines Subscribers zum Keepalived Master -> Bekommt VIP & befördert lokale DB
        - Reconnecte alle Subscriber zum neuen Master
        - Starte neuen Subscriber
      - Done
- Testbed
  - 2 VirtualBox VMs
  - CentOS 7
  - 1 Provider / 1 Subscriber
- Testszenarios
  - TODO
- Tool
  - Hilft beim hoch- / herunterfahren des Testbeds in 3 Stufen (VMs, Docker, Postgres)
  - Vereinfacht häufig genutzte Interaktion mit VMs, Docker, Postgres, Keepalived (z.b. lesen von Logs)
  - Startet Testszenarios
- Conclusion

### Inhaltliche Ordnung

- Zeiten dürfen jeder Zeit geändert werden, wichtig ist nur, dass die Präsentation unter 60 Minuten bleibt.
- Problem (30 Minuten):
  - Intro (2 Minuten)
    - Was ist die Aufgabe?
  - Context (11 Minuten)
    - Was ist vorhanden (z.b. HA Cluster)?
    - Wie macht man Upgrade in HA Environment?
    - Was ist Zerodown time, Rolling Upgrade, Blue/Green Deployment?
  - Related Work / Existierende Lösungen (10 Minuten)
    - CrunchyData Container: Bereits in Verwendung für normales HA Deployment, allerdings keine Logische Replikation!
    - ClusterControl: Only works with v9.6 or higher.
    - Bucardo (Keine Info zu Upgrade Prozess aber sieht interessant aus, leider zu spät gesehen: https://bucardo.org/Bucardo/index.html)
    - BDR (Kostenpflichtig)
    - Citus (No Info if workes with V9.5)
    - Zalando PO/Spilo/Patroni/Stolon (only works with Kubernetes/Helm)
  - Unsere Anforderungen (7 Minuten)
    - Maintainer ist synonym für uns.
    - Nicht berücksichtigt:
      - (Kunde) Ein wenig Downtime OK, aber soll dann auch laufen. (Konträr zur Aufgabenstellung)
      - (Kunde) Neue Version soll möglichst lange laufen, Performanter sein, oder weitere Vorteile bringen.
    - Must-Have
      - A1 (Aufgabenstellung) Zero Downtime Upgrade
      - A2 (Tech) PostgreSQL limitationen
      - A3 (Tech) Docker (Swarm) limitationen
      - A4 (Kunde) Keine Schwächung der HA-Eigenschaft (z.b. Rolling-Upgrade -> Rollback)
      - A5 (Kunde) Kein Datenverlust
    - Should-Have
      - A6 (Kunde) Keine Internet Connection während Update
      - A7 (Kunde) Unmodifizierte PostgreSQL Container
      - A8 (Maintainer) PostgreSQL Version je Container transparent
      - A9 (Maintainer) Möglichst leicht umzusetzen / zu warten.
    - Nice-To-Have
      - A10 (Kunde) Möglichst geringe Upgradedauer
- Solution (30 Minuten):
  - Überlegte Rolling Upgrade Lösungen (5 Minuten)
    - Externer Mount Upgrader
    - InPlace Upgrade (Nachfolger zum Externen Mount Upgrader)
    - Seperate Services
  - Vergleich zu existierenden Lösungen (5 Minuten)
    - Warum eine eigene Lösung statt eine existierende?
      - TODO Nehme die Folie von Related Work, jetzt aber inklusive Gründe warum die nicht genommenwurden.
    - Welche Lösung wird nun implementiert & getestet?
      - Externer Mount Upgrader
        - Erfüllt alle Anforderungen außer A3, A6, A8, A9
        - Scheiterte an Machbarkeit wegen Docker Limitationen (Neustart nach Upgrade mit altem Container -> nutzt alte Binarys und Daten)
      - InPlace (Done & Tested)
        - Erfüllt alle Anforderungen außer A6, A7, A8, A9, ggf. A10
      - Seperate Services (Wird implementiert)
        - Kam vor 2 Wochen als Idee auf, als InPlace schon fertig war
        - Erfüllt alle Anforderungen außer ggf. A10
  - Testbed (5 Minuten)
    - 2 VirtualBox VMs
      - CentOS 7
      - Docker vTODO
      - PostgreSQL v9.5.18
    - 1 Provider / 1 Subscriber
  - Testszenarios (5 Minuten)
    - Alle Tests starten mit einem Provider und einem Subscriber inklusive Check ob Replikation so funktioniert wie sie soll.
    - Test_1: Prüfe, ob die vom Testtool erkannten Rollen auch die realen Rollen (Provider/Subscriber) sind.
    - Test_2: Prüfe, ob nach Subscriber Crash, neuer Subscriber auch die alten Daten erhält.
    - Test_3: Prüfe, ob nach Provider Crash, neuer Provider tatsächlich von dem Subscriber als Provider erkannt wird.
    - Test_4: Prüfe, ob nach Provider Crash, neuer Provider die alten Daten hat.
    - Up_Test1: Prüfe, ob Major Upgrade eines Subscribers Probleme verursacht (z.b. Crash, Verlust alter Daten)
    - Up_Test2: Prüfe, ob Major Upgrade des Clusters Probleme verursacht (z.b. Crash, Verlust alter Daten)
  - Testtool (5 Minuten)
    - Hilft beim hoch- / herunterfahren des Testbeds in 3 Stufen (VMs, Docker, Postgres)
    - Vereinfacht häufig genutzte Interaktion mit VMs, Docker, Postgres, Keepalived (z.b. lesen von Logs)
    - Startet Testszenarios
    - Live Vorführung?
  - Conclusion (5 Minuten)
    - Erfüllte Anforderungen
    - Zukünftige Arbeit
      - Ausprobieren von Bucardo
      - Eigene Lösung verbessern: Refactoring, mehr Tests (Unit & Integration)
      - Upgrade Dauer und Downtime implementierter Lösungen messen & vergleichen
    - Dokumentation in Confluence, Aktuell noch auf meiner "privaten" Seite.


## TODO
- Eingangsstory?
  - Brainstorming Zuhörer
    - Aus der Stadt
    - INformatiker = Bastler?
    - Debugging, Stress Bug Fix und andere Lagerfeuer Geschichten
    - Sehr viel Kopfarbeit, kaum/kein Körper
    - HomeOffice
    - Internet
    - PCs
    - Studium / Quereinsteiger
  - HotSwarp HDDs
    - Intro
      - Professor erzählte eine Geschichte von IBM
    - Kern
      - Massiver HDD Ausfall
      - Viel geschraube, sehr viel Arbeit
      - Danach Umstellung auf HotSwap
    - Ende / Übergang Präsentation
      - HotSwap könnte auch zum Upgrade verwendet werden
      - wir machen heute Software Zero Downtime Upgrading
- Folieninhalt innerhalb von 10 Sek überblickbar
