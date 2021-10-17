module Translation.IntlIcu.ParserTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, string)
import Test exposing (..)
import Translation.IntlIcu.Data exposing (..)
import Translation.IntlIcu.Parser exposing (parseTranslationContent)
import Unindent exposing (unindent)


longString : String
longString =
    String.fromList <| List.repeat 100000 'a'


{-| Most tests come from [format-message](https://github.com/format-message/format-message)'s tests
-}
suite : Test
suite =
    describe "Parses a translation" <|
        [ describe "Success cases" <|
            [ fuzz string "Should work on any string" <|
                \input ->
                    Expect.ok (parseTranslationContent input)
            , test "Should work on very long string" <|
                \_ ->
                    Expect.ok (parseTranslationContent longString)
            , test "Should parse raw text" <|
                \_ ->
                    let
                        msg =
                            "Hello, World!"
                    in
                    parseTranslationContent msg
                        |> Expect.equal (Ok [ Text msg ])
            , test "Should parse raw text with variable" <|
                \_ ->
                    parseTranslationContent "Hello, {name}!"
                        |> Expect.equal (Ok [ Text "Hello, ", Var { name = "name", type_ = Raw }, Text "!" ])
            , test "Should parse number variable" <|
                \_ ->
                    parseTranslationContent "{n,number}"
                        |> Expect.equal (Ok [ Var { name = "n", type_ = Number Nothing } ])
            , test "Should parse number variable with style" <|
                \_ ->
                    parseTranslationContent "{num, number, percent }"
                        |> Expect.equal (Ok [ Var { name = "num", type_ = Number (Just "percent") } ])
            , test "Should parse plural variable with variable shorthand syntax" <|
                \_ ->
                    parseTranslationContent "{numPhotos, plural, =0{no photos} =1{one photo} other{# photos}}"
                        |> Expect.equal
                            (Ok
                                [ Var
                                    { name = "numPhotos"
                                    , type_ =
                                        Plural defaultPluralOption
                                            [ { pattern = Value 0
                                              , value = [ Text "no photos" ]
                                              }
                                            , { pattern = Value 1
                                              , value = [ Text "one photo" ]
                                              }
                                            , { pattern = PluralOther
                                              , value = [ Var { name = "numPhotos", type_ = Number Nothing }, Text " photos" ]
                                              }
                                            ]
                                    }
                                ]
                            )
            , test "Should parse can parse plural variable with offset and variable shorthand syntax" <|
                \_ ->
                    parseTranslationContent "{numGuests, plural, offset:1 =0{no party} one{host and a guest} other{# guests}}"
                        |> Expect.equal
                            (Ok
                                [ Var
                                    { name = "numGuests"
                                    , type_ =
                                        Plural { offset = 1 }
                                            [ { pattern = Value 0, value = [ Text "no party" ] }
                                            , { pattern = One, value = [ Text "host and a guest" ] }
                                            , { pattern = PluralOther, value = [ Var { name = "numGuests", type_ = Number Nothing }, Text " guests" ] }
                                            ]
                                    }
                                ]
                            )
            , test "Should parse selectordinal variable with variable shorthand syntax" <|
                \_ ->
                    parseTranslationContent "{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}"
                        |> Expect.equal
                            (Ok
                                [ Var
                                    { name = "rank"
                                    , type_ =
                                        Plural defaultPluralOption
                                            [ { pattern = One, value = [ Var { name = "rank", type_ = Number Nothing }, Text "st" ] }
                                            , { pattern = Two, value = [ Var { name = "rank", type_ = Number Nothing }, Text "nd" ] }
                                            , { pattern = Few, value = [ Var { name = "rank", type_ = Number Nothing }, Text "rd" ] }
                                            , { pattern = PluralOther, value = [ Var { name = "rank", type_ = Number Nothing }, Text "th" ] }
                                            ]
                                    }
                                ]
                            )
            , test "Should parse selectordinal variable with offset and variable shorthand syntax" <|
                \_ ->
                    parseTranslationContent "{rank, selectordinal, offset:1 one {#st} two {#nd} few {#rd} other {#th}}"
                        |> Expect.equal
                            (Ok
                                [ Var
                                    { name = "rank"
                                    , type_ =
                                        Plural { offset = 1 }
                                            [ { pattern = One, value = [ Var { name = "rank", type_ = Number Nothing }, Text "st" ] }
                                            , { pattern = Two, value = [ Var { name = "rank", type_ = Number Nothing }, Text "nd" ] }
                                            , { pattern = Few, value = [ Var { name = "rank", type_ = Number Nothing }, Text "rd" ] }
                                            , { pattern = PluralOther, value = [ Var { name = "rank", type_ = Number Nothing }, Text "th" ] }
                                            ]
                                    }
                                ]
                            )
            , test "Should parse select variable" <|
                \_ ->
                    parseTranslationContent "{gender, select, female {woman} male {man} other {person}}"
                        |> Expect.equal
                            (Ok
                                [ Var
                                    { name = "gender"
                                    , type_ =
                                        Select
                                            [ { pattern = SelectText "female", value = [ Text "woman" ] }
                                            , { pattern = SelectText "male", value = [ Text "man" ] }
                                            , { pattern = SelectOther, value = [ Text "person" ] }
                                            ]
                                    }
                                ]
                            )
            , test "Should ignore angle brackets by default" <|
                \_ ->
                    parseTranslationContent "</close>"
                        |> Expect.equal (Ok [ Text "</close>" ])
            , describe "Whitespace handling" <|
                [ test "Should allow whitespace in and around text elements" <|
                    \_ ->
                        let
                            msg =
                                "     some random test     "
                        in
                        parseTranslationContent msg
                            |> Expect.equal (Ok [ Text msg ])
                , test "Should allow whitespace in argument elements" <|
                    \_ ->
                        parseTranslationContent "{    num , number,percent    }"
                            |> Expect.equal (Ok [ Var { name = "num", type_ = Number (Just "percent") } ])
                , test "Should consider lots of kinds of whitespace" <|
                    \_ ->
                        let
                            white =
                                " \t\u{000D}\n\u{0085}\u{00A0}\u{180E}\u{2001}\u{2028}\u{2029}\u{202F}\u{205F}\u{2060}␋\u{3000}\u{FEFF}"
                        in
                        parseTranslationContent (white ++ "{" ++ white ++ "p" ++ white ++ "}" ++ white)
                            |> Expect.equal (Ok [ Text white, Var { name = "p", type_ = Raw }, Text white ])
                ]
            , describe "escaping" <|
                [ test "Should allow escaping of { via '" <|
                    \_ ->
                        parseTranslationContent "'{'"
                            |> Expect.equal (Ok [ Text "{" ])
                , test "Should allow escaping of } via '" <|
                    \_ ->
                        parseTranslationContent "'}'"
                            |> Expect.equal (Ok [ Text "}" ])
                , test "Should allow escaping of ' via '" <|
                    \_ ->
                        parseTranslationContent "''"
                            |> Expect.equal (Ok [ Text "'" ])
                , test "Should allow escaping of {' via '" <|
                    \_ ->
                        parseTranslationContent "'{'''"
                            |> Expect.equal (Ok [ Text "{'" ])
                , test "Should allow escaping of # via '" <|
                    \_ ->
                        parseTranslationContent "'#'"
                            |> Expect.equal (Ok [ Text "#" ])
                , test "Should allow unescaped '" <|
                    \_ ->
                        parseTranslationContent "'"
                            |> Expect.equal (Ok [ Text "'" ])
                , test "Should allow escaping in variable" <|
                    \_ ->
                        parseTranslationContent "{n,plural,other{#'#'}}"
                            |> Expect.equal
                                (Ok
                                    [ Var
                                        { name = "n"
                                        , type_ =
                                            Plural defaultPluralOption
                                                [ { pattern = PluralOther
                                                  , value = [ Var { name = "n", type_ = Number Nothing }, Text "#" ]
                                                  }
                                                ]
                                        }
                                    ]
                                )
                , test "Should always start an escape with ' in style text" <|
                    \_ ->
                        parseTranslationContent "{n,date,'a style'}"
                            |> Expect.equal (Ok [ Var { name = "n", type_ = Date (Just "a style") } ])
                ]
            , test "Should parse multilines full example" <|
                \_ ->
                    let
                        msg =
                            unindent """{gender_of_host, select,
                                            female {{num_guests, plural, offset:1
                                                =0    {{host} does not give a party.}
                                                =1    {{host} invites {guest} to her party.}
                                                =2    {{host} invites {guest} and one other person to her party.}
                                                other {{host} invites {guest} and # other people to her party.}
                                            }}
                                            male {{num_guests, plural, offset:1
                                                =0    {{host} does not give a party.}
                                                =1    {{host} invites {guest} to his party.}
                                                =2    {{host} invites {guest} and one other person to his party.}
                                                other {{host} invites {guest} and # other people to his party.}
                                            }}
                                            other {{num_guests, plural, offset:1
                                                =0    {{host} does not give a party.}
                                                =1    {{host} invites {guest} to their party.}
                                                =2    {{host} invites {guest} and one other person to their party.}
                                                other {{host} invites {guest} and # other people to their party.}
                                            }}
                                        }
                        """
                    in
                    parseTranslationContent msg
                        |> Expect.equal
                            (Ok
                                [ Var
                                    { name = "gender_of_host"
                                    , type_ =
                                        Select
                                            [ { pattern = SelectText "female"
                                              , value =
                                                    [ Var
                                                        { name = "num_guests"
                                                        , type_ =
                                                            Plural { offset = 1 }
                                                                [ { pattern = Value 0
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " does not give a party."
                                                                        ]
                                                                  }
                                                                , { pattern = Value 1
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " to her party."
                                                                        ]
                                                                  }
                                                                , { pattern = Value 2
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " and one other person to her party."
                                                                        ]
                                                                  }
                                                                , { pattern = PluralOther
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " and "
                                                                        , Var { name = "num_guests", type_ = Number Nothing }
                                                                        , Text " other people to her party."
                                                                        ]
                                                                  }
                                                                ]
                                                        }
                                                    ]
                                              }
                                            , { pattern = SelectText "male"
                                              , value =
                                                    [ Var
                                                        { name = "num_guests"
                                                        , type_ =
                                                            Plural { offset = 1 }
                                                                [ { pattern = Value 0
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " does not give a party."
                                                                        ]
                                                                  }
                                                                , { pattern = Value 1
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " to his party."
                                                                        ]
                                                                  }
                                                                , { pattern = Value 2
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " and one other person to his party."
                                                                        ]
                                                                  }
                                                                , { pattern = PluralOther
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " and "
                                                                        , Var { name = "num_guests", type_ = Number Nothing }
                                                                        , Text " other people to his party."
                                                                        ]
                                                                  }
                                                                ]
                                                        }
                                                    ]
                                              }
                                            , { pattern = SelectOther
                                              , value =
                                                    [ Var
                                                        { name = "num_guests"
                                                        , type_ =
                                                            Plural { offset = 1 }
                                                                [ { pattern = Value 0
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " does not give a party."
                                                                        ]
                                                                  }
                                                                , { pattern = Value 1
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " to their party."
                                                                        ]
                                                                  }
                                                                , { pattern = Value 2
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " and one other person to their party."
                                                                        ]
                                                                  }
                                                                , { pattern = PluralOther
                                                                  , value =
                                                                        [ Var { name = "host", type_ = Raw }
                                                                        , Text " invites "
                                                                        , Var { name = "guest", type_ = Raw }
                                                                        , Text " and "
                                                                        , Var { name = "num_guests", type_ = Number Nothing }
                                                                        , Text " other people to their party."
                                                                        ]
                                                                  }
                                                                ]
                                                        }
                                                    ]
                                              }
                                            ]
                                    }
                                ]
                            )
            ]
        , describe "Failure cases" <|
            [ test "Fails on extra closing brace" <|
                \_ ->
                    parseTranslationContent ""
                        |> Expect.ok
            , test "Fails on empty placeholder" <|
                \_ ->
                    parseTranslationContent "{}"
                        |> Expect.ok
            , test "Fails on open brace in placeholder" <|
                \_ ->
                    parseTranslationContent "{n{"
                        |> Expect.ok
            , test "Fails on missing type" <|
                \_ ->
                    parseTranslationContent "{n,}"
                        |> Expect.ok
            , test "Fails on unknown type" <|
                \_ ->
                    parseTranslationContent "{a, custom, one}"
                        |> Expect.ok
            , test "Fails on open brace after type" <|
                \_ ->
                    parseTranslationContent "{n,d{"
                        |> Expect.ok
            , test "Fails on missing style" <|
                \_ ->
                    parseTranslationContent "{n,t,}"
                        |> Expect.ok
            , test "Fails on missing sub-messages for select" <|
                \_ ->
                    parseTranslationContent "{n,select}"
                        |> Expect.ok
            , test "Fails on missing sub-messages for selectordinal" <|
                \_ ->
                    parseTranslationContent "{n,selectordinal}"
                        |> Expect.ok
            , test "Fails on missing sub-messages for plural" <|
                \_ ->
                    parseTranslationContent "{n,plural}"
                        |> Expect.ok
            , test "Fails on missing other for select" <|
                \_ ->
                    parseTranslationContent "{n,select,}"
                        |> Expect.ok
            , test "Fails on missing other for selectordinal" <|
                \_ ->
                    parseTranslationContent "{n,selectordinal,}"
                        |> Expect.ok
            , test "Fails on missing other for plural" <|
                \_ ->
                    parseTranslationContent "{n,plural,}"
                        |> Expect.ok
            , test "Fails on missing selector" <|
                \_ ->
                    parseTranslationContent "{n,select,{a}}"
                        |> Expect.ok
            , test "Fails on missing { for sub-message" <|
                \_ ->
                    parseTranslationContent "{n,select,other a}"
                        |> Expect.ok
            , test "Fails on missing } for sub-message" <|
                \_ ->
                    parseTranslationContent "{n,select,other{a"
                        |> Expect.ok
            , test "Fails on missing offset number" <|
                \_ ->
                    parseTranslationContent "{n,plural,offset:}"
                        |> Expect.ok
            , test "Fails on missing closing brace" <|
                \_ ->
                    parseTranslationContent "{a,b,c"
                        |> Expect.ok
            ]
        ]
