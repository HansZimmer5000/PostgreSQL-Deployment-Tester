# Testszenarios

## Normal Tests

1. Check if roles of Postgres are really what they are
2. TODO

## Major Upgrade Tests

Lower/Default Version: 9.5.18
Higher Major Version: 10.12

0. Major Upgrade of Postgres (in /upgrade/tests/simple_test.sh)
1. Major Upgrade of running Subscriber
2. Higher Provider, lower Subscriber, execute normal tests again? 
3. Lower Provider, higher Subscriber, execute normal tests again?
4. Major Update of Cluster (How much downtime?)
    - Update Subscriber
    - Promote Subscriber
    - Update Provider
    - Degrade Provider


