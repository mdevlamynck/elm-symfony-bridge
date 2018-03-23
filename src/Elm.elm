module Elm exposing (Module(..), Function(..), Arg(..), Expr(..), renderElmModule)

{-| Module defining a simplified AST of elm code along with a render to string function


# AST

@docs Module, Function, Arg, Expr


# Rendering

@docs renderElmModule

-}

import StringUtil exposing (indent)


{-| An elm module with its name and the functions is defines
-}
type Module
    = Module String (List Function)


{-| An elm function with its name, the list of arguments, the return type and its body
-}
type Function
    = Function String (List Arg) String Expr


{-| An elm function argument, containing both the name and the type

Can either be a Primitive with name and type or a Record with the name and type of each field of the record.

-}
type Arg
    = Primitive String String
    | Record (List ( String, String ))


{-| An elm expression

Can either be a Ifs (a if / else if / else block) with the expressions for the test condition and the body
or can be an Expr with the expression.

-}
type Expr
    = Ifs (List ( Expr, Expr ))
    | Expr String


{-| Renders a whole module to string
-}
renderElmModule : Module -> String
renderElmModule (Module name body) =
    let
        renderedBody =
            List.map renderElmFunction body
    in
        (("module " ++ name ++ " exposing (..)") :: renderedBody)
            |> String.join "\n\n\n"


{-| Renders a function to string
-}
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


{-| Renders a type to string
-}
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


{-| Renders a parameter name to string, intended to be used when rendering a functions arguments
-}
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


{-| Renders an expression to string
-}
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


{-| Recursive function rendering the else if and else parts of an Ifs
-}
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
