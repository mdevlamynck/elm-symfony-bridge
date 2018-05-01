# elm-symfony-bridge

[![Build Status](https://travis-ci.org/mdevlamynck/elm-symfony-bridge.svg?branch=master)](https://travis-ci.org/mdevlamynck/elm-symfony-bridge)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/mdevlamynck/elm-symfony-bridge/issues)

Webpack plugin exposing to elm symfony's translations and routing.

## Status

This project is usable and mostly feature complete but still a bit rough around the edges.

If you encounter invalid generated elm code or wrong behaviour please fill a bug report.

Help to enhance the webpack code is welcomed, especially around error handling.

## Installation

Install the plugin with:

```bash
npm install elm-symfony-bridge --save
```

The usage example bellow also uses:
```bash
npm install @symfony/webpack-encore --save
npm install elm-webpack-loader --save
```

## Usage

Setup example with symfony's webpack encore:

```js
const Encore = require('@symfony/webpack-encore');
const ElmSymfonyBridgePlugin = require('elm-symfony-bridge');

Encore
    .setOutputPath('web/static')
    .setPublicPath('/static')
    .addEntry('app', './assets/app.js')
    .addLoader({
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: {
            loader: 'elm-webpack-loader',
            options: {
                pathToMake: 'node_modules/.bin/elm-make',
                warn: true,
                debug: !Encore.isProduction()
            }
        }
    })
    .addPlugin(new ElmSymfonyBridgePlugin({
        dev: !Encore.isProduction(),    // Required: use symfony's env=dev or env=prod
        elmRoot: './assets/elm',        // Optional: root folder of your elm code, defaults to '/assets/elm'
        urlPrefix: '/app_dev.php',      // Optional: when dev is true which prefix to use when generating urls, defaults to '/app_dev.php'
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

## Hacking

You'll find the following commands useful when hacking on this project:

```bash
# build the package
npm build

# run the tests
elm test

# Using a local build in a project using webpack
npm build & npm pack
cd path/to/project/using/webpack
npm install path/to/package.tgz
```
