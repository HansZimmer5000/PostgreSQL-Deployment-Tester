# Tests

- File .env.sh: Environment Variables for the stack files
- File newstack.yml: The stack/compose file for the new postgres version
- File oldstack.yml: The stack/compose file for the old postgres version
- File test_scenario.sh: Executes an upgrade scenario with specific versions (e.g. 9.5 to 10).
- File simple_test.sh: This file acts as an wrapper to "test_scenario.sh". It abstracts the output and returns if the test was succesfull. It can do multiple scenarios sequentially.

In test.sh a test scenario can be executed, it follows this steps:
1. Start the PostgreSQL via oldstack.yml
2. Fill the database with sample data
3. Return the counts of a specfic table (if there are 10000 entries step 2 worked)
4. The PostgreSQL Version is shut down
5. The Volume used by the PostgreSQL is getting updated by the seperate container  
    1. The current 'upgrade' image will be build
    2. This is started directly via docker run
    3. This container ends and so doesn't need to be killed
6. Start the new PostgreSQL via newstack.yml
7. as Step 3
8. Delete the old database files 