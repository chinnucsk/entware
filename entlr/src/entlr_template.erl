%% Author: kbmurali
%% Created: Mar 12, 2012
%% Description: TODO: Add description to entlr_template
-module(entlr_template).

%%
%% Include files
%%

%%
%% Exported Functions
%%
-compile([export_all]).

%%
%% API Functions
%%
process( [], [], _, Vars, true ) ->
	{true, [], Vars };
process( [], [], _, _, false ) ->
	false;
process( [], Input, _, Vars, true ) ->
	{true, Input, Vars };
process( [], _Input, _, _Vars, false ) ->
	false;
process( _, [], _, _, _ ) ->
	false;
process( [ {_,or_cond, _} = Cond | Rest ], Input, Trim_Left, Vars, false ) ->
	case match( Cond, Input, Trim_Left ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			process( Rest, N_Input, Trim_Left, N_Vars, true );
		false ->
			process( Rest, Input, Trim_Left, Vars, false )
	end;
process( _, _, _, _, false ) ->
	false;
process( [ Cond | Rest ], Input, Trim_Left, Vars, true ) ->
	case match( Cond, Input, Trim_Left ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			process( Rest, N_Input, Trim_Left, N_Vars, true );
		false ->
			process( Rest, Input, Trim_Left, Vars, false )
	end.

match( {_, token, RE}, Input, Trim_Left ) ->
	String = trim_left( Input, Trim_Left ),
	case re:run( String, RE ) of
		{match, [ {0,L} | _ ] } ->
			case length(String) == L of
				true ->
					{true, [], [] };
				false ->
					N_Input = string:sub_string( String, L+1 ),
					{true, N_Input, [] }
			end;
		_ ->
			false
	end;
match( {_, var_token, {Var, RE} }, Input, Trim_Left ) ->
	String = trim_left( Input, Trim_Left ),
	case re:run( String, RE ) of
		{match, [ {0,L} | _ ] } ->
			Match = string:substr(String, 1, L),
			
			case length(String) == L of
				true ->
					{true, [], [{Var, Match}] };
				false ->
					N_Input = string:sub_string( String, L+1 ),
					{true, N_Input, [{Var, Match}] }
			end;
		_ ->
			false
	end;
match( {_, rule, Rule_Name }, Input, _Trim_Left ) ->
	R_Fun_Name = create_rule_fun_name( Rule_Name ),
	R_Fun = list_to_atom( R_Fun_Name ),
	Mod = module_name(),
	case catch apply( Mod, R_Fun, [Input] ) of
		{error, invalid_input, _} ->
			false;
		{true, [], _} ->
			{true, [], []};
		{partial, Part_Remaining, _ } ->
			{true, Part_Remaining, [] }
	end;
match( {_, and_cond, List }, Input, Trim_Left ) ->
	and_cond( List, Input, Trim_Left, [] );
match( {_, or_cond, List }, Input, Trim_Left ) ->
	or_cond( List, Input, Trim_Left, [] );
match( {_, multi_cond, List }, Input, Trim_Left ) ->
	multi_cond( List, Input, Trim_Left, [], 0 ).


and_cond( [], [], _, Vars ) ->
	{true, [], Vars };
and_cond( [], Input, _, Vars ) ->
	{true, Input, Vars };
and_cond( _, [], _, _ ) ->
	false;
and_cond( [ Cond | Rest ], Input, Trim_Left, Vars  ) ->
	case match( Cond, Input, Trim_Left  ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			and_cond( Rest, N_Input, Trim_Left, N_Vars );
		false ->
			false
	end.

or_cond( [], [], _, _ ) ->
	false;
or_cond( [], _, _, _ ) ->
	false;
or_cond( _, [], _, _ ) ->
	false;
or_cond( [ Cond | Rest ], Input, Trim_Left, Vars ) ->
	case match( Cond, Input, Trim_Left ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			{true, N_Input, N_Vars};
		false ->
			or_cond( Rest, Input, Trim_Left, Vars )
	end.

multi_cond( Conditions, Input, Trim_Left, Vars, 0 ) ->
	case multi_cond_loop( Conditions, Input, Trim_Left, Vars ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			multi_cond( Conditions, N_Input, Trim_Left, N_Vars, 1 );
		false ->
			false
	end;
multi_cond( Conditions, Input, Trim_Left, Vars, N ) ->
	case multi_cond_loop( Conditions, Input, Trim_Left, Vars ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			multi_cond( Conditions, N_Input, Trim_Left, N_Vars, N+1 );
		false ->
			{true, Input, Vars}
	end.

multi_cond_loop( [], [], _, Vars) ->
	{true, [], Vars };
multi_cond_loop( [], Input, _, Vars ) ->
	{true, Input, Vars };
multi_cond_loop( _, [], _, _ ) ->
	false;
multi_cond_loop( [ Cond | Rest ], Input, Trim_Left, Vars ) ->
	case match( Cond, Input, Trim_Left ) of
		{true, N_Input, I_Vars } ->
			N_Vars = resolve_append( Vars, I_Vars ),
			multi_cond_loop( Rest, N_Input, Trim_Left, N_Vars );
		false ->
			false
	end.

trim_left( Input, true ) ->
	string:strip( Input, left );
trim_left( Input, false ) ->
	Input.

module_name() ->
	try
		throw( error )
	catch
		_:_ ->
			[ Term | _ ] = erlang:get_stacktrace(),
			case Term of
				{Mod, _, _} ->
					Mod;
				{Mod, _, _, _} ->
					Mod
			end
	end.

create_rule_match_fun_name( Rule_Name ) -> 
	string:to_lower( Rule_Name ) ++ "_match".

create_rule_fun_name( Rule_Name ) ->
	string:to_lower( Rule_Name ).

create_rule_execute_fun_name(Rule_Name) ->
	string:to_lower( Rule_Name ) ++ "_execute_fun".

resolve_append( Vars, I_Vars ) ->
	Fun = fun( {Var,Value}, Acc ) ->
				  case lists:keyfind(Var, 1, Acc ) of
					  false ->
						  [ {Var, Value} | Acc ];
					  _ ->
						  lists:keyreplace(Var, 1, Acc, {Var,Value} )
				  end
		  end,
	lists:foldr(Fun, Vars, I_Vars ).