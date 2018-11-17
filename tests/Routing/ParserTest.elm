module Routing.ParserTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, string)
import Routing.Data exposing (ArgumentType(..), Path(..))
import Routing.Parser exposing (parseRoutingContent)
import Test exposing (..)


longString : String
longString =
    String.fromList <| List.repeat 100000 'a'


suite : Test
suite =
    describe "Parser"
        [ test "Handles very long strings" <|
            \_ ->
                Expect.ok (parseRoutingContent longString)
        , test "Handles routes with variables" <|
            \_ ->
                parseRoutingContent "/api/friend/{id}/blog/{slug}/comments"
                    |> Expect.equal
                        (Ok
                            [ Constant "/api/friend/"
                            , Variable String "id"
                            , Constant "/blog/"
                            , Variable String "slug"
                            , Constant "/comments"
                            ]
                        )
        ]
