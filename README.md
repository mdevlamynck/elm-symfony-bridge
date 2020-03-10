# elm-symfony-bridge

[![Build Status](https://travis-ci.org/mdevlamynck/elm-symfony-bridge.svg?branch=master)](https://travis-ci.org/mdevlamynck/elm-symfony-bridge)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/mdevlamynck/elm-symfony-bridge/issues)
[![webpack plugin](https://img.shields.io/npm/v/elm-symfony-bridge?label=webpack%20plugin&logo=webpack%20plugin)](https://www.npmjs.com/package/elm-symfony-bridge)
[![parcel plugin](https://img.shields.io/npm/v/parcel-plugin-elm-symfony-bridge?label=parcel%20plugin&logo=parcel%20plugin)](https://www.npmjs.com/package/parcel-plugin-elm-symfony-bridge)

Webpack and Parcel plugin exposing Symfony's translations and routing to Elm. 
The translations are available through the `Trans.<domain>` Elm module and the routing is available through the `Routing` Elm module.

For more information see [Webpack](webpack/README.md) or [Parcel](parcel/README.md) specific documentation.

## Table of content

* [Quick start](#quick-start)
* [Webpack](webpack/README.md)
    - [Installation](webpack/README.md#Installation)
    - [Configuration](webpack/README.md#Configuration)
* [Parcel](parcel/README.md)
    - [Installation](parcel/README.md#Installation)
    - [Configuration](parcel/README.md#Configuration)
* [Usage](doc/Usage.md)
* [Versioning](#versioning)
* [Contributing](#contributing)
* [Hacking](#Hacking)
* [License](#License)

## Quick Start

Translations are exposed using the `Trans.<domain>` module like following:

```elm
import Trans.Messages as Messages
import Trans.Security as Security

displayStuff : Html msg
displayStuff = 
    div [] [ text Messages.alert_awesome_plugin ]
    div [] [ text Security.global_must_have ]
```

The routing is exposed using the `Routing` module like following:

```elm
import Http
import Routing

makeHttpCall : Cmd msg
makeHttpCall =
    Http.get 
        { url = Routing.app_get_this_plugin
        , expect = Http.expectString MsgGetThisPlugin
        }
```

## Usage

See [Usage](doc/Usage.md).

## Versioning

elm-symfony-bridge follows [semantic versioning](https://semver.org/). In short the scheme is MAJOR.MINOR.PATCH where
1. MAJOR is bumped when there is a breaking change,
2. MINOR is bumped when a new feature is added in a backward-compatible way,
3. PATCH is bumped when a bug is fixed in a backward-compatible way.

Versions bellow 1.0.0 are considered experimental and breaking changes may occur at any time.

## Contributing

Contributions are welcomed! There are many ways to contribute, and we appreciate all of them. Here are some of the major ones:

* [Bug Reports](https://github.com/mdevlamynck/elm-symfony-bridge/issues): While we strive for quality software, bugs can happen and we can't fix issues we're not aware of. So please report even if you're not sure about it or just want to ask a question. If anything the issue might indicate that the documentation can still be improved!
* [Feature Request](https://github.com/mdevlamynck/elm-symfony-bridge/issues): You have a use case not covered by the current api? Want to suggest a change or add something? We'd be glad to read about it and start a discussion to try to find the best possible solution.
* [Pull Request](https://github.com/mdevlamynck/elm-symfony-bridge/pulls): Want to contribute code or documentation? We'd love that! If you need help to get started, GitHub as [documentation](https://help.github.com/articles/about-pull-requests/) on pull requests. We use the ["fork and pull model"](https://help.github.com/articles/about-collaborative-development-models/) were contributors push changes to their personnal fork and then create pull requests to the main repository. Please make your pull requests against the `master` branch.

As a reminder, all contributors are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Hacking

The sources are organized in 3 main folders:

* `/` the root contains the elm code: `src` for the sources and `tests` for the elm tests.
* `/webpack` contains all the specifics for the webpack plugin.
* `/parcel` contains all the specifics for the parcel plugin.

This project uses the following tools for development:

* [npm](https://www.npmjs.com/)
* [elm](https://elm-lang.org/)
* [elm-test](https://github.com/rtfeldman/node-test-runner)
* [elm-verify-examples](https://github.com/stoeffel/elm-verify-examples)

You'll find the following commands useful when hacking on this project:

```bash
# build the package
npm run build

# run the tests and doc tests
npm run test

# Using a local build in a project using webpack
cd webpack && npm install && npm run build && npm pack # build a package.tgz
cd path/to/project/using/webpack                       # go in the root directory of your project
npm install path/to/package.tgz                        # install the locally built package

# Using a local build in a project using parcel
cd parcel && npm install && npm run build && npm pack # build a package.tgz
cd path/to/project/using/webpack                      # go in the root directory of your project
npm install path/to/package.tgz                       # install the locally built package
```

## License

elm-symfony-bridge is distributed under the terms of the MIT license.

See [LICENSE](LICENSE.md) for details.
