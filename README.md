# PostgreSQL-Deployment-Tester

This program does two things:
1. The program deploys a PostgreSQL cluster via Docker Swarm onto VirtualBox VMs.
2. The program can interact with the deployed cluster. 
  - To manually force failure and see how the deployment reacts to that
  - To execute the pre defined automated tests
  
## TODO

As this is a Work in Progress there are currently alot of limitations. Each of them will be addressed if there is time according to their priority (MUST > SHOULD > NICE-to-have)

- Deployment
  - (NICE) Only works fully with VirtualBox
  - (NICE) Only works with Docker Swarm
- Testing
  - (MUST) There are only four pre defined tests
  - (SHOULD) Only can interact and test with current configuration
- Implementations
  - (SHOULD) The code is in a bad shape in terms of test coverage (none), readability and flakiness
