#!/bin/sh

cd test_scripts
bats *.bats

cd ../setup_scripts
bats *.bats

cd ../keepalived
bats *.bats

cd ../postgres
bats *.bats

cd ..