## sim — headless balance simulator for the prototype (docs/review/pivot/2026_options.md §3: "balance by
## simulation"). Plays whole runs with a greedy bot that can see one round ahead, and reports where the
## difficulty actually sits. No renderer, so thousands of runs cost seconds.
##
##   tools/scripts/sandbox.sh proto -s res://proto/mischief_run/sim.gd -- --runs=300 [--seed=1] [--verbose]
##
## Reported per Night: how often the bot cleared the target, the Applause it reached, and which rounds
## carried the score. Also the pick rate and average contribution of every card, so a card nobody ever
## wants (or one that always wins) shows up as a number instead of a hunch.
extends SceneTree

const RUN := preload("res://proto/mischief_run/run.gd")
const CARDS := "res://proto/mischief_run/data/cards.json"
const ENCORES := "res://proto/mischief_run/data/encores.json"

## Draft at random (unbiased data on every card) unless --greedy-draft is passed (how strong the deck
## can get). A greedy drafter with no play history never tries a card it has not already seen, which
## silently reports the whole pool as worthless — so random is the honest default for a balance report.
var _random_draft := true
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_random_draft = not args.has("greedy-draft")
	quit(_run(int(args.get("runs", 200)), int(args.get("seed", 1)), args.has("verbose")))


func _json(path: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("cannot parse %s" % path)
		return {}
	return j.data


func _run(n_runs: int, seed_v: int, verbose: bool) -> int:
	_rng.seed = seed_v
	var cards := _json(CARDS)
	var encores := _json(ENCORES)
	if cards.is_empty() or encores.is_empty():
		return 1
	var reached := {}          # night -> times the bot got there
	var cleared := {}          # night -> times it cleared the target
	var score_sum := {}        # night -> total Applause
	var picks := {}            # card/encore id -> times drafted
	var gain_sum := {}         # card id -> total Applause it produced
	var gain_n := {}           # card id -> times it fired
	var round_sum := {}        # round index -> total Applause
	var wins := 0
	for i in n_runs:
		var r: Run = RUN.new()
		r.setup(cards, encores, seed_v + i)
		while not r.over:
			var night: int = r.night
			reached[night] = int(reached.get(night, 0)) + 1
			var outcome := _play_night(r, picks, gain_sum, gain_n, round_sum)
			if outcome != "lost":
				cleared[night] = int(cleared.get(night, 0)) + 1
			score_sum[night] = int(score_sum.get(night, 0)) + r.applause
			if outcome == "won":
				wins += 1
				break
			if outcome == "lost":
				break
			r.next_night()
	print("\n=== MISCHIEF RUN — balance report (%d runs, greedy bot) ===" % n_runs)
	print("draft policy: %s" % ("random (unbiased)" if _random_draft else "greedy"))
	print("full clears: %d / %d  (%.1f%%)" % [wins, n_runs, 100.0 * float(wins) / float(maxi(1, n_runs))])
	print("\nNight  target   reached   cleared   clear%%   avg Applause")
	for night in range(1, Run.TARGETS.size() + 1):
		var re := int(reached.get(night, 0))
		if re == 0:
			continue
		var cl := int(cleared.get(night, 0))
		print("  %d     %4d     %5d     %5d    %5.1f%%   %6.1f" % [night, int(Run.TARGETS[night - 1]),
			re, cl, 100.0 * float(cl) / float(re), float(score_sum.get(night, 0)) / float(re)])
	print("\nApplause by round of a Night (all Nights pooled):")
	for k in range(1, Run.ROUNDS_PER_NIGHT + 1):
		print("  round %d: %7d" % [k, int(round_sum.get(k, 0))])
	print("\nCard                  drafted   fired   avg gain")
	var ids: Array = (cards.get("cards", {}) as Dictionary).keys()
	var avg := {}
	for id: String in ids:
		avg[id] = float(gain_sum.get(id, 0)) / float(maxi(1, int(gain_n.get(id, 0))))
	ids.sort_custom(func(a, b): return float(avg[a]) > float(avg[b]))
	for id: String in ids:
		print("  %-20s %5d   %5d   %7.1f" % [id, int(picks.get(id, 0)), int(gain_n.get(id, 0)), float(avg[id])])
	print("\nEncore                drafted")
	for id: String in (encores.get("encores", {}) as Dictionary):
		print("  %-20s %5d" % [id, int(picks.get("enc:" + id, 0))])
	if verbose:
		print("\n(greedy bot: each round it repeatedly takes the single placement that scores best on a\n full resolve, until Nerve runs out; drafts the offer with the best average gain so far.)")
	return 0


## Play one Night to its end. Returns "won" | "night_won" | "lost".
func _play_night(r: Run, picks: Dictionary, gain_sum: Dictionary, gain_n: Dictionary,
		round_sum: Dictionary) -> String:
	while true:
		var before: int = r.applause
		var rnd: int = r.round_i
		_greedy_place(r)
		var steps := r.resolve()
		for s: Dictionary in steps:
			if bool(s.get("fired", false)) and str(s.get("card", "")) != "":
				var id := str(s["card"])
				gain_sum[id] = int(gain_sum.get(id, 0)) + int(s["gain"])
				gain_n[id] = int(gain_n.get(id, 0)) + 1
		round_sum[rnd] = int(round_sum.get(rnd, 0)) + (r.applause - before)
		var outcome := r.finish_round()
		if outcome != "draft":
			return outcome
		var offers := r.draft_options()
		var best := 0
		if _random_draft:
			best = _rng.randi_range(0, offers.size() - 1)
		else:
			var best_v := -1.0
			for i in offers.size():
				var id := str(offers[i])
				var v := 9.0
				if not id.begins_with("enc:"):
					# a card never drafted yet is worth its printed base, so the bot explores the pool
					var seen := int(gain_n.get(id, 0))
					v = float(gain_sum.get(id, 0)) / float(seen) if seen > 0 \
						else float((r.cards.get(id, {}) as Dictionary).get("base", 0))
				if v > best_v:
					best_v = v
					best = i
		picks[str(offers[best])] = int(picks.get(str(offers[best]), 0)) + 1
		r.take_draft(best)
	return "lost"


## Repeatedly take the single best placement available, measured by actually resolving the board.
func _greedy_place(r: Run) -> void:
	while true:
		var base := r.snapshot()
		var probe := r.resolve()
		var now: int = r.applause
		r.restore(base)
		var best_hand := -1
		var best_pos := -1
		var best_gain := now
		for h in r.hand.size():
			for p in Run.N_STATIONS:
				if r.board[p] != "" or r.cost_of(r.hand[h]) > r.nerve:
					continue
				var s := r.snapshot()
				if r.place(h, p) != "":
					r.restore(s)
					continue
				r.resolve()
				var got: int = r.applause
				r.restore(s)
				if got > best_gain:
					best_gain = got
					best_hand = h
					best_pos = p
		if best_hand < 0:
			return
		r.place(best_hand, best_pos)
