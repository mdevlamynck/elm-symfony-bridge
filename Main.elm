module Main exposing (output)

import Elm exposing (..)
import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Char
import Result
import Result.Extra as Result
import TranslationParser
import Data exposing (..)
import List.Unique


output : List String -> String
output args =
    let
        input =
            String.join " " args
    in
        input
            |> decodeString (dict string)
            |> Result.andThen convertToElm
            |> Result.map renderElmModule
            |> Result.merge


convertToElm : Dict String String -> Result String Module
convertToElm messages =
    messages
        |> Dict.toList
        |> List.map analyseTranslation
        |> Result.combine
        |> Result.map (List.map translationToElm >> Module "Trans")


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
