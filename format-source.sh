#!/bin/sh -x

script=$(readlink -f "$0")
path=$(dirname "$script")

haxelib run formatter -s $path/src/amqp/
haxelib run formatter -s $path/macro-src/
