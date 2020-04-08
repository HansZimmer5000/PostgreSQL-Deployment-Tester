# Seperate Container

## Problem

To upgrade from one PostgreSQL Version to another this solution uses a seperate container to upgrade the postgresql data. 

## Folder content

This folder contains following contents:
- Folder "gen_docker": Contains files to build a specific docker image to update a docker volume from one version to another.
- Folder "tests": Contains the fildes necessary for testing the solution

## Test

- File .env: Environment Variables for the stack files
- File newstack.yml: The stack/compose file for the new postgres version
- File oldstack.yml: The stack/compose file for the old postgres version
- File test_scenario.sh: Tests for a specific scenario
- File test.sh: The File which can be executed to test if this solution with the seperate container works. 

In test.sh a test can be executed to test if this solution works. Following the steps:
1. Start the PostgreSQL via oldstack.yml
2. Fill the database with sample data
3. Return the counts of a specfic table (if there are 10000 entries step 2 worked)
4. The PostgreSQL Version is shutdown
5. The Volume used by the PostgreSQL is getting updated by the seperate container  
    1. The current 'upgrade' image will be build
    2. This is started directly via docker run
    3. This container ends and so doesn't need to be killed
6. Start the new PostgreSQL via newstack.yml
7. as Step 3
8. Delete the old database files 