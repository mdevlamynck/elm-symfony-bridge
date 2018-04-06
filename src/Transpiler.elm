module Transpiler exposing (transpileTranslationToElm, File)

{-| Converts a JSON containing translations from Symfony
and turn them into an elm file.

@docs transpileTranslationToElm, File

-}

import Elm exposing (..)
import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Result
import Char
import Result.Extra as Result
import String.Extra as String
import TranslationParser
import Data exposing (..)
import List.Unique


{-| Represents a file
-}
type alias File =
    { name : String
    , content : String
    }


{-| Converts a JSON containing translations to an Elm file
-}
transpileTranslationToElm : String -> Result String File
transpileTranslationToElm =
    readJsonContent
        >> Result.andThen parseTranslationDomain
        >> Result.map convertToElm


{-| Represents the content of a JSON translation file
-}
type alias JsonTranslationDomain =
    { domain : String
    , translations : Dict String String
    }


{-| A parsed translation file
-}
type alias TranslationDomain =
    { domain : String
    , translations : List Translation
    }


{-| Extracts from the given JSON the domain and the translations
-}
readJsonContent : String -> Result String JsonTranslationDomain
readJsonContent =
    decodeString (dict (dict (dict (dict string))))
        >> Result.andThen
            (Dict.get "translations"
                >> Maybe.andThen (Dict.get "fr")
                >> Maybe.andThen (Dict.toList >> List.head)
                >> Maybe.map
                    (\( domain, translations ) ->
                        JsonTranslationDomain domain translations
                    )
                >> Result.fromMaybe "No translations found in this JSON"
            )


{-| Parses the translations into use usable type
-}
parseTranslationDomain : JsonTranslationDomain -> Result String TranslationDomain
parseTranslationDomain { domain, translations } =
    translations
        |> Dict.toList
        |> List.map parseTranslation
        |> Result.combine
        |> Result.map
            (\translations ->
                { domain = String.toSentenceCase domain
                , translations = translations
                }
            )


{-| Turns a TranslationDomain into its elm representation
-}
convertToElm : TranslationDomain -> File
convertToElm { domain, translations } =
    { name = "Trans/" ++ domain ++ ".elm"
    , content = renderElmModule <| Module ("Trans." ++ domain) (List.map translationToElm translations)
    }


{-| Parses the raw translation into a Translation
-}
parseTranslation : ( String, String ) -> Result String Translation
parseTranslation ( name, message ) =
    let
        parsedTranslations =
            TranslationParser.parseTranslationContent message

        parsedName =
            formatName name
    in
        Result.map2
            (\translationContent name ->
                { name = name
                , variables = extractVariables translationContent
                , content = translationContent
                }
            )
            parsedTranslations
            parsedName


{-| Format the name of a translation to match elm rules on function name
-}
formatName : String -> Result String String
formatName name =
    let
        formatedName =
            String.replace "." "_" name

        onlyAllowedChars =
            String.all
                (\c -> Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_')
                formatedName
    in
        if onlyAllowedChars then
            Ok formatedName
        else
            Err ("Translation name contains invalid characters: " ++ name)


{-| Extracts the list of variables used in the TranslationContent
-}
extractVariables : TranslationContent -> List String
extractVariables translationContent =
    let
        chunks =
            case translationContent of
                SingleMessage chunks ->
                    chunks

                PluralizedMessage alternatives ->
                    alternatives
                        |> List.concatMap .chunks
    in
        chunks
            |> List.filterMap
                (\e ->
                    case e of
                        Variable v ->
                            Just v

                        _ ->
                            Nothing
                )
            |> List.Unique.filterDuplicates


{-| Turns a translation into an elm function
-}
translationToElm : Translation -> Function
translationToElm translation =
    let
        arguments =
            count ++ record

        count =
            if hasCountVariable translation.content then
                [ Primitive "Int" "count" ]
            else
                []

        recordArgs =
            List.map (\arg -> ( "String", arg )) translation.variables

        record =
            if recordArgs == [] then
                []
            else
                [ Record recordArgs ]
    in
        Function translation.name arguments "String" (translationContentToElm translation.content)


{-| Does a TranslationContent contains a `count` variable
-}
hasCountVariable : TranslationContent -> Bool
hasCountVariable translationContent =
    case translationContent of
        SingleMessage chunks ->
            chunks
                |> List.any
                    (\chunk ->
                        case chunk of
                            VariableCount ->
                                True

                            _ ->
                                False
                    )

        PluralizedMessage _ ->
            True


{-| Turns a TranslationContent into the body of an elm function
-}
translationContentToElm : TranslationContent -> Expr
translationContentToElm translationContent =
    case translationContent of
        SingleMessage chunks ->
            Expr (combineChunks chunks)

        PluralizedMessage alternatives ->
            Ifs
                (alternatives
                    |> List.map
                        (\alt ->
                            ( Expr (appliesToConditionToElm alt.appliesTo), Expr (combineChunks alt.chunks) )
                        )
                )


{-| -}
appliesToConditionToElm : AppliesTo -> String
appliesToConditionToElm appliesTo =
    case appliesTo of
        Intervals intervals ->
            combineIntervals intervals

        Indexed ->
            "False"


{-| Turns a list of Intervals into an elm expression usable in a if
-}
combineIntervals : List Interval -> String
combineIntervals intervals =
    case intervals of
        head :: [] ->
            intervalToCondExpr head

        intervals ->
            let
                conditions =
                    intervals
                        |> List.map intervalToCondExpr
                        |> String.join ") || ("
            in
                "(" ++ conditions ++ ")"


{-| Turns a Interval into an elm expression usable in a if
-}
intervalToCondExpr : Interval -> String
intervalToCondExpr interval =
    let
        isLowEqualToHigh =
            case ( interval.low, interval.high ) of
                ( Included low, Included high ) ->
                    if low == high then
                        Just <| "count == " ++ (toString low)
                    else
                        Nothing

                _ ->
                    Nothing

        lowBound =
            case interval.low of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "count >= " ++ (toString bound)

                Excluded bound ->
                    Just <| "count > " ++ (toString bound)

        highBound =
            case interval.high of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "count <= " ++ (toString bound)

                Excluded bound ->
                    Just <| "count < " ++ (toString bound)
    in
        case ( isLowEqualToHigh, lowBound, highBound ) of
            ( Just value, _, _ ) ->
                value

            ( _, Just low, Just high ) ->
                low ++ " && " ++ high

            ( _, Just low, Nothing ) ->
                low

            ( _, Nothing, Just high ) ->
                high

            _ ->
                "True"


{-| Turns a list of Chunks into an elm expression usable in the body of a function
-}
combineChunks : List Chunk -> String
combineChunks =
    List.map chunkToString >> String.join " ++ "


{-| Turns a Chunk into an elm expression usable in the body of a function
-}
chunkToString : Chunk -> String
chunkToString chunk =
    case chunk of
        Text text ->
            "\"" ++ text ++ "\""

        Variable variable ->
            variable

        VariableCount ->
            "(toString count)"
