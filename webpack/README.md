# elm-symfony-bridge

[![Build Status](https://travis-ci.org/mdevlamynck/elm-symfony-bridge.svg?branch=master)](https://travis-ci.org/mdevlamynck/elm-symfony-bridge)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/mdevlamynck/elm-symfony-bridge/issues)
[![webpack plugin](https://img.shields.io/npm/v/elm-symfony-bridge?label=webpack%20plugin&logo=webpack%20plugin)

Webpack plugin exposing symfony's translations and routing to elm.

## Table of content

* [Installation](#Installation)
* [Configuration](#Configuration)
* [Usage](../doc/Usage.md)
* [Versioning](#Versioning)
* [Contributing](#Contributing)
* [Hacking](#Hacking)
* [License](#License)

## Installation

You can install the webpack plugin with [npm](https://www.npmjs.com/get-npm):

```bash
npm install elm-symfony-bridge --save-dev
```

The usage example bellow also uses `@symfony/webpack-encore` and `elm-webpack-loader` which you can install with:

```bash
npm install @symfony/webpack-encore --save-dev
npm install elm-webpack-loader --save-dev
```

## Configuration

Setup example with symfony's webpack encore:

```js
const Encore = require('@symfony/webpack-encore');
const ElmSymfonyBridgePlugin = require('elm-symfony-bridge');

Encore
    .setOutputPath('public/static')
    .setPublicPath('/static')
    .addEntry('app', './assets/app.js')
    .addLoader({
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: {
            loader: 'elm-webpack-loader',
            options: {
                pathToElm: 'node_modules/.bin/elm',
                debug: !Encore.isProduction(),
                optimize: Encore.isProduction()
            }
        }
    })
    .addPlugin(new ElmSymfonyBridgePlugin({
        dev: !Encore.isProduction(),    // Required: use symfony's env=dev or env=prod
        outputFolder: 'public',         // Optional: set the folder where content is generated, defaults to 'public' (symfony >= 4 uses 'public', symfony < 4 'web')
        elmRoot: './assets/elm',        // Optional: root folder of your elm code, defaults to './assets/elm'
        elmVersion: '0.19',             // Optional: elm version the generated code should be compatible with, defaults to '0.19', available '0.19' and '0.18'

        enableRouting: true,            // Optional: enable generating routes, defaults to true
        urlPrefix: '/index.php',        // Optional: when dev is true, which prefix to use when generating urls, defaults to '/index.php' (symfony >= 4 uses '/index.php', symfony < 4 '/app_dev.php')

        enableTranslations: true,       // Optional: enable generating translations, defaults to true
        lang: 'en',                     // Optional: lang to use when exporting translations, defaults to 'en'
    }))
    .configureFilenames({
        js: '[name].[chunkhash].js',
        css: '[name].[chunkhash].css',
        images: 'images/[name].[ext]',
        fonts: 'fonts/[name].[ext]',
    })
    .enableVersioning()
    .enableSourceMaps(!Encore.isProduction())
    .cleanupOutputBeforeBuild()
;

module.exports = Encore.getWebpackConfig();
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

As a reminder, all contributors are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Hacking

The sources are organized in 3 main folders:

* `/` the root contains the elm code: `src` for the sources and `tests` for the elm tests.
* `/webpack` contains all the specifics for the webpack plugin (you are here).
* `/parcel` contains all the specifics for the parcel plugin.

This project uses the following tools for development:

* [npm](https://www.npmjs.com/)
* [elm](https://elm-lang.org/)
* [elm-test](https://github.com/rtfeldman/node-test-runner)
* [elm-verify-examples](https://github.com/stoeffel/elm-verify-examples)

You'll find the following commands useful when hacking on this project (assuming you're at the root of the repository and this in this folder):

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

See [LICENSE](../LICENSE.md) for details.
