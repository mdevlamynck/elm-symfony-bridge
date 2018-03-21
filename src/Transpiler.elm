module Transpiler exposing (transpileTranslationToElm)

import Elm exposing (..)
import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Char
import Result
import Result.Extra as Result
import String.Extra as String
import TranslationParser
import Data exposing (..)
import List.Unique


transpileTranslationToElm : String -> String
transpileTranslationToElm input =
    input
        |> extractTranslation
        |> Result.andThen convertToElm
        |> Result.map renderElmModule
        |> Result.merge


extractTranslation : String -> Result String ( String, Dict String String )
extractTranslation =
    decodeString (dict (dict (dict (dict string))))
        >> Result.andThen
            (Dict.get "translations"
                >> Maybe.andThen (Dict.get "fr")
                >> Maybe.andThen (Dict.toList >> List.head)
                >> Result.fromMaybe "No translations found in this JSON"
            )


convertToElm : ( String, Dict String String ) -> Result String Module
convertToElm ( domain, messages ) =
    messages
        |> Dict.toList
        |> List.map analyseTranslation
        |> Result.combine
        |> Result.map (List.map translationToElm >> Module ("Trans" ++ (String.toSentenceCase domain)))


analyseTranslation : ( String, String ) -> Result String Translation
analyseTranslation ( name, message ) =
    TranslationParser.parseAlternatives message
        |> Result.map
            (\alternatives ->
                let
                    placeholders =
                        alternatives
                            |> List.concatMap .chunks
                            |> List.filterMap
                                (\e ->
                                    case e of
                                        Placeholder p ->
                                            Just p

                                        _ ->
                                            Nothing
                                )
                            |> List.Unique.filterDuplicates
                in
                    { name = formatName name
                    , alternatives = alternatives
                    , placeholders = placeholders
                    }
            )


formatName : String -> String
formatName name =
    name
        |> String.split "."
        |> String.join "_"


translationToElm : Translation -> Function
translationToElm translation =
    let
        arguments =
            choice ++ record

        choice =
            if List.length translation.alternatives > 1 then
                [ Primitive "Int" "choice" ]
            else
                []

        recordArgs =
            List.map (\arg -> ( "String", arg )) translation.placeholders

        record =
            if recordArgs == [] then
                []
            else
                [ Record recordArgs ]
    in
        Function translation.name arguments "String" (alternativesToElm translation.alternatives)


alternativesToElm : List Alternative -> Expr
alternativesToElm alternatives =
    case alternatives of
        head :: [] ->
            Expr (combineChunks head.chunks)

        alternatives ->
            Ifs
                (alternatives
                    |> List.map
                        (\alt ->
                            ( Expr (combineRanges alt.appliesTo), Expr (combineChunks alt.chunks) )
                        )
                )


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


combineChunks : List Chunk -> String
combineChunks =
    List.map chunkToString >> String.join " ++ "


chunkToString : Chunk -> String
chunkToString chunk =
    case chunk of
        Text text ->
            "\"" ++ text ++ "\""

        Placeholder placeholder ->
            placeholder
