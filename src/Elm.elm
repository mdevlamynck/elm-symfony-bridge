module Elm exposing
    ( Module(..), Function(..), Arg(..), Expr(..)
    , Version(..), renderElmModule
    , normalizeFunctionName
    )

{-| Module defining a simplified AST of elm code along with a render to string function.


# AST

@docs Module, Function, Arg, Expr


# Rendering

@docs Version, renderElmModule


# Utils

@docs normalizeFunctionName

-}

import StringUtil exposing (indent)


{-| An elm module with its name and the functions it defines.
-}
type Module
    = Module String (List Function)


{-| An elm function with its name, the list of arguments, the return type and its body.
-}
type Function
    = Function String (List Arg) String Expr


{-| An elm function argument, containing both the name and the type.

Can either be a Primitive with name and type or a Record with the name and type of each field in the record.

-}
type Arg
    = Primitive String String
    | Record (List ( String, String ))


{-| An elm expression.

Can either be a Ifs (a if / else if / else block) with the expressions for the test condition and the body or
can be a Case with the variable to match on and a list of values to match with and body pairs or
can be an Expr with the expression.

-}
type Expr
    = Ifs (List ( Expr, Expr ))
    | Case String (List ( String, String ))
    | Expr String


{-| Supported Elm versions.
-}
type Version
    = Elm_0_18
    | Elm_0_19


{-| Renders a whole module to string compatible with the given elm version.
-}
renderElmModule : Version -> Module -> String
renderElmModule version (Module name body) =
    let
        renderedBody =
            List.map renderElmFunction (toStringHelper version :: body)
    in
    (("module " ++ name ++ " exposing (..)") :: renderedBody)
        |> String.join "\n\n\n"


{-| AST of an helper function to abstract differences between elm versions on handling int to string conversions.
-}
toStringHelper : Version -> Function
toStringHelper version =
    Function "fromInt" [ Primitive "Int" "int" ] "String" <|
        case version of
            Elm_0_18 ->
                Expr "toString int"

            Elm_0_19 ->
                Expr "String.fromInt int"


{-| Renders a function to string.
-}
renderElmFunction : Function -> String
renderElmFunction (Function name args returnType body) =
    let
        renderedArgs =
            (List.map renderElmType args ++ [ returnType ])
                |> String.join " -> "

        annotation =
            name ++ " : " ++ renderedArgs

        definition =
            (name :: List.map renderElmParam args ++ [ "=" ])
                |> String.join " "
    in
    [ annotation, definition, indent (renderElmExpr body) ]
        |> String.join "\n"


{-| Renders a type to string.
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


{-| Renders a parameter name to string, intended to be used when rendering a function's arguments.
-}
renderElmParam : Arg -> String
renderElmParam arg =
    case arg of
        Primitive _ param ->
            param

        Record types ->
            "params_"


{-| Renders an expression to string.
-}
renderElmExpr : Expr -> String
renderElmExpr expr =
    case expr of
        Ifs alternatives ->
            case alternatives of
                -- Don't render condition when there is only one branch
                [ ( Expr cond, Expr subExpr ) ] ->
                    subExpr

                ( Expr cond, Expr headExpr ) :: tail ->
                    ([ "if " ++ cond ++ " then"
                     , indent headExpr
                     , ""
                     ]
                        |> String.join "\n"
                    )
                        ++ renderElseIf tail

                _ ->
                    ""

        Case matched variants ->
            ("case " ++ matched ++ " of\n")
                ++ indent
                    ((List.map renderElmCaseVariant variants ++ [ renderElmCaseWildcardVariant ])
                        |> String.join "\n"
                    )

        Expr body ->
            body


{-| Recursive function rendering the else if and else parts of an Ifs.
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
                ++ renderElseIf tail

        _ ->
            ""


{-| Renders a match arm.
-}
renderElmCaseVariant : ( String, String ) -> String
renderElmCaseVariant ( match, body ) =
    ("\"" ++ match ++ "\" ->\n")
        ++ indent (body ++ "\n")


{-| Renders the wildcard variant of a case expression.

Used to render the behaviour of keyname not found when doing a translation.

-}
renderElmCaseWildcardVariant : String
renderElmCaseWildcardVariant =
    "_ ->\n"
        ++ indent "\"\""


{-| Formats a string to match elm rules on function name.
-}
normalizeFunctionName : String -> String
normalizeFunctionName =
    String.toLower
        >> replaceMatches (\c -> not (Char.isLower c || Char.isDigit c)) '_'
        >> (\name ->
                let
                    needsPrefix =
                        name
                            |> String.toList
                            |> List.head
                            |> Maybe.map Char.isDigit
                            |> Maybe.withDefault True
                in
                if needsPrefix then
                    "f_" ++ name

                else if String.startsWith "_" name then
                    "f" ++ name

                else
                    name
           )


{-| Replaces characters matching predicate with the given character.
-}
replaceMatches : (Char -> Bool) -> Char -> String -> String
replaceMatches predicate replacement =
    String.toList
        >> List.map
            (\c ->
                if predicate c then
                    replacement

                else
                    c
            )
        >> String.fromList
