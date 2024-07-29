module Dto.GraphTest exposing (..)

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
                        Set.fromList []
                in
                Expect.equal expected (Graph.findNodesInCycles input)
        , test "one cycle" <|
            \_ ->
                let
                    input =
                        Dict.fromList
                            [ ( "A", Set.fromList [ "B" ] )
                            , ( "B", Set.fromList [ "C" ] )
                            , ( "C", Set.fromList [ "A" ] )
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
                            [ ( "A", Set.fromList [ "B" ] )
                            , ( "B", Set.fromList [ "C" ] )
                            , ( "C", Set.fromList [ "D" ] )
                            , ( "D", Set.fromList [ "B" ] )
                            ]

                    expected =
                        Set.fromList [ "B", "C", "D" ]
                in
                Expect.equal expected (Graph.findNodesInCycles input)
        ]
