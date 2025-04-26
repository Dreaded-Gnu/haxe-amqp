#!/bin/sh
rm -f amqp.zip
zip -r amqp.zip src thirdparty README.md CHANGELOG.md LICENSE.md haxelib.json extraParams.hxml -x thirdparty/promises/.git
haxelib submit amqp.zip
