#!/bin/sh
rm -f amqp.zip
zip -r amqp.zip src macro-src README.md CHANGELOG.md LICENSE.md haxelib.json extraParams.hxml -x src/promises/.git
haxelib submit amqp.zip
