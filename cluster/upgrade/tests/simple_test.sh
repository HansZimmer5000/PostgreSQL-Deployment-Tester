#!/bin/sh
set +x

# Loop with Old_versions and New_versions and dynamic creation of the log files and checking these is not so hard but not worth the effort as not so much test are be done.

# CONSTANTS / HELPER
RED='\033[1;31m'
GREEN='\033[1;32m'
BLANK='\033[0m'

clean_up_logs() {
    rm *.log
}

test() {
    if $LOG_INTO_LOGFILE; then
        ./test_scenario.sh $1 $2 > $3.log

        echo # New Line
        echo "Checking the result Logs"

        if [ $(cat $3.log | grep -o "Content seems correct" | wc -l) -gt 1 ]; then
            echo -e "Test '$3' was ${GREEN} successfull! ${BLANK}"
        else
            echo -e "Test '$3' was ${RED} NOT ${BLANK} successfull!"
        fi
    else
        echo ""
        echo -e "BEWARE Log is not saved into file -> ${RED} no checking of the result! ${BLANK}"
        ./test_scenario.sh $1 $2
    fi
    clean_up_logs
    rm -rf ./vol/
}

# VARIABLES / SCRIPT

LOG_INTO_LOGFILE=$1
if [ -z "$LOG_INTO_LOGFILE" ]; then
	LOG_INTO_LOGFILE=true
fi

clean_up_logs

test 9.5 10 95_to_10
#test 10 11 10_to_11
#test 9.5 11 95_to_11
#test 9.5 12 95_to_12