#!/bin/sh

build_images(){
    docker build ../custom_image -f ../custom_image/9.5.18.dockerfile -t mypglog:9.5
    docker build ../custom_image -f ../custom_image/10.13.dockerfile -t mypglog:10
}