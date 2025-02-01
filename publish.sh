#!/bin/sh
rm -f haxe-amqp.zip
zip -r haxe-amqp.zip src macro-src README.md CHANGELOG.md LICENSE.md haxelib.json extraParams.hxml
haxelib submit haxe-amqp.zip DreadedGnu
