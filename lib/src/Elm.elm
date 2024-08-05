module Elm exposing
    ( normalizeModuleName, normalizeFunctionName
    , keywords, stringConcat
    )

{-| Extra helpers to build elm code.

@docs normalizeModuleName, normalizeFunctionName

-}

import Char exposing (isAlpha)
import Elm.CodeGen as Gen exposing (Expression)
import String.Extra exposing (toSentenceCase)
import StringUtil exposing (splitOn)


{-| Formats a string to match elm rules on module name.
-}
normalizeModuleName : String -> String
normalizeModuleName =
    splitOn (not << isAlpha)
        >> List.map toSentenceCase
        >> String.concat


{-| Formats a string to match elm rules on function name.
-}
normalizeFunctionName : String -> String
normalizeFunctionName =
    String.toLower
        >> replaceMatches (\c -> not (Char.isLower c || Char.isDigit c)) '_'
        >> (\name ->
                let
                    needsPrefix =
                        name
                            |> String.toList
                            |> List.head
                            |> Maybe.map Char.isDigit
                            |> Maybe.withDefault True
                in
                if needsPrefix then
                    "f_" ++ name

                else if String.startsWith "_" name then
                    "f" ++ name

                else
                    name
           )


{-| Replaces characters matching predicate with the given character.
-}
replaceMatches : (Char -> Bool) -> Char -> String -> String
replaceMatches predicate replacement =
    String.toList
        >> List.map
            (\c ->
                if predicate c then
                    replacement

                else
                    c
            )
        >> String.fromList


{-| List of reserved elm keywords.
-}
keywords : List String
keywords =
    [ "if", "then", "else", "case", "of", "let", "in", "type", "module", "where", "import", "exposing", "as", "port" ]


stringConcat : List Expression -> Expression
stringConcat strings =
    case List.filter ((/=) (Gen.string "")) strings of
        [] ->
            Gen.string ""

        one :: [] ->
            one

        first :: rest ->
            Gen.binOpChain first Gen.append rest
