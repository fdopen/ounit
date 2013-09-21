
open OUnitLogger
open OUnitTest
open OUnitResultSummary

let ocaml_position pos =
  Printf.sprintf
    "File \"%s\", line %d, characters 1-1:"
    pos.filename pos.line

let multiline f str = 
  if String.length str > 0 then
    let buf = Buffer.create 80 in
    let flush () = f (Buffer.contents buf); Buffer.clear buf in
      String.iter
        (function '\n' -> flush () | c -> Buffer.add_char buf c)
        str;
      flush ()

let count results f =
  List.fold_left
    (fun count (_, test_result, _) -> 
       if f test_result then count + 1 else count)
    0 results

(* TODO: deprecate in 2.1.0. *)
let results_style_1_X =
  OUnitConf.make_bool
    "results_style_1_X"
    false
    "Use OUnit 1.X results printer (will be deprecated in 2.1.0+)."

let format_display_event conf log_event =
  match log_event.event with
    | GlobalEvent e ->
        begin
          match e with
            | GConf (_, _) | GLog _ | GStart | GEnd -> ""
            | GResults (running_time, results, test_case_count) ->
                let separator1 = String.make (Format.get_margin ()) '=' in
                let separator2 = String.make (Format.get_margin ()) '-' in
                let buf = Buffer.create 1024 in
                let bprintf fmt = Printf.bprintf buf fmt in
                let print_results =
                  List.iter
                    (fun (path, test_result, pos_opt) ->
                       bprintf "%s\n" separator1;
                       if results_style_1_X conf then begin
                         bprintf "%s: %s\n\n"
                           (result_flavour test_result)
                           (string_of_path path);
                       end else begin
                         bprintf "Error: %s%s\n\n"
                           (string_of_path path)
                           (if pos_opt <> None then " (in the log)." else "");
                         begin
                           match pos_opt with
                             | Some pos ->
                                 bprintf "%s\n" (ocaml_position pos)
                             | None ->
                                 ()
                         end;
                         begin
                           match test_result with
                             | RError (_, Some backtrace) ->
                                 bprintf "%s\n" backtrace
                             | RFailure (_, Some pos, _) ->
                                 bprintf "%s\nError: %s (in the code).\n\n"
                                   (ocaml_position pos)
                                   (string_of_path path)
                             | RFailure (_, _, Some backtrace) ->
                                 bprintf "%s\n" backtrace
                             | _ ->
                                 ()
                         end;
                       end;
                       bprintf "%s\n" (result_msg test_result);
                       bprintf "%s\n" separator2)
                in
                let filter f =
                  let lst =
                    List.filter
                      (fun (_, test_result, _) -> f test_result)
                      results
                  in
                    lst, List.length lst
                in
                let errors, nerrors     = filter is_error in
                let failures, nfailures = filter is_failure in
                let skips, nskips       = filter is_skip in
                let todos, ntodos       = filter is_todo in
                let timeouts, ntimeouts = filter is_timeout in
                  bprintf "\n";
                  print_results errors;
                  print_results failures;
                  print_results timeouts;
                  bprintf "Ran: %d tests in: %.2f seconds.\n"
                    (List.length results) running_time;

                  (* Print final verdict *)
                  if was_successful results then
                    begin
                      if skips = [] then
                        bprintf "OK"
                      else
                        bprintf "OK: Cases: %d Skip: %d"
                          test_case_count nskips
                    end
                  else
                    begin
                      bprintf
                        "FAILED: Cases: %d Tried: %d Errors: %d \
                              Failures: %d Skip:  %d Todo: %d \
                              Timeouts: %d."
                        test_case_count
                        (List.length results)
                        nerrors
                        nfailures
                        nskips
                        ntodos
                        ntimeouts;
                    end;
                  bprintf "\n";
                  Buffer.contents buf
        end

    | TestEvent (_, e) ->
        begin
          match e with
            | EStart _ | EEnd _ | ELog _ | ELogRaw _ -> ""
            | EResult RSuccess -> "."
            | EResult (RFailure _) -> "F"
            | EResult (RError _) -> "E"
            | EResult (RSkip _) -> "S"
            | EResult (RTodo _) -> "T"
            | EResult (RTimeout _) -> "~"
        end

let format_log_event ev = 
  let rlst = ref [] in
  let timestamp_str = OUnitUtils.date_iso8601 ev.timestamp in
  let spf pre fmt = 
    Printf.ksprintf
      (multiline 
         (fun l ->
            rlst := (timestamp_str^" "^ev.shard^" "^pre^": "^l) :: !rlst))
      fmt
  in
  let ispf fmt = spf "I" fmt in
  let wspf fmt = spf "W" fmt in
  let espf fmt = spf "E" fmt in
  let format_result path result =
    let path_str = string_of_path path in
    match result with 
    | RTimeout test_length ->
        espf "Test %s timed out after %.1fs"
          path_str (delay_of_length test_length)
    | RError (msg, backtrace_opt) ->
        espf "Test %s exited with an error." path_str;
        espf "%s in test %s." msg path_str;
        OUnitUtils.opt (espf "%s") backtrace_opt
    | RFailure (msg, _, backtrace_opt) ->
        espf "Test %s has failed." path_str;
        espf "%s in test %s." msg path_str;
        OUnitUtils.opt (espf "%s") backtrace_opt
    | RTodo msg -> wspf "TODO test %s: %s." path_str msg
    | RSkip msg -> wspf "Skip test %s: %s." path_str msg
    | RSuccess -> ispf "Test %s is successful." path_str
  in

  begin
    match ev.event with
      | GlobalEvent e ->
          begin
            match e with
            | GConf (k, v) -> ispf "Configuration %s = %S" k v
            | GLog (`Error, str) -> espf "%s" str
            | GLog (`Warning, str) -> wspf "%s" str
            | GLog (`Info, str) -> ispf "%s" str
            | GStart -> ispf "Start testing."
            | GEnd -> ispf "End testing."
            | GResults (running_time, results, test_case_count) ->
                let countr = count results in
                ispf "==============";
                ispf "Summary:";
                List.iter
                  (fun (path, test_result, _) ->
                     format_result path test_result)
                  results;
                (* Print final verdict *)
                ispf "Ran: %d tests in: %.2f seconds."
                  (List.length results) running_time;
                ispf "Cases: %d." test_case_count;
                ispf "Tried: %d." (List.length results);
                ispf "Errors: %d." (countr is_error);
                ispf "Failures: %d." (countr is_failure);
                ispf "Skip: %d." (countr is_skip);
                ispf "Todo: %d." (countr is_todo);
                ispf "Timeout: %d." (countr is_timeout)
          end

      | TestEvent (path, e) ->
          begin
            let path_str = string_of_path path in
            match e with
            | EStart -> ispf "Start test %s." path_str
            | EEnd -> ispf "End test %s." path_str
            | EResult result -> format_result path result
            | ELog (`Error, str) -> espf "%s" str
            | ELog (`Warning, str) -> wspf "%s" str
            | ELog (`Info, str) -> ispf "%s" str
            | ELogRaw str -> ispf "%s" str
          end
  end;
  List.rev !rlst

let file_logger conf fn =
  let chn = open_out fn in
  let line = ref 1 in

  let fwrite ev =
    List.iter
      (fun l -> output_string chn l; output_char chn '\n'; incr line)
      (format_log_event ev);
    flush chn
  in
  let fpos () =
    Some { filename = fn; line = !line }
  in
  let fclose () =
    close_out chn
  in
    {
      lshard = shard_default;
      fwrite = fwrite;
      fpos   = fpos;
      fclose = fclose;
    }

let verbose =
  OUnitConf.make_bool
    "verbose"
    false
    "Run test in verbose mode."

let display =
  OUnitConf.make_bool
    "display"
    true
    "Output logs on screen."

let std_logger conf =
  if display conf then
    let verbose = verbose conf in
    let fwrite log_ev =
      if verbose then
        List.iter print_endline (format_log_event log_ev)
      else
        print_string (format_display_event conf log_ev);
      flush stdout
    in
      {
        lshard = shard_default;
        fwrite = fwrite;
        fpos   = (fun () -> None);
        fclose = ignore;
      }
  else
    null_logger

let output_file =
  OUnitConf.make_string_subst_opt
    "output_file"
    (Some (Filename.concat OUnitUtils.buildir "oUnit-$(suite_name).log"))
    "Output verbose log in the given file."

let create conf =
  let std_logger=
    std_logger conf
  in
  let file_logger =
    match output_file conf with
      | Some fn ->
          file_logger conf fn
      | None ->
          null_logger
  in
    combine [std_logger; file_logger]
