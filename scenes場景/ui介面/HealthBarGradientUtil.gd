# res://scenes場景/ui介面/HealthBarGradientUtil.gd
extends RefCounted
class_name HealthBarGradientUtil
## 血條「填色」共用：低飽和紅（左）→ 金（右），四角圓角（滿血時左右外側皆圓）；底色仍由場景 background StyleBox 負責。


const _TEX_WIDTH := 128


static func _muted_red() -> Color:
	return Color(0.68, 0.42, 0.40, 1.0)


static func _muted_gold() -> Color:
	return Color(0.86, 0.74, 0.50, 1.0)


static func _corner_radius_for_height(h: int) -> float:
	var hf := float(maxi(4, h))
	# 細條（怪物／石頭等 h≈6）：整數 h/4 會變 1px，左緣幾乎直角；改接近半高「帽形」圓角。
	if hf <= 8.5:
		return clampf(hf * 0.48, 1.25, hf * 0.5 - 0.01)
	# 主角等較高血條：與原本 StyleBoxFlat 約 3px 同級，勿拉成滿高半圓。
	return clampf(hf / 4.5, 2.0, 5.0)


## 與 `create_gradient_fill_stylebox` 內圓角一致；底色 StyleBoxFlat 請用此值對齊外框。
static func corner_radius_for_bar_height(bar_height_px: int) -> float:
	return _corner_radius_for_height(maxi(4, bar_height_px))


static func _inside_rounded_rect(xf: float, yf: float, w: float, h: float, r: float) -> bool:
	if r <= 0.001:
		return xf >= 0.0 and xf < w and yf >= 0.0 and yf < h
	if xf < r and yf < r:
		return Vector2(xf, yf).distance_to(Vector2(r, r)) <= r + 0.001
	if xf >= w - r and yf < r:
		return Vector2(xf, yf).distance_to(Vector2(w - r, r)) <= r + 0.001
	if xf < r and yf >= h - r:
		return Vector2(xf, yf).distance_to(Vector2(r, h - r)) <= r + 0.001
	if xf >= w - r and yf >= h - r:
		return Vector2(xf, yf).distance_to(Vector2(w - r, h - r)) <= r + 0.001
	return xf >= 0.0 and xf < w and yf >= 0.0 and yf < h


## bar_height_px：與 ProgressBar 內填色高度一致（custom_minimum_size.y），圓角半徑會依高度推算。
static func create_gradient_fill_stylebox(bar_height_px: int = 14) -> StyleBoxTexture:
	var h := maxi(4, bar_height_px)
	var w := _TEX_WIDTH
	var r := _corner_radius_for_height(h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wf := float(w)
	var hf := float(h)
	for y in h:
		var yf := float(y) + 0.5
		for x in w:
			var xf := float(x) + 0.5
			if not _inside_rounded_rect(xf, yf, wf, hf, r):
				continue
			var t := xf / (wf - 1.0) if w > 1 else 0.0
			var c := _muted_red().lerp(_muted_gold(), clampf(t, 0.0, 1.0))
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	return sb


## 經驗條 **`background` 槽** 的透明度（僅深灰底；**fill 漸層**不受影響）。
const XP_BAR_BACKGROUND_ALPHA := 0.38


## 深灰 RGB 沿用血條底或預設，alpha 固定為 **`XP_BAR_BACKGROUND_ALPHA`**。
static func xp_bar_background_color(theme_background_flat: Variant = null) -> Color:
	var rgb := Color(0.08, 0.08, 0.1)
	if theme_background_flat is StyleBoxFlat:
		var t := (theme_background_flat as StyleBoxFlat).bg_color
		rgb = Color(t.r, t.g, t.b)
	return Color(rgb.r, rgb.g, rgb.b, XP_BAR_BACKGROUND_ALPHA)


## 經驗條填色：左＝封印畫圈藍線 RGB（`SealManager` `line_2d.default_color` 同色不透明）、右＝滿條金色。
static func seal_draw_blue() -> Color:
	return Color(0.4, 0.8, 1.0, 1.0)


static func xp_bar_gold() -> Color:
	return Color(0.94, 0.76, 0.32, 1.0)


## 與 `create_gradient_fill_stylebox` 相同圓角與橫向 lerp 幾何，配色改藍→金（玩家／寵物 XP 共用）。
static func create_xp_gradient_fill_stylebox(bar_height_px: int = 12) -> StyleBoxTexture:
	var h := maxi(4, bar_height_px)
	var w := _TEX_WIDTH
	var r := _corner_radius_for_height(h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wf := float(w)
	var hf := float(h)
	var c0 := seal_draw_blue()
	var c1 := xp_bar_gold()
	for y in h:
		var yf := float(y) + 0.5
		for x in w:
			var xf := float(x) + 0.5
			if not _inside_rounded_rect(xf, yf, wf, hf, r):
				continue
			var t := xf / (wf - 1.0) if w > 1 else 0.0
			var c: Color = c0.lerp(c1, clampf(t, 0.0, 1.0))
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	return sb


## 與填色條同圓角邏輯的實心底（像素硬邊），對齊 `StyleBoxFlat` 平滑圓角視覺改走帳簿／像素風。
static func create_pixel_background_stylebox(bar_height_px: int, bg_color: Color) -> StyleBoxTexture:
	var h := maxi(4, bar_height_px)
	var w := _TEX_WIDTH
	var r := _corner_radius_for_height(h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wf := float(w)
	var hf := float(h)
	for y in h:
		var yf := float(y) + 0.5
		for x in w:
			var xf := float(x) + 0.5
			if not _inside_rounded_rect(xf, yf, wf, hf, r):
				continue
			img.set_pixel(x, y, bg_color)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	return sb


## 編隊槽內嵌血條：深軌＋咖啡邊（與按鈕框同色寬）、默契色填滿。
static func apply_party_slot_hp_bar_theme(
	bar: ProgressBar,
	bar_height_px: int,
	border_color: Color,
	border_width_px: int = 1
) -> void:
	var h := maxi(4, bar_height_px)
	var cr := _corner_radius_for_height(h)
	var cr_i := int(round(cr))
	var track := Color(0.08, 0.08, 0.1, 0.9)
	var fill := Color(0.482, 0.451, 0.404, 1.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = track
	if border_width_px > 0:
		bg.set_border_width_all(border_width_px)
		bg.border_color = border_color
	bg.set_corner_radius_all(cr_i)
	var fl := StyleBoxFlat.new()
	fl.bg_color = fill
	fl.set_corner_radius_all(cr_i)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fl)
