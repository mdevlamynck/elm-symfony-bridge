module Routing.Parser exposing (parsePathContent)

import Char
import Parser exposing (..)
import Routing.Data exposing (ArgumentType(..), Path(..))


parsePathContent : String -> Result String (List Path)
parsePathContent input =
    Parser.run pathP input
        |> Result.mapError (\_ -> "Failed to parse routing path")


pathP : Parser (List Path)
pathP =
    let
        messageConstructor =
            List.foldr
                (\elem acc ->
                    case ( elem, acc ) of
                        ( Constant elem, (Constant t) :: tail ) ->
                            Constant (elem ++ t) :: tail

                        ( elem, acc ) ->
                            elem :: acc
                )
                []
    in
        succeed messageConstructor
            |= repeat (AtLeast 1) pathChunkP


pathChunkP : Parser Path
pathChunkP =
    oneOf
        [ variableP
        , constantP
        ]


variableP : Parser Path
variableP =
    succeed (\name -> Variable name String)
        |. symbol "{"
        |= keep oneOrMore isIdentifierChar
        |. symbol "}"


constantP : Parser Path
constantP =
    succeed Constant
        |= keep (Exactly 1) (\c -> c /= '{' && c /= '}')


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'
