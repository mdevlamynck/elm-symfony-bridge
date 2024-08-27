module Translation.ParserTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, string)
import Test exposing (..)
import Translation.Data exposing (..)
import Translation.Parser exposing (parseTranslationContent)


longString : String
longString =
    String.fromList <| List.repeat 100000 'a'


suite : Test
suite =
    describe "Parses a translation" <|
        [ describe "Successfull parsing" <|
            [ fuzz string "Should work on any string" <|
                \input ->
                    Expect.ok (parseTranslationContent input)
            , test "Should work on very long string" <|
                \_ ->
                    Expect.ok (parseTranslationContent longString)
            , test "Works with empty translations" <|
                \_ ->
                    let
                        input =
                            ""

                        expected =
                            Ok (SingleMessage [])
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with plain constant translations" <|
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
            , test "Works with translations containing variables using reserved keywords as name" <|
                \_ ->
                    let
                        input =
                            " %if% %then% %else% %case% %of% %let% %in% %type% %module% %where% %import% %exposing% %as% %port% "

                        expected =
                            Ok
                                (SingleMessage
                                    [ Variable "if_"
                                    , Text " "
                                    , Variable "then_"
                                    , Text " "
                                    , Variable "else_"
                                    , Text " "
                                    , Variable "case_"
                                    , Text " "
                                    , Variable "of_"
                                    , Text " "
                                    , Variable "let_"
                                    , Text " "
                                    , Variable "in_"
                                    , Text " "
                                    , Variable "type_"
                                    , Text " "
                                    , Variable "module_"
                                    , Text " "
                                    , Variable "where_"
                                    , Text " "
                                    , Variable "import_"
                                    , Text " "
                                    , Variable "exposing_"
                                    , Text " "
                                    , Variable "as_"
                                    , Text " "
                                    , Variable "port_"
                                    ]
                                )
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Do not treat percent encoded (a.k.a. url encoded) values as variables" <|
                \_ ->
                    let
                        input =
                            "%case%%20%C3%A9%case%"

                        expected =
                            Ok
                                (SingleMessage
                                    [ Variable "case_"
                                    , Text "%20%C3%A9"
                                    , Variable "case_"
                                    ]
                                )
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with translations containing lisp-cased variables" <|
                \_ ->
                    let
                        input =
                            "%count-notifications% notifications non lues"

                        expected =
                            Ok (SingleMessage [ Variable "count_notifications", Text " notifications non lues" ])
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with translations containing % that are not variables" <|
                \_ ->
                    let
                        input =
                            "% pris en charge"

                        expected =
                            Ok (SingleMessage [ Text "% pris en charge" ])
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with translations containing % that are not variables alongside legit variables" <|
                \_ ->
                    let
                        input =
                            "dont TVA (%percent%%)"

                        expected =
                            Ok (SingleMessage [ Text "dont TVA (", Variable "percent", Text "%)" ])
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with translations containing printf variables like %s or %d" <|
                \_ ->
                    let
                        input =
                            "&quot;%s%d&quot;"

                        expected =
                            Ok (SingleMessage [ Text "&quot;%s%d&quot;" ])
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with pluralized translations containing variables" <|
                \_ ->
                    let
                        input =
                            "{0} Pas de notification | {1} %count% notification non lue | [2, Inf[ %count% notifications non lues"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Intervals [ { low = Included 0, high = Included 0 } ]
                                      , chunks =
                                            [ Text "Pas de notification"
                                            ]
                                      }
                                    , { appliesTo = Intervals [ { low = Included 1, high = Included 1 } ]
                                      , chunks =
                                            [ VariableCount
                                            , Text " notification non lue"
                                            ]
                                      }
                                    , { appliesTo = Intervals [ { low = Included 2, high = Inf } ]
                                      , chunks =
                                            [ VariableCount
                                            , Text " notifications non lues"
                                            ]
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with pluralized translations in indexed form with negative integers" <|
                \_ ->
                    let
                        input =
                            "{-0} Pas de notification | {-1} %count% notification non lue | [-2, Inf[ %count% notifications non lues"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Intervals [ { low = Included 0, high = Included 0 } ]
                                      , chunks =
                                            [ Text "Pas de notification"
                                            ]
                                      }
                                    , { appliesTo = Intervals [ { low = Included -1, high = Included -1 } ]
                                      , chunks =
                                            [ VariableCount
                                            , Text " notification non lue"
                                            ]
                                      }
                                    , { appliesTo = Intervals [ { low = Included -2, high = Inf } ]
                                      , chunks =
                                            [ VariableCount
                                            , Text " notifications non lues"
                                            ]
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with pluralized translations in interval and indexed forms" <|
                \_ ->
                    let
                        input =
                            "{0} There are no apples|There is one apple|There are %count% apples"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Intervals [ { low = Included 0, high = Included 0 } ]
                                      , chunks =
                                            [ Text "There are no apples"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "There is one apple"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "There are "
                                            , VariableCount
                                            , Text " apples"
                                            ]
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Labels in indexed form plurals are optional" <|
                \_ ->
                    let
                        input =
                            "zero: there are no apples|there is one apple|more: there are %count% apples"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Indexed
                                      , chunks =
                                            [ Text "there are no apples"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "there is one apple"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "there are "
                                            , VariableCount
                                            , Text " apples"
                                            ]
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with pluralized translations in interval and indexed forms with labels" <|
                \_ ->
                    let
                        input =
                            "{0} There are no apples|one: There is one apple|more: There are %count% apples"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Intervals [ { low = Included 0, high = Included 0 } ]
                                      , chunks =
                                            [ Text "There are no apples"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "There is one apple"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "There are "
                                            , VariableCount
                                            , Text " apples"
                                            ]
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with translation without plural variants but containing interval looking prefixes" <|
                \_ ->
                    let
                        input =
                            "[Prénom] {NOM}"

                        expected =
                            Ok (SingleMessage [ Text "[Prénom] {NOM}" ])
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with translation with plural variants but containing interval looking prefixes" <|
                \_ ->
                    let
                        input =
                            "[Prénom] {NOM}|{Prénom} [NOM]"

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Indexed
                                      , chunks =
                                            [ Text "[Prénom] {NOM}"
                                            ]
                                      }
                                    , { appliesTo = Indexed
                                      , chunks =
                                            [ Text "{Prénom} [NOM]"
                                            ]
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            , test "Works with empty pluralized translations in interval form" <|
                \_ ->
                    let
                        input =
                            "{0} |]-Inf,Inf["

                        expected =
                            Ok <|
                                PluralizedMessage <|
                                    [ { appliesTo = Intervals [ { low = Included 0, high = Included 0 } ]
                                      , chunks =
                                            []
                                      }
                                    , { appliesTo = Intervals [ { low = Inf, high = Inf } ]
                                      , chunks =
                                            []
                                      }
                                    ]
                    in
                    Expect.equal expected (parseTranslationContent input)
            ]
        ]
