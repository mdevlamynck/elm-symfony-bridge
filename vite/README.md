# elm-symfony-bridge

[![Build Status](https://travis-ci.org/mdevlamynck/elm-symfony-bridge.svg?branch=master)](https://travis-ci.org/mdevlamynck/elm-symfony-bridge)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/mdevlamynck/elm-symfony-bridge/issues)
[![vite plugin](https://img.shields.io/npm/v/vite-plugin-elm-symfony-bridge?label=vite%20plugin&logo=vite%20plugin)](https://www.npmjs.com/package/vite-plugin-elm-symfony-bridge)

Vite plugin exposing symfony's translations and routing to elm.

## Table of content

* [Quick start](#quick-start)
* [Installation](#Installation)
* [Configuration](#Configuration)
* [Usage](../doc/Usage.md)
* [Versioning](#Versioning)
* [Contributing](#Contributing)
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

## Installation

You can install the vite plugin with [npm](https://www.npmjs.com/get-npm):

```bash
npm install vite-plugin-elm-symfony-bridge --save-dev
```

or with [yarn](https://yarnpkg.com/getting-started/install):

```bash
yarn add vite-plugin-elm-symfony-bridge --dev
```

And you're all done!

## Configuration

This plugin follows vite's zero-config philosophy and will automatically configure itself. You should be able to mostly ignore this section but if you really need to tweak something, here is the config along with the rules used to infer each value:

* `watch`: Do we watch for changes to regenerate elm code? (defaults to vite's own watch value, true for serve, false for build)
* `watchFolders`: Which folders to watch (defaults to `src`, `app`, `config`, `translations`)
* `watchExtensions`: Which file extensions to watch (defaults to `php`, `yaml`, `yml`, `xml`)
* `dev`: Use symfony's env=dev or env=prod (defaults to vite's own dev value, true for serve, false for build)
* `projectRoot`: Path to the root of your symfony project (defaults to `./`)
* `elmRoot`: Where to put generated code (defaults to `./assets/elm`)
* `outputFolder`: Where to put intermediate build artifacts (defaults to `./elm-stuff/generated-code/elm-symfony-bridge`)
* `elmVersion`: Elm version the generated code should be compatible with (defaults to 0.19)
* `enableRouting`: Enable generating routes (defaults to true)
* `urlPrefix`: When dev is true, which prefix to use when generating urls (defaults to `/index.php` or `/app_dev.php` depending on which is found)
* `enableTranslations`: Enable generating translations (defaults to true)
* `lang`: Lang to use when exporting translations (defaults to 'en')
* `envVariables`: Variables to replace during compile time, will also read env vars

If these rules don't work for you, you can override any of these parameters in your `package.json` under the `elm-symfony-bridge` key like so:

```json
{
  "elm-symfony-bridge": {
    "enableRouting": false,
    "lang": "fr"
  },
}
```

## Usage

See [Usage](../doc/Usage.md).

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

As a reminder, all contributors are expected to follow our [Code of Conduct](../CODE_OF_CONDUCT.md).

## Hacking

The sources are organized in 4 main folders:

* `/` the root contains the elm code: `src` for the sources and `tests` for the elm tests.
* `/webpack` contains all the specifics for the webpack plugin.
* `/parcel` contains all the specifics for the parcel plugin.
* `/vite` contains all the specifics for the vite plugin (you are here).

This project uses the following tools for development:

* [yarn](https://yarnpkg.com/)
* [elm](https://elm-lang.org/)
* [elm-test](https://github.com/rtfeldman/node-test-runner)
* [elm-verify-examples](https://github.com/stoeffel/elm-verify-examples)

You'll find the following commands useful when hacking on this project:

```bash
# build the package
yarn run build

# run the tests and doc tests
yarn run test

# Using a local build in a project using vite
yarn install && yarn run build && yarn pack # build a package.tgz
cd path/to/project/using/vite               # go in the root directory of your project
yarn install path/to/package.tgz            # install the locally built package
```

## License

elm-symfony-bridge is distributed under the terms of the MIT license.

See [LICENSE](../LICENSE.md) for details.
