module ElmTest exposing (suite)

import Dict
import Elm exposing (Arg(..), Expr(..), Function(..), Module(..), renderElmModule)
import Expect
import StringUtil exposing (..)
import Test exposing (..)


suite : Test
suite =
    describe "Render a simple elm AST to string"
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


                            button_validate_global : String
                            button_validate_global =
                                "Ok"


                            button_validate_save : String
                            button_validate_save =
                                "Enregistrer"
                            """
                in
                Expect.equal expected (renderElmModule input)
        , test "Renders functions with arguments correctly" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages"
                            [ Function "user_welcome"
                                [ Primitive "Int" "choice"
                                , Record <| Dict.fromList [ ( "firstname", "String" ), ( "lastname", "String" ) ]
                                ]
                                "String"
                                (Expr "\"Ok\"")
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            user_welcome : Int -> { firstname : String, lastname : String } -> String
                            user_welcome choice params_ =
                                "Ok"
                            """
                in
                Expect.equal expected (renderElmModule input)
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
                Expect.equal expected (renderElmModule input)
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


                            user_account_balance : Int -> String
                            user_account_balance choice =
                                "Negative"
                            """
                in
                Expect.equal expected (renderElmModule input)
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
                Expect.equal expected (renderElmModule input)
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
                Expect.equal expected (renderElmModule input)
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
                Expect.equal expected (renderElmModule input)
        , test "Renders module" <|
            \_ ->
                let
                    input =
                        Module "Trans.Messages" []

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)
                            """
                in
                Expect.equal expected (renderElmModule input)
        ]
