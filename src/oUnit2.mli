(***********************************************************************)
(* The OUnit library                                                   *)
(*                                                                     *)
(* Copyright (C) 2013 Sylvain Le Gall                                  *)
(*                                                                     *)
(* See LICENSE for details.                                            *)
(***********************************************************************)

(** Unit test building blocks (v2).

    @author Sylvain Le Gall
  *)

(** {2 Types} *)

(** Context of a test. *)
type test_ctxt

(** The type of test function *)
type test_fun = test_ctxt -> unit

(** The type of tests *)
type test

(** {2 Assertions}

    Assertions are the basic building blocks of unittests. *)

(** Signals a failure. This will raise an exception with the specified
    string.

    @raise Failure signal a failure *)
val assert_failure : string -> 'a

(** Signals a failure when bool is false. The string identifies the
    failure.

    @raise Failure signal a failure *)
val assert_bool : string -> bool -> unit

(** Shorthand for assert_bool

    @raise Failure to signal a failure *)
val ( @? ) : string -> bool -> unit

(** Signals a failure when the string is non-empty. The string identifies the
    failure.

    @raise Failure signal a failure *)
val assert_string : string -> unit

(** [assert_command prg args] Run the command provided.

    @param exit_code expected exit code
    @param sinput provide this [char Stream.t] as input of the process
    @param foutput run this function on output, it can contains an
                   [assert_equal] to check it
    @param use_stderr redirect [stderr] to [stdout]
    @param env Unix environment
    @param verbose if a failed, dump stdout/stderr of the process to stderr
  *)
val assert_command :
    ?exit_code:Unix.process_status ->
    ?sinput:char Stream.t ->
    ?foutput:(char Stream.t -> unit) ->
    ?use_stderr:bool ->
    ?env:string array ->
    ctxt:test_ctxt ->
    string -> string list -> unit

(** [assert_equal expected real] Compares two values, when they are not equal a
    failure is signaled.

    @param cmp customize function to compare, default is [=]
    @param printer value printer, don't print value otherwise
    @param pp_diff if not equal, ask a custom display of the difference
                using [diff fmt exp real] where [fmt] is the formatter to use
    @param msg custom message to identify the failure

    @raise Failure signal a failure

    @version 1.1.0
  *)
val assert_equal :
  ?cmp:('a -> 'a -> bool) ->
  ?printer:('a -> string) ->
  ?pp_diff:(Format.formatter -> ('a * 'a) -> unit) ->
  ?msg:string -> 'a -> 'a -> unit

(** Asserts if the expected exception was raised.

    @param msg identify the failure

    @raise Failure description *)
val assert_raises : ?msg:string -> exn -> (unit -> 'a) -> unit

(** {2 Skipping tests }

    In certain condition test can be written but there is no point running it,
    because they are not significant (missing OS features for example). In this
    case this is not a failure nor a success. Following functions allow you to
    escape test, just as assertion but without the same error status.

    A test skipped is counted as success. A test todo is counted as failure.
  *)

(** [skip cond msg] If [cond] is true, skip the test for the reason explain in
    [msg]. For example [skip_if (Sys.os_type = "Win32") "Test a doesn't run on
    windows"].
  *)
val skip_if : bool -> string -> unit

(** The associated test is still to be done, for the reason given.
  *)
val todo : string -> unit

(** {2 Compare Functions} *)

(** Compare floats up to a given relative error.

    @param epsilon if the difference is smaller [epsilon] values are equal
  *)
val cmp_float : ?epsilon:float -> float -> float -> bool

(** {2 Bracket}

    A bracket is a registered object with setUp and tearDown in unit tests.
    Data generated during the setUp will be automatically tearDown when the test
    ends.
  *)

(** [bracket set_up tear_down test_ctxt] set up an object and register it to be
    tore down in [test_ctxt].
  *)
val bracket : (test_ctxt -> 'a) -> ('a -> test_ctxt -> unit) -> test_ctxt -> 'a

(** [bracket_tmpfile test_ctxt] Create a temporary filename and matching output
    channel. The temporary file is removed after the test.

    @param prefix see [Filename.open_temp_file]
    @param suffix see [Filename.open_temp_file]
    @param mode see [Filename.open_temp_file]
  *)
val bracket_tmpfile:
  ?prefix:string ->
  ?suffix:string ->
  ?mode:open_flag list ->
  test_ctxt -> (string * out_channel)

(** [bracket_tmpdir test] Create a temporary dirname. The temporary directory is
    removed after the test.

    @param prefix see [Filename.open_temp_file]
    @param suffix see [Filename.open_temp_file]
  *)
val bracket_tmpdir:
  ?prefix:string ->
  ?suffix:string ->
  test_ctxt -> string

(** {2 Constructing Tests} *)

(** Create a TestLabel for a test *)
val (>:) : string -> test -> test

(** Create a TestLabel for a TestCase *)
val (>::) : string -> test_fun -> test

(** Create a TestLabel for a TestList *)
val (>:::) : string -> test list -> test

(** Generic function to create a test case. *)
val test_case : test_fun -> test

(** Generic function to create a test list. *)
val test_list : test list -> test

(** Some shorthands which allows easy test construction.

   Examples:

   - ["test1" >: TestCase((fun _ -> ()))] =>
   [TestLabel("test2", TestCase((fun _ -> ())))]
   - ["test2" >:: (fun _ -> ())] =>
   [TestLabel("test2", TestCase((fun _ -> ())))]
   - ["test-suite" >::: ["test2" >:: (fun _ -> ());]] =>
   [TestLabel("test-suite", TestSuite([TestLabel("test2",
                                       TestCase((fun _ -> ())))]))]
*)

(** {2 Performing Tests} *)

(** Severity level for log. *)
type log_severity = [ `Error | `Warning | `Info ]

(** Log into OUnit logging system.
  *)
val logf: test_ctxt -> log_severity -> ('a, unit, string, unit) format4 -> 'a

(** Main version of the text based test runner. It reads the supplied command
    line arguments to set the verbose level and limit the number of test to
    run.

    @param test the test suite to run.
  *)
val run_test_tt_main : ?exit:(int -> unit) -> test -> unit

(* TODO: comment. *)
val conf_make_string: string -> string -> Arg.doc -> test_ctxt -> string
val conf_make_string_opt:
    string -> string option -> Arg.doc -> test_ctxt -> string option
val conf_make_int: string -> int -> Arg.doc -> test_ctxt -> int
val conf_make_bool: string -> bool -> Arg.doc -> test_ctxt -> bool
