#!/bin/sh

cd helper_scripts
bats *.bats

cd ../helper_scripts
bats *.bats

cd ../keepalived
bats *.bats

cd ../postgres
bats *.bats

cd ..