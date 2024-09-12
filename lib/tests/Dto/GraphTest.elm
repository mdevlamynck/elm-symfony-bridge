module Dto.GraphTest exposing (suite)

import Dict
import Dto.Graph as Graph
import Expect
import Set
import Test exposing (..)


suite : Test
suite =
    describe "Graph cycle detection"
        [ test "no cycle" <|
            \_ ->
                let
                    input =
                        Dict.fromList
                            [ ( "A", Set.fromList [ "B", "C" ] )
                            , ( "B", Set.fromList [ "D", "E" ] )
                            , ( "C", Set.fromList [ "F", "G" ] )
                            ]

                    expected =
                        Set.empty
                in
                Expect.equal expected (Graph.findNodesInCycles input)
        , test "one cycle" <|
            \_ ->
                let
                    input =
                        Dict.fromList
                            [ ( "A", Set.singleton "B" )
                            , ( "B", Set.singleton "C" )
                            , ( "C", Set.singleton "A" )
                            ]

                    expected =
                        Set.fromList [ "A", "B", "C" ]
                in
                Expect.equal expected (Graph.findNodesInCycles input)
        , test "one cycle not containing first root considered" <|
            \_ ->
                let
                    input =
                        Dict.fromList
                            [ ( "A", Set.singleton "B" )
                            , ( "B", Set.singleton "C" )
                            , ( "C", Set.singleton "D" )
                            , ( "D", Set.singleton "B" )
                            ]

                    expected =
                        Set.fromList [ "B", "C", "D" ]
                in
                Expect.equal expected (Graph.findNodesInCycles input)
        ]
