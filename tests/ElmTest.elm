module ElmTest exposing (suite)

import Elm exposing (Arg(..), Expr(..), Function(..), Module(..), Version(..), renderElmModule)
import Expect exposing (Expectation)
import Test exposing (..)
import Unindent exposing (..)


suite : Test
suite =
    describe "Render a simple elm AST to string" <|
        [ test "Renders a module correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "button_validate_global" [] "String" (Expr "\"Ok\"")
                            , Function "button_validate_save" [] "String" (Expr "\"Enregistrer\"")
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            button_validate_global : String
                            button_validate_global =
                                "Ok"


                            button_validate_save : String
                            button_validate_save =
                                "Enregistrer"
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders functions with arguments correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "user_welcome"
                                [ Primitive "Int" "choice"
                                , Record [ ( "String", "firstname" ), ( "String", "lastname" ) ]
                                ]
                                "String"
                                (Expr "\"Ok\"")
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            user_welcome : Int -> { firstname : String, lastname : String } -> String
                            user_welcome choice params_ =
                                "Ok"
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders if blocks correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "user_account_balance"
                                [ Primitive "Int" "choice" ]
                                "String"
                                (Ifs
                                    [ ( Expr "choice < 0", Expr "\"Negative\"" )
                                    , ( Expr "choice == 0", Expr "\"Zero\"" )
                                    , ( Expr "choice > 0", Expr "\"Positive\"" )
                                    ]
                                )
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            user_account_balance : Int -> String
                            user_account_balance choice =
                                if choice < 0 then
                                    "Negative"
                                else if choice == 0 then
                                    "Zero"
                                else
                                    "Positive"
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "No if when there is only one variant" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "user_account_balance"
                                [ Primitive "Int" "choice" ]
                                "String"
                                (Ifs
                                    [ ( Expr "choice < 0", Expr "\"Negative\"" )
                                    ]
                                )
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            user_account_balance : Int -> String
                            user_account_balance choice =
                                "Negative"
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders case … of expressions correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "user_account_balance"
                                [ Primitive "Int" "choice" ]
                                "String"
                                (Case "choice"
                                    [ ( "0", Expr "\"zero\"" )
                                    , ( "1", Expr "\"one\"" )
                                    , ( "_", Expr "\"\"" )
                                    ]
                                )
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            user_account_balance : Int -> String
                            user_account_balance choice =
                                case choice of
                                    0 ->
                                        "zero"

                                    1 ->
                                        "one"

                                    _ ->
                                        ""
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders nested case … of expressions correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "user_account_balance"
                                [ Primitive "Int" "choice" ]
                                "String"
                                (Case "choice"
                                    [ ( "0"
                                      , Case "other"
                                            [ ( "2", Expr "\"two\"" )
                                            , ( "_", Expr "\"\"" )
                                            ]
                                      )
                                    , ( "1"
                                      , Case "other"
                                            [ ( "3", Expr "\"three\"" )
                                            , ( "_", Expr "\"\"" )
                                            ]
                                      )
                                    , ( "_", Expr "\"\"" )
                                    ]
                                )
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            user_account_balance : Int -> String
                            user_account_balance choice =
                                case choice of
                                    0 ->
                                        case other of
                                            2 ->
                                                "two"

                                            _ ->
                                                ""

                                    1 ->
                                        case other of
                                            3 ->
                                                "three"

                                            _ ->
                                                ""

                                    _ ->
                                        ""
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders nested let … in … correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "test_nested_let_in"
                                []
                                "String"
                                (LetIn
                                    [ ( "var1", LetIn [ ( "var3", Expr "\"Hello, \"" ) ] (Expr "var3") )
                                    , ( "var2", LetIn [ ( "var4", Expr "\"World!\"" ) ] (Expr "var4") )
                                    ]
                                    (Expr "var1 ++ var2")
                                )
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int


                            test_nested_let_in : String
                            test_nested_let_in =
                                let
                                    var1 =
                                        let
                                            var3 =
                                                "Hello, "
                                        in
                                        var3

                                    var2 =
                                        let
                                            var4 =
                                                "World!"
                                        in
                                        var4
                                in
                                var1 ++ var2
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders module with fromInt for 0.19" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages" []

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                String.fromInt int
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_19 input)
        , test "Renders module with fromInt for 0.18" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages" []

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            fromInt : Int -> String
                            fromInt int =
                                toString int
                            """
                in
                Expect.equal expected (renderElmModule Elm_0_18 input)
        ]
