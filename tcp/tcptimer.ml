(*
 * Copyright (c) 2012 Balraj Singh <bs375@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt.Infix

let debug = Log.create "TCP.Tcptimer"

type tr =
  | Stoptimer
  | Continue of Sequence.t
  | ContinueSetPeriod of (float * Sequence.t)

type t = {
  expire: (Sequence.t -> tr Lwt.t);
  mutable period: float;
  mutable running: bool;
}

module Make(Time:V1_LWT.TIME) = struct
  let t ~period ~expire =
    let running = false in
    {period; expire; running}

  let timerloop t s =
    Log.s debug "timerloop";
    Stats.incr_timer ();
    let rec aux t s =
      Time.sleep t.period >>= fun () ->
      t.expire s >>= function
      | Stoptimer ->
        Stats.decr_timer ();
        t.running <- false;
        Log.s debug "timerloop: stoptimer";
        Lwt.return_unit
      | Continue d ->
        Log.s debug "timerloop: continuer";
        aux t d
      | ContinueSetPeriod (p, d) ->
        Log.s debug "timerloop: coontinuesetperiod";
        t.period <- p;
        aux t d
    in
    aux t s

  let period t = t.period

  let start t ?(p=(period t)) s =
    if not t.running then begin
      t.period <- p;
      t.running <- true;
      Lwt.async (fun () -> timerloop t s);
      Lwt.return_unit
    end else
      Lwt.return_unit
end
