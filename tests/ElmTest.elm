module ElmTest exposing (..)

import Elm exposing (Arg(..), Expr(..), Function(..), Module(..), renderElmModule)
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
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
                                , Record [ ( "String", "firstname" ), ( "String", "lastname" ) ]
                                ]
                                "String"
                                (Expr "\"Ok\"")
                            ]

                    expected =
                        unindent """
                            module Trans.Messages exposing (..)


                            user_welcome : Int -> { firstname : String, lastname : String } -> String
                            user_welcome choice { firstname, lastname } =
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
        ]
