module Main exposing (output)

import Elm exposing (..)
import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Char
import Result
import Result.Extra as Result
import TransParser exposing (..)
import Data exposing (..)
import Parser
import List.Unique


output : List String -> String
output args =
    let
        input =
            String.join " " args
    in
        input
            |> decodeString (dict string)
            |> Result.map (convertToElm >> renderElmModule)
            |> Result.merge


convertToElm : Dict String String -> Module
convertToElm messages =
    let
        translations =
            messages
                |> Dict.toList
                |> List.map (analyseTranslation >> translationToElm)
    in
        Module "Trans" translations


analyseTranslation : ( String, String ) -> Translation
analyseTranslation ( name, message ) =
    let
        alternatives =
            Parser.run alternativesP message
                |> Result.withDefault
                    [ { chunks = []
                      , appliesTo = []
                      }
                    ]

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
                            If ( Expr (combineRanges alt.appliesTo), Expr (combineChunks alt.chunks) )
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
        lowBound =
            case range.low of
                Inf ->
                    "True"

                Included bound ->
                    "choice >= " ++ (toString bound)

                Excluded bound ->
                    "choice > " ++ (toString bound)

        highBound =
            case range.high of
                Inf ->
                    "True"

                Included bound ->
                    "choice <= " ++ (toString bound)

                Excluded bound ->
                    "choice < " ++ (toString bound)
    in
        lowBound ++ " && " ++ highBound


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
