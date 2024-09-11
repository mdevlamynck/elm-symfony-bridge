# elm-symfony-bridge

[![Build Status](https://github.com/mdevlamynck/elm-symfony-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/mdevlamynck/elm-symfony-bridge/actions)
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

You can install the webpack plugin with [npm](https://www.npmjs.com/get-npm) or with [yarn](https://yarnpkg.com/getting-started/install):

```bash
# NPM
npm install vite-plugin-elm-symfony-bridge --save-dev

# Yarn
yarn add vite-plugin-elm-symfony-bridge --dev
```

And you're all done!

## Configuration

Setup example with symfony's webpack encore:

```js
import { defineConfig } from "vite";
import symfonyPlugin from "vite-plugin-symfony";
import elmPlugin from 'vite-plugin-elm';
import elmSymfonyBridgePlugin from 'vite-plugin-elm-symfony-bridge';

export default defineConfig({
    plugins: [
        elmPlugin(),
        symfonyPlugin(),
        elmSymfonyBridgePlugin({
            outputFolder: './elm-stuff/generated-code/elm-symfony-bridge'
                                            // Optional: set the folder where to put intermediate build artifacts, defaults to './elm-stuff/generated-code/elm-symfony-bridge'
            projectRoot: './',              // Optional: root folder of your symfony project, defaults to './'
            elmRoot: './assets/elm',        // Optional: root folder of your elm code, defaults to './assets/elm'
            elmVersion: '0.19',             // Optional: elm version the generated code should be compatible with, defaults to '0.19', available '0.19' and '0.18'

            enableRouting: true,            // Optional: enable generating routes, defaults to true
            urlPrefix: '/index.php',        // Optional: when dev is true, which prefix to use when generating urls, defaults to '/index.php' (symfony >= 4 uses '/index.php', symfony < 4 '/app_dev.php')

            enableTranslations: true,       // Optional: enable generating translations, defaults to true
            lang: 'en',                     // Optional: lang to use when exporting translations, defaults to 'en'

            watchFolders: ['src', 'config', 'translations'],
                                            // Optional: which folders to watch for changes that might trigger changes in generated elm code, defaults to ['src', 'config', 'translations']
            watchExtensions: ['php', 'yaml', 'yml', 'xml'],
                                            // Optional: which file extensions to watch for changes that might trigger changes in generated elm code, defaults to ['php', 'yaml', 'yml', 'xml']

            envVariables: {                 // Optional: variables to replace during compile time, will also read env vars
                '%variable%': 'ENV_VAR'
            },
        }),
    ],
    build: {
        rollupOptions: {
            input: {
                app: "./assets/app.js"
            },
        }
    },
});
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

See the [README](../README.md#Hacking) at the root of the project for usefull information when hacking on this project.

## License

elm-symfony-bridge is distributed under the terms of the MIT license.

See [LICENSE](../LICENSE.md) for details.
