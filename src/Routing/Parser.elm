module Routing.Parser exposing (parsePathContent)

import Char
import Parser exposing (..)
import Parser.Extra exposing (chomp)
import Routing.Data exposing (ArgumentType(..), Path(..))


parsePathContent : String -> Result String (List Path)
parsePathContent input =
    Parser.run pathP input
        |> Result.mapError (\_ -> "Failed to parse routing path")


pathP : Parser (List Path)
pathP =
    let
        merge list string =
            case list of
                (Constant constant) :: rest ->
                    Constant (constant ++ string) :: rest

                _ ->
                    Constant string :: list
    in
    loop [] <|
        \revList ->
            oneOf
                [ succeed (\parsed -> Loop <| Variable String parsed :: revList)
                    |= variableP
                , succeed (merge revList >> Loop)
                    |= getChompedString (chomp 1)
                , succeed (Done <| List.reverse revList)
                ]


variableP : Parser String
variableP =
    succeed identity
        |. symbol "{"
        |= (getChompedString <|
                succeed ()
                    |. chompIf isIdentifierChar
                    |. chompWhile isIdentifierChar
           )
        |. symbol "}"


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'
