module Data exposing (..)

{-| Types common to several modules

@docs Translation, TranslationContent, Alternative, Chunk, Interval, IntervalBound

-}


{-| Represents a Translation

name is the name of the translation
variables is the list of variables
content is the actual content of the translation

-}
type alias Translation =
    { name : String
    , variables : List String
    , content : TranslationContent
    }


{-| The content of a translation

Can either be a single message or in a pluralized translation a list of
alternatives messages with the conditions to choose one over the others.

-}
type TranslationContent
    = SingleMessage (List Chunk)
    | PluralizedMessage (List Alternative)


{-| A plurilized translation message is constitued of several alternatives, represented by this type

A translation without pluralization is considered to be constitued of a single Alternative.

-}
type alias Alternative =
    { appliesTo : AppliesTo
    , chunks : List Chunk
    }


type AppliesTo
    = Intervals (List Interval)
    | Indexed


{-| A translation's message is constant string with variable for variables

Text represents the contant part
Variable represents the variable name
VariableCount represents the special variable `count` controlling the selection
of the variant in a pluralized message

-}
type Chunk
    = Text String
    | Variable String
    | VariableCount


{-| A interval with a minimal value and a maximal value

Used to determine which alternative to use for a given value
by checking in which interval the value falls.

-}
type alias Interval =
    { low : IntervalBound
    , high : IntervalBound
    }


{-| Represent either the lower limit or the high limit of a Interval

Inf is -infinity or +infinity depending if its present in the low or high bound.
Included means the limit falls in the interval
Excluded means the limit falls out of the interval

-}
type IntervalBound
    = Inf
    | Included Int
    | Excluded Int
