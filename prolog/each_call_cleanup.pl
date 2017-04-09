/* Part of SWI-Prolog

    Author:        Douglas R. Miles, ...
    E-mail:        logicmoo@gmail.com
    WWW:           http://www.logicmoo.org
    Copyright (c)  2016-2017, LogicMOO Basic Tools
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(each_call_cleanup,
   [
      each_call_cleanup/3,             % +Setup, +Goal, +Cleanup      
      each_call_catcher_cleanup/4,     % +Setup, +Goal, ?Catcher, +Cleanup
      redo_call_cleanup/3              % +Setup, +Goal, +Cleanup
    ]).

/** <module> Each call cleanup

Call Setup Goal Cleanup *Each* Iteration

@see  https://groups.google.com/forum/#!searchin/comp.lang.prolog/redo_call_cleanup%7Csort:relevance/comp.lang.prolog/frH_4RzMAHg/2bBub5t6AwAJ

*/

:- meta_predicate
  redo_call_cleanup(0,0,0),
  each_call_catcher_cleanup(0,0,?,0),
  each_call_cleanup(0,0,0).

:- module_transparent(pt1/1).
:- module_transparent(pt2/1).
  

%! redo_call_cleanup(:Setup, :Goal, :Cleanup).
%
% @warn Setup/Cleanup do not share variables.
% If that is needed, use each_call_cleanup/3 

redo_call_cleanup(Setup,Goal,Cleanup):- 
   assertion(each_call_cleanup:unshared_vars(Setup,Goal,Cleanup)),  
   \+ \+ '$sig_atomic'(Setup),
   catch( 
     ((Goal, deterministic(DET)),
       '$sig_atomic'(Cleanup),
         (DET == true -> !
          ; (true;('$sig_atomic'(Setup),fail)))), 
      E, 
      ('$sig_atomic'(Cleanup),throw(E))). 


%! each_call_catcher_cleanup(:Setup, :Goal, +Catcher, :Cleanup).
%
%   Call Setup before Goal like normal but *also* before each Goal is redone.
%   Also call Cleanup *each* time Goal is finished
%  @bug Goal does not share variables with Setup/Cleanup Pairs

each_call_catcher_cleanup(Setup, Goal, Catcher, Cleanup):-
   setup_call_catcher_cleanup(true, 
     each_call_cleanup(Setup, Goal, Cleanup), Catcher, true).

:- thread_local(ecc:'$each_call_cleanup'/2).
:- thread_local(ecc:'$each_call_undo'/2).

%! each_call_cleanup(:Setup, :Goal, :Cleanup).
%
%   Call Setup before Goal like normal but *also* before each Goal is redone.
%   Also call Cleanup *each* time Goal is finished
%  @bug Goal does not share variables with Setup/Cleanup Pairs

each_call_cleanup(Setup,Goal,Cleanup):- 
 ((ground(Setup);ground(Cleanup)) -> 
  redo_call_cleanup(Setup,Goal,Cleanup);
  setup_call_cleanup(
   asserta((ecc:'$each_call_cleanup'(Setup,Cleanup)),HND), 
   redo_call_cleanup(pt1(HND),Goal,pt2(HND)),
   (pt2(HND),erase(HND)))).

 		 /*******************************
		 *	  UTILITIES		*
		 *******************************/

ecc:throw_failure(Why):- throw(error(assertion_error(Why),_)).

pt1(HND) :- 
   clause(ecc:'$each_call_cleanup'(Setup,Cleanup),true,HND) 
   ->
   ('$sig_atomic'(Setup) -> 
     asserta(ecc:'$each_call_undo'(HND,Cleanup)) ; 
       ecc:throw_failure(failed_setup(Setup)))
   ; 
   ecc:throw_failure(pt1(HND)).

pt2(HND) :- 
  retract(ecc:'$each_call_undo'(HND,Cleanup)) ->
    ('$sig_atomic'(Cleanup)->true ;ecc:throw_failure(failed_cleanup(Cleanup)));
      ecc:throw_failure(failed('$each_call_undo'(HND))).

:- if(true).
:- system:import(each_call_cleanup/3).
:- system:import(each_call_catcher_cleanup/4).
:- system:import(redo_call_cleanup/3).
:- system:import(pt1/1).
:- system:import(pt2/1).
:- endif.

% Only checks for shared vars (not shared structures)
% @TODO what if someone got tricky with setarging?
unshared_vars(Setup,_,_):- ground(Setup),!.
unshared_vars(Setup,Goal,Cleanup):- 
   term_variables(Setup,SVs),
   term_variables(Cleanup,CVs),
   ( CVs==[] -> true; unshared_set(SVs,CVs)),
   term_variables(Goal,GVs),
   ( GVs==[] -> true; 
     (unshared_set(SVs,GVs),
      unshared_set(CVs,GVs))).

unshared_set([],_).
unshared_set([E1|Set1],Set2):- 
   not_in_identical(E1,Set2),
   unshared_set(Set1,Set2).

not_in_identical(X, [Y|Ys]) :- X \== Y, not_in_identical(X, Ys).


