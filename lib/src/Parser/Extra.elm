module Parser.Extra exposing
    ( oneOfBacktrackable, many, sequenceAtLeastTwoElements
    , chomp
    , ensureProgress, failIf
    )

{-| Common functions used in the different parsers.

@docs oneOfBacktrackable, many, sequenceAtLeastTwoElements
@docs chomp
@docs ensureProgress, failIf

-}

import Parser exposing (..)


{-| Redefines oneOf to make all variants backtrackable for simplicity.
-}
oneOfBacktrackable : List (Parser a) -> Parser a
oneOfBacktrackable =
    List.map backtrackable >> oneOf


{-| Runs a parser multiple times until it fails and return the successfully parsed values.
-}
many : Parser a -> Parser (List a)
many parser =
    loop [] <|
        \revList ->
            oneOfBacktrackable
                [ ensureProgress parser |> map (\c -> Loop <| c :: revList)
                , succeed (Done <| List.reverse revList)
                ]


{-| Parser for a list of elements containing at least two elements.
-}
sequenceAtLeastTwoElements :
    { item : Parser item
    , separator : Char
    , spaces : Parser ()
    }
    -> Parser (List item)
sequenceAtLeastTwoElements config =
    succeed (::)
        |= (backtrackable <|
                succeed identity
                    |= itemInSequence
                        { item = config.item
                        , separator = config.separator
                        }
                    |. chompIf ((==) config.separator)
                    |. config.spaces
           )
        |= lazy
            (\_ ->
                oneOfBacktrackable
                    [ sequenceAtLeastTwoElements config
                    , succeed List.singleton
                        |= config.item
                    ]
            )


{-| Parses one element that is part of `sequenceAtLeastTwoElements`.
-}
itemInSequence :
    { item : Parser item
    , separator : Char
    }
    -> Parser item
itemInSequence { item, separator } =
    chompWhile ((/=) separator)
        |> getChompedString
        |> andThen
            (\content ->
                case run item content of
                    Ok parsedItem ->
                        succeed parsedItem

                    Err _ ->
                        problem ""
            )


{-| A parser that chomps n characters unconditionally.
-}
chomp : Int -> Parser ()
chomp n =
    if n <= 1 then
        chompIf (\_ -> True)

    else
        chompIf (\_ -> True) |. chomp (n - 1)


type alias HasProgress a =
    { before : Int
    , value : a
    , after : Int
    }


{-| Runs the given parser and succeeds only if the parser advanced.
-}
ensureProgress : Parser a -> Parser a
ensureProgress parser =
    succeed HasProgress
        |= getOffset
        |= parser
        |= getOffset
        |> andThen
            (\{ before, value, after } ->
                if after > before then
                    succeed value

                else
                    problem "No progress"
            )


{-| Makes a parser fail if the given predicate is True.
-}
failIf : (a -> Bool) -> Parser a -> Parser a
failIf predicate =
    andThen <|
        \value ->
            if predicate value then
                problem ""

            else
                succeed value
