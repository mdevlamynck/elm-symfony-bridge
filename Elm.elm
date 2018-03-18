module Elm exposing (Module(..), Function(..), Arg(..), Expr(..), renderElmModule)

import StringUtil exposing (indent)


type Module
    = Module String (List Function)


type Function
    = Function String (List Arg) String Expr


type Arg
    = Primitive String String
    | Record (List ( String, String ))


type Expr
    = Ifs (List ( Expr, Expr ))
    | Expr String


renderElmModule : Module -> String
renderElmModule (Module name body) =
    let
        renderedBody =
            List.map renderElmFunction body
    in
        (("module " ++ name ++ " exposing (..)") :: renderedBody)
            |> String.join "\n\n\n"


renderElmFunction : Function -> String
renderElmFunction (Function name args returnType body) =
    let
        renderedArgs =
            ((List.map renderElmType args) ++ [ returnType ])
                |> String.join " -> "

        annotation =
            name ++ " : " ++ renderedArgs

        definition =
            (name :: (List.map renderElmParam args) ++ [ "=" ])
                |> String.join " "
    in
        [ annotation, definition, indent (renderElmExpr body) ]
            |> String.join "\n"


renderElmType : Arg -> String
renderElmType arg =
    case arg of
        Primitive typeName _ ->
            typeName

        Record types ->
            let
                renderTypes =
                    List.map
                        (\( typeName, argName ) ->
                            argName ++ " : " ++ typeName
                        )
                        >> String.join ", "
            in
                "{ " ++ renderTypes types ++ " }"


renderElmParam : Arg -> String
renderElmParam arg =
    case arg of
        Primitive _ param ->
            param

        Record types ->
            let
                renderParams =
                    List.map Tuple.second
                        >> String.join ", "
            in
                "{ " ++ renderParams types ++ " }"


renderElmExpr : Expr -> String
renderElmExpr expr =
    case expr of
        Expr body ->
            body

        Ifs alternatives ->
            case alternatives of
                [ ( Expr cond, Expr expr ) ] ->
                    expr

                ( Expr cond, Expr expr ) :: tail ->
                    ([ "if " ++ cond ++ " then"
                     , indent expr
                     , ""
                     ]
                        |> String.join "\n"
                    )
                        ++ renderElseIf tail

                _ ->
                    ""


renderElseIf : List ( Expr, Expr ) -> String
renderElseIf alternatives =
    case alternatives of
        [ ( Expr cond, Expr expr ) ] ->
            [ "else"
            , indent expr
            ]
                |> String.join "\n"

        ( Expr cond, Expr expr ) :: tail ->
            ([ "else if " ++ cond ++ " then"
             , indent expr
             , ""
             ]
                |> String.join "\n"
            )
                ++ (renderElseIf tail)

        _ ->
            ""
