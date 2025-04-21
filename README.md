# amqp

Implementation of amqp 0.9.1 library for haxe.

## running spec generation

```bash
cd spec
haxe --run GenerateDefinition.hx amqp-rabbitmq-0.9.1.json
```

## installation

Using amqp source install.

```bash
haxelib git amqp https://github.com/Dreaded-Gnu/haxe-amqp
```

Using amqp normal install

```bash
haxelib install amqp
```

This project relies heavily on [promises](https://github.com/core-haxe/promises) which is linked as submodule and applied to class path via macro set as haxelib src.

## examples

In order to use examples with docker based rabbitmq from this project you've to generate a set of certificates via `tls-gen`.
