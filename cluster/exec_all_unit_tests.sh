#!/bin/sh

cd helper_scripts
bats *.bats
cd ..

cd setup_scripts
bats *.bats
cd ..

cd tests_scripts
bats *.bats
cd ..