# How to contribute

It's important to us that you feel you can contribute towards the evolution of haxe-amqp. This can take many forms: from helping to fix bugs or improve the docs, to adding in new features to the source. This guide should help you in making that process as smooth as possible.

Before contributing, please read the [Code of Conduct](.github/CODE_OF_CONDUCT.md) which is adapted from [Contributor Covenant, version 2.1](https://www.contributor-covenant.org/version/2/1).

## Reporting issues

To report a bug, request a feature or simply ask a question, make use of GiHub Issues section for [Issues](https://github.com/Dreaded-Gnu/haxe-amqp/issues). When submitting an issue please take care of the following steps

1. **Search for already existing issues.** Your question or bug may already have been answered or fixed. Be sure to search issues first before putting in a possible duplicate issue.

2. **Create an isolated and reproducible test case.** If you are reporting a bug, make sure you also have a minimal, runnable, code example that reproduces the problem you have. That makes it easier to fix something.

3. **Share as much information as possible.** Include browser version affected, your OS, version of the library, steps to reproduce as also written within issue template. Something like "X isn't working!!!1!" will probably just be closed.

## Contributing changes

### Setting up

To setup for making changes you'll need to take a few steps, we've outlined below.

1. Ensure that haxe is installed
2. Fork the haxe-amqp repository
3. Run `haxelib newrepo`
4. Run `haxelib install format`
5. Run `haxelib install formatter`
6. Run `haxelib install hxcpp`
7. Run `haxelib install utest`
8. Run `haxelib install emitter`
9. Run `haxelib install dox`
10. Run `haxelib install uuid`

### Making a change

Once the repository has been checked out and everything has been prepared, you're almost ready to make a change. The last point to be done before you start is checking out the correct branch for the change itself. Which branch shall be used depends on the type of change you're going to do.

Short branch breakdown

- `master` - Make your change at the `master` branch in case that it is an *urgent* hotfix
- `develop` - Make your change at the `develop` branch, when it's a *non-urgent* bugfix or feature.

The change should be made directly to the correct branch within your fork or to a branch, branched from the correct branch listed above. Also ensure, that there is an issue existing for the change you want to submit.

### Testing Your change

You can test your change by adjusting the `Main.hx` temporarily and then run `npm start` or `openfl test html5 -debug -verbose`.

### Submitting Your change

After you've made and tested the change, commit and push it to the fork. Then open a Pull Request from your fork to the main repository on the branch you used in `Making a change`.

Once all discussions have been completed, and the related issue is scheduled within the current milestone, the pull request is going to be merged.

## Code style guide

- Use 2 spaces for tabs, never tab characters.
- No trailing whitespace and consecutive blank lines, blank lines should have no whitespace.
- Follow conventions already in the code.
- Use haxe formatter to format your code after you're done with changes: `haxelib run formatter -s src`

## Contributor Code of Conduct

[Code of Conduct](.github/CODE_OF_CONDUCT.md) is adapted from [Contributor Covenant, version 2.1](https://www.contributor-covenant.org/version/2/1)

## Post scriptum

Thanks to the author who created the original [Pixi.js](https://github.com/pixijs/pixi.js) contributing file which we adapted for this project.
