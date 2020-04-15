# Seperate Container

## Problem

To upgrade from one PostgreSQL Version to another this solution uses a seperate container to upgrade the postgresql data. 

## Folder content

This folder contains following contents:
- Folder "gen_docker": Contains files to build a specific docker image to update a docker volume from one version to another.
- Folder "tests": Contains the files necessary for testing the solution
