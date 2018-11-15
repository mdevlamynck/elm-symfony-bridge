# elm-symfony-bridge

[![Build Status](https://travis-ci.org/mdevlamynck/elm-symfony-bridge.svg?branch=master)](https://travis-ci.org/mdevlamynck/elm-symfony-bridge)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/mdevlamynck/elm-symfony-bridge/issues)

Webpack plugin exposing symfony's translations and routing to elm.

## Table of content

* [Installation](#Installation)
* [Configuration](#Configuration)
* [Usage](#Usage)
* [Versioning](#Versioning)
* [Contributing](#Contributing)
* [Hacking](#Hacking)
* [License](#License)

## Installation

You can install the plugin with [npm](https://www.npmjs.com/get-npm):

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
                pathToMake: 'node_modules/.bin/elm-make',
                debug: !Encore.isProduction()
                optimize: Encore.isProduction()
            }
        }
    })
    .addPlugin(new ElmSymfonyBridgePlugin({
        dev: !Encore.isProduction(),    // Required: use symfony's env=dev or env=prod
        elmRoot: './assets/elm',        // Optional: root folder of your elm code, defaults to '/assets/elm'
        elmVersion: '0.19',             // Optional: elm version the generated code should be compatible with, defaults to '0.19', available '0.19' and '0.18'
        urlPrefix: '/index.php',        // Optional: when dev is true which prefix to use when generating urls, defaults to '/index.php' (symfony >= 4 uses 'index.php', symfony < 4 'app_dev.php')
        lang: 'en',                     // Optional: lang to use when exporting translations, defaults to 'en'
        enableRouting: true,            // Optional: enable generating routes, defaults to true
        enableTranslations: true,       // Optional: enable generating translations, defaults to true
        outputFolder: 'public',         // Optional: set the folder where content is generated, defaults to 'public' (symfony >= 4 uses 'public', symfony < 4 'web')
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

This project generates a `Routing` module and a `Trans.<domain>` module for each translation domain. They will contain functions defined from your routing and translations. The idea is that if you update your symfony code, the changes will reflect the generated elm code, helping you keep your frontend in sync with your backend.

### Routing

Given this routing:

```yaml
user_profile:
    path: /
    controller: App\Controller\UserController::getMyProfile

blog_post:
    path: /api/blog/{slug}
    controller: App\Controller\BlogController::getPost

friend_profile:
    path: /api/friend/{id}/profile
    controller: App\Controller\UserController::getFriendProfile
    requirements:
        id: '\d+'
```

You can use them in elm like this:

```elm
module MyElmModule exposing (..)

import Http
import Json.Decode as Json
import Routing


type Msg
    = GotUserProfile (Result Http.Error Json.Value)
    | GotFriendProfile (Result Http.Error Json.Value)
    | GotBlogPostContent (Result Http.Error Json.Value)


-- Constant route
getUserProfile : Cmd Msg
getUserProfile =
    Http.get
        { url = Routing.user_profile
        , expect = Http.expectJson GotUserProfile Json.value
        }


-- Route with a variable
getBlogPost : String -> Cmd Msg
getBlogPost slug =
    Http.get
        { url = Routing.user_profile { slug = slug }
        , expect = Http.expectJson GotBlogPost Json.value
        }


-- Route with an id
getFriendProfile : Int -> Cmd Msg
getFriendProfile friendId =
    Http.get
        { url = Routing.friend_profile { id = friendId }
        , expect = Http.expectJson GotFriendProfile Json.value
        }
```

The function name is based on the route name, any characters other than letters, numbers and `_` are converted to `_`. If needed, the function takes as argument a record containing a `String` value for each of the variables in the url. One special case, if you specify the requirement `'\d+'` on a variable, the function will expect an `Int` for that variable. This special case is very usefull to pass ids.

### Translations

Given these translations:

```yaml
form:
    signup:
        username: "Your user name"
        email: "Your email"
        password: "Your password"
    success: "Welcome %username%!"

notifications:
    new_messages: "You have one new message.|You have %count% new messages."
    new_messages_from: "You have one new message from %friend_username%.|You have %count% new messages from %friend_username%."
```

You can use them in elm like this:

```elm
module MyElmModule exposing (..)

import Html exposing (div, form, input, text)
import Html.Attributes exposing (placeholder)
import Trans.Messages as Trans


-- Constant translations
signupFormView : Html msg
signupFormView =
    form []
        [ input [ placeholder Trans.form_signup_username ] []
        , input [ placeholder Trans.form_signup_email ] []
        , input [ placeholder Trans.form_signup_password ] []
        ]


-- Translation with a variable
successBannerView : { username : String } -> Html msg
successBannerView user =
    div []
        [ text (Trans.form_success { username = user.username }) ]


-- Translations with several variants to accomodates plural rules.
-- The first parameter is an Int used to choose the correct variant.
newMessagesView : Int -> Html msg
newMessagesView nbNewMessages =
    div []
        [ text (Trans.notifications_new_messages nbNewMessages) ]


-- Same with an extra variable
newMessagesView : Int -> String -> Html msg
newMessagesView nbNewMessages friendName =
    div []
        [ text (Trans.notifications_new_messages nbNewMessages { friend_username = friendName }) ]
```

As you can see, for each translation a function is created, named after the translation path in the yaml. So `form.signup.username` becomes `form_signup_username`. Only letters, numbers and `_` will appear in the function name, any other character will be replaced with a `_`.

Variables are also supported. A variable name must be enclosed in `%` to distinguish it from the rest of the text. You will have to provide a `String` value for each variable in a record. There is a special case for the variable `%count%`. If it is present, you will have to pass an `Int` as the first argument of the translation function instead of passing it in a record.

Finally, it supports variants to handle plural rules. The special variable `%count%` is used to choose the correct variant. See the [symfony documentation on pluralization](https://symfony.com/doc/current/components/translation/usage.html#pluralization) for more details on pluralization.

## Versioning

elm-symfony-bridge follows [semantic versioning](https://semver.org/). In short the scheme is MAJOR.MINOR.PATCH where
1. MAJOR is bumped when there is a breaking change,
2. MINOR is bumped when a new feature is added in a backward-compatible way,
3. PATCH is bumped when a bug is fixed in a backward-compatible way.

Versions bellow 1.0.0 are considered experimental and breaking changes may occur at any time.

## Contributing

Contributions are welcomed! There are many ways to contribute, and we appreciate all of them. Here are some of the major ones:

* [Bug Reports](https://github.com/chaplean/elm-symfony-bridge/issues): While we strive for quality software, bugs can happen and we can't fix issues we're not aware of. So please report even if you're not sure about it or just want to ask a question. If anything the issue might indicate that the documentation can still be improved!
* [Feature Request](https://github.com/chaplean/elm-symfony-bridge/issues): You have a use case not covered by the current api? Want to suggest a change or add something? We'd be glad to read about it and start a discussion to try to find the best possible solution.
* [Pull Request](https://github.com/chaplean/elm-symfony-bridge/pulls): Want to contribute code or documentation? We'd love that! If you need help to get started, GitHub as [documentation](https://help.github.com/articles/about-pull-requests/) on pull requests. We use the ["fork and pull model"](https://help.github.com/articles/about-collaborative-development-models/) were contributors push changes to their personnal fork and then create pull requests to the main repository. Please make your pull requests against the `master` branch.

As a reminder, all contributors are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Hacking

This project uses the following tools for developpement:

* [npm](https://www.npmjs.com/)
* [elm](https://elm-lang.org/)
* [elm-test](https://github.com/rtfeldman/node-test-runner)
* [elm-verify-examples](https://github.com/stoeffel/elm-verify-examples)

You'll find the following commands useful when hacking on this project:

```bash
# build the package
npm run build

# run the tests
elm test

# run the doc tests
elm-verify-examples

# Using a local build in a project using webpack
npm install & npm run build & npm pack # build a package.tgz
cd path/to/project/using/webpack       # go in the root directory of your project
npm install path/to/package.tgz        # install the locally built package
```

## License

elm-symfony-bridge is distributed under the terms of the MIT license.

See [LICENSE](LICENSE.md) for details.
