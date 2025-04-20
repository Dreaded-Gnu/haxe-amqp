#!/bin/sh
rm -f amqp.zip
mv LICENSE.md LICENSE.md.bak
cat LICENSE.md.bak src/promises/LICENSE > LICENSE.md
zip -r amqp.zip src macro-src README.md CHANGELOG.md LICENSE.md haxelib.json extraParams.hxml
rm LICENSE.md
mv LICENSE.md.bak LICENSE.md
haxelib submit amqp.zip
