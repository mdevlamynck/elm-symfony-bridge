module TranslationParserTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (..)
import Data exposing (..)
import TranslationParser exposing (parseTranslationContent)


suite : Test
suite =
    describe "Parses a translation" <|
        [ describe "Succeesfull parsing" <|
            [ test "Works with plain constant translations" <|
                \_ ->
                    let
                        input =
                            "Ok"

                        expected =
                            Ok (SingleMessage [ Text "Ok" ])
                    in
                        Expect.equal expected (parseTranslationContent input)
            , test "Works with translations containing variables" <|
                \_ ->
                    let
                        input =
                            "%count% notifications non lues"

                        expected =
                            Ok (SingleMessage [ VariableCount, Text " notifications non lues" ])
                    in
                        Expect.equal expected (parseTranslationContent input)
            , test "Works with alternatives translations containing variables" <|
                \_ ->
                    let
                        input =
                            "{0}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = [ { low = Included 0, high = Included 0 } ]
                                      , chunks =
                                            [ Text "Pas de notification"
                                            ]
                                      }
                                    , { appliesTo = [ { low = Included 1, high = Included 1 } ]
                                      , chunks =
                                            [ VariableCount
                                            , Text " notification non lue"
                                            ]
                                      }
                                    , { appliesTo = [ { low = Included 2, high = Inf } ]
                                      , chunks =
                                            [ VariableCount
                                            , Text " notifications non lues"
                                            ]
                                      }
                                    ]
                    in
                        Expect.equal expected (parseTranslationContent input)
            ]
        , describe "Failed parsing" <|
            [ describe "Invalid ranges" <|
                [ test "Invalid range's low side [Inf" <|
                    \_ ->
                        let
                            input =
                                "[Inf, 0[Negative|[0, Inf[Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range's low side:

                                            [Inf, 0[Negative|[0, Inf[Positive
                                             ^

                                        Expected a valid integer.

                                        Hint if the input is [Inf:
                                            In a range's low side, [Inf is invalid as Inf is always exclusive.
                                            Try ]Inf instead."
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Invalid range's high side Inf]" <|
                    \_ ->
                        let
                            input =
                                "]Inf, 0[Negative|[0, Inf]Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range's high side:

                                            ]Inf, 0[Negative|[0, Inf]Positive
                                                                    ^

                                        Expected the symbol "[".

                                        Hint if the input is Inf]:
                                            In a range's high side, Inf] is invalid as Inf is always exclusive.
                                            Try Inf[ instead."
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing ," <|
                    \_ ->
                        let
                            input =
                                "]Inf 0[Negative|[0, Inf]Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range:

                                            ]Inf 0[Negative|[0, Inf]Positive
                                                 ^

                                        Expected the symbol ",".

                                        Hint:
                                            Ranges must contain two values, a low and a high bound.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Too many values" <|
                    \_ ->
                        let
                            input =
                                "]Inf, 0, 1[Negative|[0, Inf]Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range's high side:

                                            ]Inf, 0, 1[Negative|[0, Inf]Positive
                                                   ^

                                        Expected one of:
                                            - the symbol "]";
                                            - the symbol "[".

                                        Hint:
                                            Ranges can only contain two values, a low and a high bound.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing high value" <|
                    \_ ->
                        let
                            input =
                                "[0]Negative|[0, Inf]Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range:

                                            [0]Negative|[0, Inf]Positive
                                              ^

                                        Expected the symbol ",".

                                        Hint:
                                            Ranges must contain two values, a low and a high bound.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing values" <|
                    \_ ->
                        let
                            input =
                                "[]Negative|[0, Inf]Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range's low side:

                                            []Negative|[0, Inf]Positive
                                             ^

                                        Expected a valid integer.

                                        Hint if the input is [Inf:
                                            In a range's low side, [Inf is invalid as Inf is always exclusive.
                                            Try ]Inf instead."
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing values with ," <|
                    \_ ->
                        let
                            input =
                                "[,]Negative|[0, Inf]Positive"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a range's low side:

                                            [,]Negative|[0, Inf]Positive
                                             ^

                                        Expected a valid integer.

                                        Hint if the input is [Inf:
                                            In a range's low side, [Inf is invalid as Inf is always exclusive.
                                            Try ]Inf instead."
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                ]
            , describe "Invalid list of values" <|
                [ test "Empty list of values" <|
                    \_ ->
                        let
                            input =
                                "{}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a list of values:

                                            {}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues
                                              ^

                                        Expected a non empty list of values.

                                        Hint:
                                            A list of values must contain at least one value
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing ," <|
                    \_ ->
                        let
                            input =
                                "{0 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a list of values:

                                            {0 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues
                                               ^

                                        Expected one of:
                                            - the symbol ",";
                                            - the symbol "}".

                                        Hint:
                                            The values must be separated by a ",".
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Invalid value in first position" <|
                    \_ ->
                        let
                            input =
                                "{Inf, 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a list of values:

                                            {Inf, 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues
                                             ^

                                        Expected one of:
                                            - a valid integer;
                                            - the symbol "}".

                                        Hint:
                                            Only integer are allowed in a list of values.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Invalid value" <|
                    \_ ->
                        let
                            input =
                                "{0, Inf}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a list of values:

                                            {0, Inf}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues
                                                ^

                                        Expected a valid integer.

                                        Hint:
                                            Only integer are allowed in a list of values.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                ]
            , describe "Invalid pluralization" <|
                [ test "Only one pluralization" <|
                    \_ ->
                        let
                            input =
                                "{0, 1}Pas de notification"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a pluralization:

                                            {0, 1}Pas de notification
                                                                     ^

                                        Expected at least two pluralizations.

                                        Hint:
                                            Expected to be parsing a pluralization, found only one variant.
                                            If this is a single message, try removing the prefix (the range or
                                            the list of values). Otherwise add at least another variant.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing prefix" <|
                    \_ ->
                        let
                            input =
                                "{0}Pas de notification|%count% notification non lue|[2, Inf[%count% notifications non lues"

                            expected =
                                Err <|
                                    unindent
                                        """
                                        Failed to parse a translation.

                                        Error while parsing a block specifying when to apply the message:

                                            {0}Pas de notification|%count% notification non lue|[2, Inf[%count% notifications non lues
                                                                   ^

                                        Expected one of:
                                            - the symbol "]";
                                            - the symbol "[";
                                            - the symbol "{".

                                        Hint:
                                            It seems a pluralization is missing either a range or a list of values
                                            to specify when to apply this message.
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                , test "Missing prefix in the first message" <|
                    \_ ->
                        let
                            input =
                                "Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues"

                            expected =
                                Err <|
                                    unindent """
                                        Failed to parse a translation.

                                        Error while parsing a translation:

                                            Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues
                                            ^

                                        Expected one of:
                                            - at least two pluralizations;
                                            - the end of input.

                                        Hint:
                                            It seems that either a pluralization is invalid or that a simple message contains a "|".
                                        """
                        in
                            Expect.equal expected (parseTranslationContent input)
                ]
            ]
        ]
