extends RefCounted
var h: Harness

func test_on_offer_fires_only_when_short_enough() -> void:
	var t := OnOffer.new()
	t.short_at = 8
	var ctx := EffectContext.new()
	ctx.short = 3
	h.check("a near miss does not set them off", not t.matches(ctx))
	ctx.short = 8
	h.check("a big miss does", t.matches(ctx))

func test_on_offer_can_filter_by_how_badly_they_rank_it() -> void:
	var t := OnOffer.new()
	t.rank_worse_than = 5
	var ctx := EffectContext.new()
	ctx.rank = 5
	h.check("inside their top five is fine", not t.matches(ctx))
	ctx.rank = 6
	h.check("below it is not", t.matches(ctx))

func test_on_offer_with_no_filters_always_fires() -> void:
	var t := OnOffer.new()
	h.check("unfiltered means every offer", t.matches(EffectContext.new()))

func test_on_sale_can_require_a_bullseye() -> void:
	var t := OnSale.new()
	t.rank_better_than = 3
	var ctx := EffectContext.new()
	ctx.rank = 2
	h.check("their second counts", t.matches(ctx))
	ctx.rank = 3
	h.check("their third does not", not t.matches(ctx))

func test_on_sale_with_no_filter_fires_on_any_sale() -> void:
	h.check("unfiltered means every sale",
		OnSale.new().matches(EffectContext.new()))

func test_patience_below_fires_under_the_mark() -> void:
	var t := PatienceBelow.new()
	t.at = 5
	var ctx := EffectContext.new()
	ctx.patience = 5
	h.check("at the mark, not yet", not t.matches(ctx))
	ctx.patience = 4
	h.check("under it, yes", t.matches(ctx))

func test_every_trigger_describes_its_cadence() -> void:
	var t := Every.new()
	t.ticks = 5
	h.check("says how often", t.describe().contains("5"))

func test_every_trigger_type_describes_itself() -> void:
	for t in [OnOffer.new(), OnSale.new(), Every.new(), PatienceBelow.new()]:
		h.check("%s describes itself" % t.get_script().resource_path.get_file(),
			t.describe().strip_edges() != "")
