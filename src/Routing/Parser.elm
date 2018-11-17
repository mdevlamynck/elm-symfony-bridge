module Routing.Parser exposing (parseRoutingContent)

{-| Parser for a Routing.

@docs parseRoutingContent

-}

import Char
import Parser exposing (..)
import Parser.Extra exposing (chomp)
import Routing.Data exposing (ArgumentType(..), Path(..), Routing)


{-| Runs the Routing parser on the given string.
-}
parseRoutingContent : String -> Result String Routing
parseRoutingContent input =
    Parser.run path input
        |> Result.mapError (\_ -> "Failed to parse routing path")


{-| Parses a Routing.

Parses one variable at a time or one character of text at a time.
Then contatenates together neighboring text to simplify output.

-}
path : Parser Routing
path =
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
                    |= variable
                , succeed (merge revList >> Loop)
                    |= getChompedString (chomp 1)
                , succeed (Done <| List.reverse revList)
                ]


{-| Parses a variable like '{id}'. At least one character in the variable name.
-}
variable : Parser String
variable =
    succeed identity
        |. symbol "{"
        |= (getChompedString <|
                succeed ()
                    |. chompIf isVariableChar
                    |. chompWhile isVariableChar
           )
        |. symbol "}"


{-| Is the character allowed to appear in a variable.
-}
isVariableChar : Char -> Bool
isVariableChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'
