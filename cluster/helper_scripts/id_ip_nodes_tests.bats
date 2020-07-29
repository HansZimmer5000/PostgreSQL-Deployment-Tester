#!/usr/bin/env bats

source ./id_ip_nodes.sh

@test 'Test extract_db_version' {
    expected="9.5.18"
    result=$(extract_db_version "                                                  version                    
                                            
--------------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 9.5.18 on x86_64-pc-linux-gnu (Debian 9.5.18-1.pgdg90+1), compiled by gcc (Deb
ian 6.3.0-18+deb9u1) 6.3.0 20170516, 64-bit
(1 row)
")
    echo $result
    [ "$expected" == "$result" ]
}

