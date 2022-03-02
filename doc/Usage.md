# Usage

This project generates a `Routing` module and a `Trans.<domain>` module for each translation domain. They will contain functions defined from your routing and translations. The idea is that if you update your symfony code, the changes will reflect the generated elm code, helping you keep your frontend in sync with your backend.

## Routing

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

## Translations

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

user_status:
    keyname:
        connected: "Connected"
        away: "Away"
        do_not_disturb: "Do not disturb"
        disconnected: "Disconnected"
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


-- Keyname translation
userStatusView :  Maybe User -> Html msg
userStatusView user =
    case user of
        Just { status } ->
            div []
                [ text (Trans.user_status_keyname status) ]
        Nothing ->
            div []
                [ text Trans.user_status_keyname_disconnected ]
```

As you can see, for each translation a function is created, named after the translation path in the yaml. So `form.signup.username` becomes `form_signup_username`. Only letters, numbers and `_` will appear in the function name, any other character will be replaced with a `_`.

Variables are also supported. A variable name must be enclosed in `%` to distinguish it from the rest of the text. You will have to provide a `String` value for each variable in a record. There is a special case for the variable `%count%`. If it is present, you will have to pass an `Int` as the first argument of the translation function instead of passing it in a record.

It also supports variants to handle plural rules. The special variable `%count%` is used to choose the correct variant. See the [symfony documentation on pluralization](https://symfony.com/doc/current/components/translation/usage.html#pluralization) for more details on pluralization.

Finally if there is a `keyname` in the translation path, an extra function is created accepting a keyname variable to choose the translation. This is for convenience and should be used with care, if the keyname does not match any translation the function returns an empty string.

## Replace variable during compile time

Variables can be resolved at compile time using the `envVariables` option :

```
envVariables: {
    '{site_name}': 'SITE_NAME', // example of variable in routing
    '%site_name%': 'SITE_NAME', // example of variable in translation
}
```

Values are read from `./.env.local` or `./env` :

```
SITE_NAME=value
```
