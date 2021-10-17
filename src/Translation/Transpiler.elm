module Translation.Transpiler exposing (transpileToElm, Command, File)

{-| Converts a JSON containing translations from Symfony and turn them into an elm file.

@docs transpileToElm, Command, File

-}

import Dict exposing (Dict)
import Dict.Extra as Dict
import Elm exposing (..)
import Json.Decode exposing (bool, decodeString, dict, errorToString, float, int, map, oneOf, string, succeed, value)
import Result
import Result.Extra as Result
import String.Extra as String
import Translation.IntlIcu.Data as IntlIcu
import Translation.IntlIcu.Transpiler as IntlIcu
import Translation.Legacy.Data as Legacy
import Translation.Legacy.Transpiler as Legacy


{-| Parameters to the transpile command.
-}
type alias Command =
    { name : String
    , content : String
    , version : Version
    , envVariables : Dict String String
    }


{-| Represents a file.
-}
type alias File =
    { name : String
    , content : String
    }


{-| Converts a JSON containing translations to an Elm file.
-}
transpileToElm : Command -> Result String File
transpileToElm command =
    command.content
        |> readJsonContent
        |> Result.map (replaceEnvVariables command.envVariables)
        |> Result.andThen parseTranslationDomain
        |> Result.map (convertToElm command.version)


{-| Represents the content of a JSON translation file.
-}
type alias JsonTranslationDomain =
    { lang : String
    , domain : String
    , translations : Dict String String
    }


{-| A parsed translation file.
-}
type alias TranslationDomain =
    { lang : String
    , domain : String
    , translations : TranslationsInDomain
    }


type TranslationsInDomain
    = IntlIcu (List IntlIcu.Translation)
    | Legacy (List Legacy.Translation)


{-| Extracts from the given JSON the domain and the translations.
-}
readJsonContent : String -> Result String JsonTranslationDomain
readJsonContent =
    decodeString
        ((dict << dict << dict << oneOf)
            [ dict
                (oneOf
                    [ bool
                        |> map
                            (\b ->
                                if b then
                                    "true"

                                else
                                    "false"
                            )
                    , float |> map String.fromFloat
                    , int |> map String.fromInt
                    , string
                    , -- anything else is ignored
                      value |> map (\_ -> "")
                    ]
                )
            , -- Empty translations are allowed
              succeed Dict.empty
            ]
        )
        >> Result.mapError errorToString
        >> Result.andThen
            (Dict.get "translations"
                >> Maybe.andThen dictFirst
                >> Maybe.andThen
                    (\( lang, translations ) ->
                        translations
                            |> dictFirst
                            |> Maybe.map
                                (\( domain, translations_ ) ->
                                    JsonTranslationDomain lang domain translations_
                                )
                    )
                >> Result.fromMaybe "No translations found in this JSON"
            )


replaceEnvVariables : Dict String String -> JsonTranslationDomain -> JsonTranslationDomain
replaceEnvVariables envVariables json =
    let
        replace translation =
            Dict.foldl String.replace translation envVariables
    in
    { json | translations = Dict.map (\k v -> replace v) json.translations }


{-| Parses the translations into usable type.
-}
parseTranslationDomain : JsonTranslationDomain -> Result String TranslationDomain
parseTranslationDomain json =
    if String.endsWith "+intl-icu" json.domain then
        parseTranslationDomainWith json IntlIcu.parseTranslation IntlIcu

    else
        parseTranslationDomainWith json Legacy.parseTranslation <| \t -> Legacy <| t ++ keynameTranslations t


parseTranslationDomainWith : JsonTranslationDomain -> (( String, String ) -> Result String a) -> (List a -> TranslationsInDomain) -> Result String TranslationDomain
parseTranslationDomainWith { lang, domain, translations } parser builder =
    translations
        |> Dict.toList
        |> List.map (\( name, translation ) -> ( normalizeFunctionName name, translation ))
        |> deduplicateKeys
        |> List.map parser
        |> Result.combine
        |> Result.map
            (\translations_ ->
                { lang = lang
                , domain = String.toSentenceCase domain
                , translations = builder translations_
                }
            )


{-| Creates all extra keyname translation functions.
-}
keynameTranslations : List Legacy.Translation -> List Legacy.Translation
keynameTranslations translations =
    translations
        |> groupByKeyname
        |> Dict.toList
        |> List.map createAKeynameTranslation


{-| Groups together functions with a common same name from the beginning up to `_keyname_`.
Filters out functions not containing `_keyname_` in their name.
-}
groupByKeyname : List Legacy.Translation -> Dict String (List Legacy.Translation)
groupByKeyname =
    Dict.filterGroupBy <|
        \{ name, variables } ->
            let
                base =
                    String.leftOfBack "_keyname_" name

                keyname =
                    String.rightOfBack "_keyname_" name

                isKeynameCorrect =
                    keyname /= "" && (keyname |> not << String.contains ".")
            in
            if isKeynameCorrect && List.isEmpty variables then
                Just (base ++ "_keyname")

            else
                Nothing


{-| Creates a translation function delegating to existing translation,
choosing the correct one based on a keyname parameter.
-}
createAKeynameTranslation : ( String, List Legacy.Translation ) -> Legacy.Translation
createAKeynameTranslation ( baseName, translations ) =
    Legacy.Translation baseName
        []
        (Legacy.Keyname <|
            List.map
                (\{ name } -> ( String.rightOfBack "_keyname_" name, name ))
                translations
        )


{-| Turns a TranslationDomain into its elm representation.
-}
convertToElm : Version -> TranslationDomain -> File
convertToElm version { lang, domain, translations } =
    let
        normalizedDomain =
            normalizeModuleName domain
    in
    { name = "Trans/" ++ normalizedDomain ++ ".elm"
    , content =
        renderElmModule version <|
            Module ("Trans." ++ normalizedDomain) <|
                translationToElm lang translations
    }


translationToElm : String -> TranslationsInDomain -> List Function
translationToElm lang translationsInDomain =
    case translationsInDomain of
        IntlIcu translations ->
            List.map (IntlIcu.translationToElm lang) translations

        Legacy translations ->
            List.map (Legacy.translationToElm lang) translations


{-| Returns the first element.
-}
dictFirst : Dict comparable value -> Maybe ( comparable, value )
dictFirst =
    Dict.toList >> List.head


{-| Removes duplicate keys.
-}
deduplicateKeys : List ( String, a ) -> List ( String, a )
deduplicateKeys =
    Dict.fromList >> Dict.toList
