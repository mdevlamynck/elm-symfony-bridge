module Transpiler exposing (transpileTranslationToElm, File)

{-| Converts a JSON containing translations from Symfony
and turn them into an elm file.

@docs transpileTranslationToElm, File

-}

import Elm exposing (..)
import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Result
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
                { domain = "Trans" ++ (String.toSentenceCase domain)
                , translations = translations
                }
            )


{-| Turns a TranslationDomain into its elm representation
-}
convertToElm : TranslationDomain -> File
convertToElm { domain, translations } =
    { name = domain ++ ".elm"
    , content = renderElmModule <| Module domain (List.map translationToElm translations)
    }


{-| Parses the raw translation into a Translation
-}
parseTranslation : ( String, String ) -> Result String Translation
parseTranslation ( name, message ) =
    TranslationParser.parseTranslationContent message
        |> Result.map
            (\translationContent ->
                { name = formatName name
                , placeholders = extractPlaceholders translationContent
                , content = translationContent
                }
            )


{-| Format the name of a translation to match elm rules on function name
-}
formatName : String -> String
formatName =
    String.split "." >> String.join "_"


{-| Extracts the list of placeholders used in the TranslationContent
-}
extractPlaceholders : TranslationContent -> List String
extractPlaceholders translationContent =
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
                        Placeholder p ->
                            Just p

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
            choice ++ record

        choice =
            case translation.content of
                SingleMessage _ ->
                    []

                PluralizedMessage _ ->
                    [ Primitive "Int" "choice" ]

        recordArgs =
            List.map (\arg -> ( "String", arg )) translation.placeholders

        record =
            if recordArgs == [] then
                []
            else
                [ Record recordArgs ]
    in
        Function translation.name arguments "String" (translationContentToElm translation.content)


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
                            ( Expr (combineRanges alt.appliesTo), Expr (combineChunks alt.chunks) )
                        )
                )


{-| Turns a list of Ranges into an elm expression usable in a if
-}
combineRanges : List Range -> String
combineRanges ranges =
    case ranges of
        head :: [] ->
            rangeToCondExpr head

        ranges ->
            let
                conditions =
                    ranges
                        |> List.map rangeToCondExpr
                        |> String.join ") || ("
            in
                "(" ++ conditions ++ ")"


{-| Turns a Range into an elm expression usable in a if
-}
rangeToCondExpr : Range -> String
rangeToCondExpr range =
    let
        isLowEqualToHigh =
            case ( range.low, range.high ) of
                ( Included low, Included high ) ->
                    if low == high then
                        Just <| "choice == " ++ (toString low)
                    else
                        Nothing

                _ ->
                    Nothing

        lowBound =
            case range.low of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "choice >= " ++ (toString bound)

                Excluded bound ->
                    Just <| "choice > " ++ (toString bound)

        highBound =
            case range.high of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "choice <= " ++ (toString bound)

                Excluded bound ->
                    Just <| "choice < " ++ (toString bound)
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

        Placeholder placeholder ->
            placeholder
