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

func test_on_offer_with_no_filters_always_fires() -> void:
	var t := OnOffer.new()
	h.check("unfiltered means every offer", t.matches(EffectContext.new()))

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
