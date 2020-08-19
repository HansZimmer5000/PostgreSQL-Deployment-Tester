#!/bin/sh

cd helper_scripts
bats *.bats

cd ../helper_scripts
bats *.bats

cd ..